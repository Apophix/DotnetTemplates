#!/usr/bin/env bash
set -euo pipefail

RG="rg-webprojectazureprefix"

# Parse arguments
SCOPE=""
PR_LABEL=""
TEARDOWN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope) SCOPE="$2"; shift 2 ;;
    --pr-label) PR_LABEL="$2"; shift 2 ;;
    --teardown) TEARDOWN=true; shift ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# Validate
if [[ -z "$SCOPE" ]]; then
  echo "Usage: $0 --scope <shared|staging|production|pr> [--pr-label <prN>] [--teardown]"
  exit 1
fi
if [[ "$SCOPE" == "pr" && -z "$PR_LABEL" ]]; then
  echo "Error: --pr-label is required when --scope is pr"
  exit 1
fi

# Ensure PyYAML is available (not guaranteed on all GitHub Actions runners)
python3 -m pip install --quiet pyyaml

# Resolve the App Configuration store name dynamically
STORE=$(az appconfig list -g "$RG" --query '[0].name' -o tsv)
if [[ -z "$STORE" ]]; then
  echo "ERROR: No App Configuration store found in resource group '${RG}'" >&2
  exit 1
fi
echo "Using App Configuration store: $STORE"

# ── Teardown ──────────────────────────────────────────────────────────────────
if [[ "$TEARDOWN" == "true" ]]; then
  if [[ "$SCOPE" != "pr" ]]; then
    echo "Error: --teardown is only valid with --scope pr"
    exit 1
  fi
  echo "Deleting all AppConfig entries with label '${PR_LABEL}'..."
  az appconfig kv delete \
    --name "$STORE" \
    --key "*" \
    --label "$PR_LABEL" \
    --yes \
    --output none
  az appconfig feature delete \
    --name "$STORE" \
    --feature "*" \
    --label "$PR_LABEL" \
    --yes \
    --output none 2>/dev/null || true
  echo "Teardown complete."
  exit 0
fi

# ── Helper: upsert regular config keys ───────────────────────────────────────
upsert_config_keys() {
  local section="$1"
  local label="$2"   # empty string means no label (shared scope)

  echo "Syncing config keys for section '${section}'..."

  local section_json
  section_json=$(python3 - <<'PYEOF'
import yaml, json, sys, os

section_name = os.environ['_SECTION']
config_path = os.environ.get('_CONFIG_PATH', 'config/appconfig.yaml')

with open(config_path) as f:
    data = yaml.safe_load(f)

section = data.get(section_name, {}) or {}
print(json.dumps(section))
PYEOF
)

  # Iterate each key in the section JSON
  python3 - <<PYEOF2
import json, sys, os, subprocess

section = json.loads(os.environ['_SECTION_JSON'])
label = os.environ.get('_LABEL', '')
store = os.environ['_STORE']
rg = os.environ['_RG']

for key, value in section.items():
    if isinstance(value, dict):
        # KeyVault reference
        secret_name = value.get('keyVaultSecret', '')
        vault_name = value.get('keyVaultName', '')

        if not vault_name:
            # Resolve vault by environment tag
            result = subprocess.run(
                ['az', 'keyvault', 'list', '-g', rg,
                 '--query', f"[?tags.environment=='{label}'].name",
                 '-o', 'tsv'],
                capture_output=True, text=True, check=True
            )
            vault_name = result.stdout.strip()
            if not vault_name or '\n' in vault_name:
                print(f"ERROR: Expected exactly one Key Vault with tag environment='{label}', got: {vault_name!r}", file=sys.stderr)
                sys.exit(1)

        uri = f"https://{vault_name}.vault.azure.net/secrets/{secret_name}"
        kv_value = json.dumps({'uri': uri})

        cmd = [
            'az', 'appconfig', 'kv', 'set',
            '--name', store,
            '--key', key,
            '--value', kv_value,
            '--content-type', 'application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8',
            '--yes',
            '--output', 'none'
        ]
        if label:
            cmd += ['--label', label]
    else:
        # Plain string value
        cmd = [
            'az', 'appconfig', 'kv', 'set',
            '--name', store,
            '--key', key,
            '--value', str(value),
            '--yes',
            '--output', 'none'
        ]
        if label:
            cmd += ['--label', label]

    print(f"  Upserting key: {key}")
    subprocess.run(cmd, check=True)

print("Config keys synced.")
PYEOF2
}

# ── Helper: bootstrap feature flags ──────────────────────────────────────────
bootstrap_feature_flags() {
  local ff_scope="$1"   # which section to read enabled state from (shared/staging/production)
  local label="$2"      # label to write to AppConfig (empty = no label)

  echo "Bootstrapping feature flags for scope '${ff_scope}' with label '${label:-<none>}'..."

  python3 - <<PYEOF3
import yaml, json, sys, os, subprocess

ff_scope = os.environ['_FF_SCOPE']
label = os.environ.get('_LABEL', '')
store = os.environ['_STORE']
config_path = os.environ.get('_FF_CONFIG_PATH', 'config/featureflags.yaml')

with open(config_path) as f:
    flags = yaml.safe_load(f) or {}

for flag_id, flag_data in flags.items():
    scope_data = flag_data.get(ff_scope)
    if scope_data is None:
        # Flag does not have an entry for this scope — skip
        continue

    description = flag_data.get('description', '')
    enabled = bool(scope_data.get('enabled', False))
    enabled_str = 'true' if enabled else 'false'

    # Check if already exists
    check_cmd = [
        'az', 'appconfig', 'kv', 'show',
        '--name', store,
        '--key', f'.appconfig.featureflag/{flag_id}',
    ]
    if label:
        check_cmd += ['--label', label]

    result = subprocess.run(check_cmd, capture_output=True, text=True)

    if result.returncode == 0 and result.stdout.strip():
        print(f"  Feature flag '{flag_id}' already exists — skipping.")
        continue

    # Bootstrap it
    flag_json = json.dumps({
        'id': flag_id,
        'description': description,
        'enabled': enabled
    })

    set_cmd = [
        'az', 'appconfig', 'kv', 'set',
        '--name', store,
        '--key', f'.appconfig.featureflag/{flag_id}',
        '--value', flag_json,
        '--content-type', 'application/vnd.microsoft.appconfig.ff+json;charset=utf-8',
        '--yes',
        '--output', 'none'
    ]
    if label:
        set_cmd += ['--label', label]

    print(f"  Bootstrapping feature flag: {flag_id} (enabled={enabled_str})")
    subprocess.run(set_cmd, check=True)

print("Feature flags bootstrapped.")
PYEOF3
}

# ── Helper: bump Sentinel ─────────────────────────────────────────────────────
bump_sentinel() {
  echo "Bumping Sentinel..."
  az appconfig kv set \
    --name "$STORE" \
    --key "Sentinel" \
    --value "$(date -u +%Y%m%dT%H%M%SZ)" \
    --yes \
    --output none
  echo "Sentinel bumped."
}

# ── Main dispatch ─────────────────────────────────────────────────────────────
case "$SCOPE" in
  shared)
    export _SECTION="shared"
    export _SECTION_JSON
    _SECTION_JSON=$(python3 -c "
import yaml, json
with open('config/appconfig.yaml') as f:
    data = yaml.safe_load(f)
print(json.dumps(data.get('shared', {}) or {}))
")
    export _LABEL=""
    export _STORE="$STORE"
    export _RG="$RG"
    export _FF_SCOPE="shared"
    export _FF_CONFIG_PATH="config/featureflags.yaml"

    upsert_config_keys "shared" ""
    bootstrap_feature_flags "shared" ""
    bump_sentinel
    ;;

  staging)
    export _SECTION="staging"
    export _SECTION_JSON
    _SECTION_JSON=$(python3 -c "
import yaml, json
with open('config/appconfig.yaml') as f:
    data = yaml.safe_load(f)
print(json.dumps(data.get('staging', {}) or {}))
")
    export _LABEL="staging"
    export _STORE="$STORE"
    export _RG="$RG"
    export _FF_SCOPE="staging"
    export _FF_CONFIG_PATH="config/featureflags.yaml"

    upsert_config_keys "staging" "staging"
    bootstrap_feature_flags "staging" "staging"
    bump_sentinel
    ;;

  production)
    export _SECTION="production"
    export _SECTION_JSON
    _SECTION_JSON=$(python3 -c "
import yaml, json
with open('config/appconfig.yaml') as f:
    data = yaml.safe_load(f)
print(json.dumps(data.get('production', {}) or {}))
")
    export _LABEL="production"
    export _STORE="$STORE"
    export _RG="$RG"
    export _FF_SCOPE="production"
    export _FF_CONFIG_PATH="config/featureflags.yaml"

    upsert_config_keys "production" "production"
    bootstrap_feature_flags "production" "production"
    # No Sentinel bump here — the slot swap hasn't happened yet. Bumping Sentinel
    # (no label) would trigger a config reload in the staging slot right before the
    # swap, risking a failed health ping. Production keys will be loaded naturally
    # after the swap on the first incoming request.
    ;;

  pr)
    # Only bootstrap feature flags using staging enabled states, with PR label
    export _LABEL="$PR_LABEL"
    export _STORE="$STORE"
    export _RG="$RG"
    export _FF_SCOPE="staging"
    export _FF_CONFIG_PATH="config/featureflags.yaml"

    bootstrap_feature_flags "staging" "$PR_LABEL"
    # No Sentinel bump for PR scope
    ;;

  *)
    echo "Error: Unknown scope '${SCOPE}'. Must be one of: shared, staging, production, pr"
    exit 1
    ;;
esac

echo "Done."

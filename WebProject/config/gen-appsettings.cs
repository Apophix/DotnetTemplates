#!/usr/bin/env dotnet-run
#:sdk Microsoft.NET.Sdk
#:package YamlDotNet@16.3.0

// gen-appsettings.cs — Generate environment-specific appsettings.{Env}.json files.
//
// Reads:
//   config/appconfig.yaml     — non-secret config values (shared + per-env sections)
//   config/featureflags.yaml  — feature flag definitions (shared + per-env enabled states)
//
// Outputs:
//   appsettings.{Env}.json    — merged JSON ready to drop into the API project
//
// Usage (run from repo root):
//   dotnet run config/gen-appsettings.cs -- --env staging  --output WebProject.Api/appsettings.Staging.json
//   dotnet run config/gen-appsettings.cs -- --env production --output WebProject.Api/appsettings.Production.json
//
// Optional:
//   --vault <name>   Default Key Vault name (used when a secret entry omits keyVaultName)
//   --config <path>  Path to appconfig.yaml    (default: config/appconfig.yaml)
//   --flags  <path>  Path to featureflags.yaml (default: config/featureflags.yaml)

using System.Text.Json;
using System.Text.Json.Nodes;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

// ── Argument parsing ────────────────────────────────────────────────────────

string? env = null, output = null, vault = null;
string configPath = "config/appconfig.yaml";
string flagsPath  = "config/featureflags.yaml";

for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--env":    env        = args[++i]; break;
        case "--output": output     = args[++i]; break;
        case "--vault":  vault      = args[++i]; break;
        case "--config": configPath = args[++i]; break;
        case "--flags":  flagsPath  = args[++i]; break;
    }
}

if (env is null || output is null)
{
    Console.Error.WriteLine("Usage: dotnet run config/gen-appsettings.cs -- --env <staging|production> --output <path>");
    return 1;
}

if (env is not ("staging" or "production"))
{
    Console.Error.WriteLine($"Unknown environment '{env}'. Must be 'staging' or 'production'.");
    return 1;
}

// ── YAML loading ────────────────────────────────────────────────────────────

var deserializer = new DeserializerBuilder()
    .WithNamingConvention(NullNamingConvention.Instance)
    .Build();

static Dictionary<string, object> LoadYaml(string path, IDeserializer d)
{
    if (!File.Exists(path))
    {
        Console.Error.WriteLine($"File not found: {path}");
        Environment.Exit(1);
    }
    return d.Deserialize<Dictionary<string, object>>(File.ReadAllText(path))
        ?? [];
}

var appconfig    = LoadYaml(configPath, deserializer);
var featureflags = LoadYaml(flagsPath,  deserializer);

// ── Output object ───────────────────────────────────────────────────────────

var root = new JsonObject();

// Helper: set a value using a colon-separated ASP.NET Core config key
static void SetNested(JsonObject obj, string key, JsonNode value)
{
    var parts = key.Split(':');
    var current = obj;
    foreach (var part in parts[..^1])
    {
        if (!current.ContainsKey(part) || current[part] is not JsonObject)
            current[part] = new JsonObject();
        current = (JsonObject)current[part]!;
    }
    current[parts[^1]] = value;
}

// Helper: resolve a Key Vault URI from a secret entry dict
static string KeyVaultUri(string secretName, string? vaultName, string? defaultVault)
{
    var resolved = vaultName ?? defaultVault;
    if (resolved is null)
        throw new InvalidOperationException(
            $"Key Vault secret '{secretName}' has no vault name. " +
            "Pass --vault <name> or add keyVaultName to the entry.");
    return $"@Microsoft.KeyVault(VaultName={resolved};SecretName={secretName})";
}

// Apply a config section (shared or env-specific) into the output object
void ApplySection(object? section)
{
    if (section is not Dictionary<object, object> dict) return;
    foreach (var (k, v) in dict)
    {
        var key = k.ToString()!;
        if (v is Dictionary<object, object> secretDict
            && secretDict.ContainsKey("keyVaultSecret"))
        {
            var secretName = secretDict["keyVaultSecret"].ToString()!;
            var vaultName  = secretDict.TryGetValue("keyVaultName", out var vn) ? vn?.ToString() : null;
            SetNested(root, key, JsonValue.Create(KeyVaultUri(secretName, vaultName, vault))!);
        }
        else
        {
            var json = v switch
            {
                bool b   => JsonValue.Create(b),
                int n    => JsonValue.Create(n),
                double d => JsonValue.Create(d),
                _        => JsonValue.Create(v?.ToString() ?? "")
            };
            SetNested(root, key, json!);
        }
    }
}

// Apply shared then env-specific config
appconfig.TryGetValue("shared", out var shared);
appconfig.TryGetValue(env, out var envSection);
ApplySection(shared);
ApplySection(envSection);

// ── Feature flags ───────────────────────────────────────────────────────────

var fm = new JsonObject();
foreach (var (flagName, flagDef) in featureflags)
{
    if (flagDef is not Dictionary<object, object> def) continue;

    bool enabled = false;

    if (def.TryGetValue("shared", out var sharedDef)
        && sharedDef is Dictionary<object, object> sharedBlock
        && sharedBlock.TryGetValue("enabled", out var sharedEnabled))
        enabled = Convert.ToBoolean(sharedEnabled);

    if (def.TryGetValue(env, out var envDef)
        && envDef is Dictionary<object, object> envBlock
        && envBlock.TryGetValue("enabled", out var envEnabled))
        enabled = Convert.ToBoolean(envEnabled);

    fm[flagName] = JsonValue.Create(enabled);
}

if (fm.Count > 0)
{
    if (root["FeatureManagement"] is JsonObject existing)
        foreach (var (k, v) in fm) existing[k] = v?.DeepClone();
    else
        root["FeatureManagement"] = fm;
}

// ── Write output ────────────────────────────────────────────────────────────

var outPath = Path.GetFullPath(output);
Directory.CreateDirectory(Path.GetDirectoryName(outPath)!);

var json = root.ToJsonString(new JsonSerializerOptions { WriteIndented = true });
File.WriteAllText(outPath, json + Environment.NewLine);

Console.WriteLine($"Generated {output} ({env})");
return 0;

#Requires -Version 5.1
<#
.SYNOPSIS
    Pulls staging secrets from Azure Key Vault into local dotnet user-secrets.
.DESCRIPTION
    Authenticates to Azure using the Azure CLI, reads the list of required secrets
    from config/user-secrets.example.json, pulls each value from the staging Key Vault,
    and writes them to dotnet user-secrets for the AppHost project.

    Key Vault name is read from config/hydrate.config.json. If that file does not exist,
    you will be prompted once and the name will be saved for future runs.

    Safe to run at any time — existing secrets are overwritten unless --SkipExisting is passed.

.PARAMETER SkipExisting
    When set, secrets that are already configured in dotnet user-secrets are not overwritten.

.EXAMPLE
    .\scripts\dev-hydrate.ps1
    .\scripts\dev-hydrate.ps1 -SkipExisting
#>

[CmdletBinding()]
param(
    [switch]$SkipExisting
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "Dev Hydrate" -ForegroundColor Cyan
Write-Host "===========" -ForegroundColor Cyan

# ── 1. Check az CLI ───────────────────────────────────────────────────────────
Write-Host "`nChecking Azure CLI..." -ForegroundColor White
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "  [ERROR] Azure CLI not found. Install from: https://aka.ms/install-azure-cli" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Azure CLI found" -ForegroundColor Green

# ── 2. Verify Azure login ─────────────────────────────────────────────────────
Write-Host "`nChecking Azure login..." -ForegroundColor White
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "  Not logged in. Running az login..." -ForegroundColor Yellow
    az login | Out-Null
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Host "  [ERROR] Azure login failed." -ForegroundColor Red
        exit 1
    }
}
Write-Host "  [OK] Logged in as $($account.user.name) (subscription: $($account.name))" -ForegroundColor Green

# ── 3. Load or create hydrate.config.json ────────────────────────────────────
Write-Host "`nLoading hydrate config..." -ForegroundColor White
$hydrateConfigPath = "$root/config/hydrate.config.json"
if (Test-Path $hydrateConfigPath) {
    $hydrateConfig = Get-Content $hydrateConfigPath -Raw | ConvertFrom-Json
    Write-Host "  [OK] Key Vault: $($hydrateConfig.keyVaultName)" -ForegroundColor Green
} else {
    Write-Host "  config/hydrate.config.json not found." -ForegroundColor Yellow
    $kvName = Read-Host "  Enter your staging Key Vault name"
    if ([string]::IsNullOrWhiteSpace($kvName)) {
        Write-Host "  [ERROR] Key Vault name cannot be empty." -ForegroundColor Red
        exit 1
    }
    $hydrateConfig = [PSCustomObject]@{ keyVaultName = $kvName.Trim() }
    $hydrateConfig | ConvertTo-Json | Set-Content $hydrateConfigPath
    Write-Host "  [OK] Saved to config/hydrate.config.json (gitignored)" -ForegroundColor Green
}
$kvName = $hydrateConfig.keyVaultName

# ── 4. Read required secret keys ─────────────────────────────────────────────
Write-Host "`nReading required secrets..." -ForegroundColor White
$exampleFile = "$root/config/user-secrets.example.json"
if (-not (Test-Path $exampleFile)) {
    Write-Host "  [SKIP] config/user-secrets.example.json not found — nothing to hydrate." -ForegroundColor DarkGray
    exit 0
}
$example     = Get-Content $exampleFile -Raw | ConvertFrom-Json
$secretKeys  = $example.PSObject.Properties |
    Where-Object { $_.Name -notlike '_*' } |
    Select-Object -ExpandProperty Name

if ($secretKeys.Count -eq 0) {
    Write-Host "  [OK] No secrets documented — nothing to hydrate." -ForegroundColor Green
    exit 0
}
Write-Host "  Found $($secretKeys.Count) secret(s) to hydrate" -ForegroundColor Green

# ── 5. Find AppHost project ───────────────────────────────────────────────────
$appHostProject = Get-ChildItem $root -Recurse -Filter '*.AppHost.csproj' | Select-Object -First 1
if (-not $appHostProject) {
    Write-Host "`n  [ERROR] No *.AppHost.csproj found in $root" -ForegroundColor Red
    exit 1
}

# Pre-load existing secrets if --SkipExisting was requested
$existingSecrets = @()
if ($SkipExisting) {
    $existingSecrets = & dotnet user-secrets list --project $appHostProject.FullName 2>$null
    if (-not $existingSecrets) { $existingSecrets = @() }
}

# ── 6. Pull and write each secret ────────────────────────────────────────────
Write-Host "`nHydrating secrets from Key Vault '$kvName'..." -ForegroundColor White

$set     = 0
$skipped = 0
$failed  = 0

foreach ($key in $secretKeys) {
    # Convert ASP.NET Core config key (colon separator) to Key Vault secret name (double-dash)
    $kvSecretName = $key -replace ':', '--'

    # Skip if --SkipExisting and already set
    if ($SkipExisting) {
        $alreadySet = $existingSecrets | Where-Object { $_ -match "^$([regex]::Escape($key))\s*=" }
        if ($alreadySet) {
            Write-Host "  [SKIP] $key (already set)" -ForegroundColor DarkGray
            $skipped++
            continue
        }
    }

    try {
        $value = az keyvault secret show `
            --vault-name $kvName `
            --name $kvSecretName `
            --query value `
            -o tsv 2>$null

        if ([string]::IsNullOrWhiteSpace($value)) {
            Write-Host "  [WARN] $key — secret '$kvSecretName' not found or empty in vault" -ForegroundColor Yellow
            $failed++
            continue
        }

        & dotnet user-secrets set $key $value --project $appHostProject.FullName | Out-Null
        Write-Host "  [SET]  $key" -ForegroundColor Green
        $set++
    } catch {
        Write-Host "  [FAIL] $key — $_" -ForegroundColor Red
        $failed++
    }
}

# ── 7. Summary ────────────────────────────────────────────────────────────────
$solution    = Get-ChildItem $root -Filter '*.slnx' | Select-Object -First 1
if (-not $solution) { $solution = Get-ChildItem $root -Filter '*.sln' | Select-Object -First 1 }
$appHostName = if ($solution) { "$([System.IO.Path]::GetFileNameWithoutExtension($solution.Name)).AppHost" } else { 'AppHost' }

Write-Host ""
Write-Host "Done: $set set, $skipped skipped, $failed failed" -ForegroundColor $(if ($failed -gt 0) { 'Yellow' } else { 'Cyan' })

if ($failed -eq 0) {
    Write-Host @"

  Secrets are set. Start the app:
    dotnet run --project $appHostName

  Re-run this script any time to refresh secrets from Key Vault.
  Pass -SkipExisting to preserve any local overrides.

"@ -ForegroundColor Cyan
} else {
    Write-Host @"

  Some secrets could not be retrieved. Check that:
    - Your account has 'Key Vault Secrets User' on vault '$kvName'
    - The secret names in config/user-secrets.example.json match those in Key Vault
      (Key Vault uses double-dash: 'PostHog--ProjectToken' for 'PostHog:ProjectToken')

"@ -ForegroundColor Yellow
}

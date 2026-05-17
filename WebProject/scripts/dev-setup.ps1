#Requires -Version 5.1
<#
.SYNOPSIS
    Developer setup / sync.
.DESCRIPTION
    Checks prerequisites, restores packages, creates .env.local, and reports
    any user secrets that are documented in config/user-secrets.example.json
    but not yet set locally.

    Safe to run at any time — all steps are idempotent.
    No Azure connection is made — local dev is fully self-contained.
#>

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

# Detect project name from solution file
$solution = Get-ChildItem $root -Filter '*.slnx' | Select-Object -First 1
if (-not $solution) { $solution = Get-ChildItem $root -Filter '*.sln' | Select-Object -First 1 }
$projectName = if ($solution) { [System.IO.Path]::GetFileNameWithoutExtension($solution.Name) } else { 'Project' }

Write-Host ""
Write-Host "$projectName Dev Setup" -ForegroundColor Cyan
Write-Host ("=" * "$projectName Dev Setup".Length) -ForegroundColor Cyan

# ── 1. Prerequisites ──────────────────────────────────────────────────────────
Write-Host "`nChecking prerequisites..." -ForegroundColor White

function Test-Tool($cmd, $label, $hint) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Host "  [OK] $label" -ForegroundColor Green; return $true
    }
    Write-Host "  [MISSING] $label — $hint" -ForegroundColor Red; return $false
}

$prereqsOk = $true
$prereqsOk = (Test-Tool dotnet ".NET SDK"  "https://dot.net")                       -and $prereqsOk
$prereqsOk = (Test-Tool node   "Node.js"   "https://nodejs.org")                    -and $prereqsOk
$prereqsOk = (Test-Tool docker "Docker"    "https://docs.docker.com/get-docker/")   -and $prereqsOk

if (-not $prereqsOk) {
    Write-Host "`nInstall the missing tools above, then re-run this script." -ForegroundColor Red
    exit 1
}

$sdkVersion = [version](dotnet --version 2>$null)
if ($sdkVersion.Major -lt 10) {
    Write-Host "  [ERROR] .NET SDK $sdkVersion found; version 10+ required." -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] .NET SDK $sdkVersion" -ForegroundColor Green

# ── 2. Restore .NET packages ──────────────────────────────────────────────────
Write-Host "`nRestoring .NET packages..." -ForegroundColor White
if (-not $solution) {
    Write-Host "  [ERROR] No solution file found in $root" -ForegroundColor Red
    exit 1
}
& dotnet restore $solution.FullName --verbosity quiet
if ($LASTEXITCODE -ne 0) { Write-Host "  [ERROR] dotnet restore failed (exit $LASTEXITCODE)" -ForegroundColor Red; exit $LASTEXITCODE }
Write-Host "  [OK] $($solution.Name)" -ForegroundColor Green

# ── 3. Install npm packages ───────────────────────────────────────────────────
Write-Host "`nInstalling npm packages..." -ForegroundColor White
$webDir = Get-ChildItem $root -Directory |
    Where-Object { Test-Path "$($_.FullName)/package.json" } |
    Select-Object -First 1
if ($webDir) {
    Push-Location $webDir.FullName
    try { & npm install --silent } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { Write-Host "  [ERROR] npm install failed (exit $LASTEXITCODE)" -ForegroundColor Red; exit $LASTEXITCODE }
    Write-Host "  [OK] $($webDir.Name)" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] No package.json found" -ForegroundColor DarkGray
}

# ── 4. Frontend .env.local ────────────────────────────────────────────────────
Write-Host "`nFrontend environment..." -ForegroundColor White
if ($webDir) {
    $envLocal   = "$($webDir.FullName)/.env.local"
    $envExample = "$($webDir.FullName)/.env.example"
    if (Test-Path $envExample) {
        if (-not (Test-Path $envLocal)) {
            Copy-Item $envExample $envLocal
            Write-Host "  [OK] Created .env.local from .env.example" -ForegroundColor Green
        } else {
            Write-Host "  [OK] .env.local already exists" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  [SKIP] No .env.example found" -ForegroundColor DarkGray
    }
}

# ── 5. Backend appsettings.local.json ────────────────────────────────────────
Write-Host "`nBackend local configuration..." -ForegroundColor White
$apiDir = Get-ChildItem $root -Directory |
    Where-Object { Test-Path "$($_.FullName)/appsettings.local.json.example" } |
    Select-Object -First 1
if ($apiDir) {
    $localJson   = "$($apiDir.FullName)/appsettings.local.json"
    $exampleJson = "$($apiDir.FullName)/appsettings.local.json.example"
    if (-not (Test-Path $localJson)) {
        Copy-Item $exampleJson $localJson
        Write-Host "  [OK] Created appsettings.local.json from .example" -ForegroundColor Green
    } else {
        Write-Host "  [OK] appsettings.local.json already exists" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  [SKIP] No appsettings.local.json.example found" -ForegroundColor DarkGray
}

# ── 6. User secrets check ─────────────────────────────────────────────────────
Write-Host "`nChecking user secrets..." -ForegroundColor White
$exampleFile = "$root/config/user-secrets.example.json"
if (Test-Path $exampleFile) {
    $example      = Get-Content $exampleFile -Raw | ConvertFrom-Json
    $requiredKeys = $example.PSObject.Properties |
        Where-Object { $_.Name -notlike '_*' } |
        Select-Object -ExpandProperty Name

    if ($requiredKeys.Count -eq 0) {
        Write-Host "  [OK] No user secrets required for local dev" -ForegroundColor Green
    } else {
        $appHostProject = Get-ChildItem $root -Recurse -Filter '*.AppHost.csproj' |
            Select-Object -First 1
        if ($appHostProject) {
            $currentSecrets = & dotnet user-secrets list --project $appHostProject.FullName 2>$null
            $missing = @()
            foreach ($key in $requiredKeys) {
                $isSet = $currentSecrets | Where-Object { $_ -match "^$([regex]::Escape($key))\s*=" }
                if (-not $isSet) { $missing += $key }
            }
            if ($missing.Count -eq 0) {
                Write-Host "  [OK] All required user secrets are set" -ForegroundColor Green
            } else {
                Write-Host "  [ACTION REQUIRED] Missing user secrets:" -ForegroundColor Yellow
                foreach ($key in $missing) {
                    Write-Host "    dotnet user-secrets set `"$key`" `"<value>`" --project $($appHostProject.Name)" -ForegroundColor Yellow
                }
            }
        }
    }
} else {
    Write-Host "  [SKIP] No config/user-secrets.example.json found" -ForegroundColor DarkGray
}

# ── 7. Done ───────────────────────────────────────────────────────────────────
$appHostName = if ($solution) { "$([System.IO.Path]::GetFileNameWithoutExtension($solution.Name)).AppHost" } else { 'AppHost' }

Write-Host @"

Setup complete!

  Start everything:
    dotnet run --project $appHostName

  Aspire dashboard (logs, traces, health checks):
    https://localhost:17022

  Local dev is fully self-contained — no Azure connection required.
  Feature flags:  appsettings.local.json  (FeatureManagement section)
  Auth:           dev bypass  (appsettings.local.json Authentication:DevBypass)
  Switch persona: add header  X-Dev-Persona: admin  (or any persona defined in config)

  To pull staging secrets from Azure Key Vault into local user-secrets:
    .\scripts\dev-hydrate.ps1

"@ -ForegroundColor Cyan

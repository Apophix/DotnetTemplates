<#
.SYNOPSIS
    WebProject — One-time bootstrap for Azure infrastructure.

.DESCRIPTION
    Run this ONCE before the first deployment. Registers resource providers,
    sets GitHub secrets, and deploys the initial infrastructure stack.

.PARAMETER Variant
    Which hosting option to deploy: AppService or ContainerApps.

.PARAMETER Location
    Azure region to deploy to (default: centralus).

.EXAMPLE
    .\infra\bootstrap.ps1 -Variant AppService
    .\infra\bootstrap.ps1 -Variant ContainerApps -Location westus2
#>
param(
    [Parameter(Mandatory)]
    [ValidateSet('AppService', 'ContainerApps')]
    [string]$Variant,

    [string]$Location = 'centralus'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "WebProject Bootstrap" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host "Variant : $Variant"
Write-Host "Location: $Location"
Write-Host ""

# ── Preflight checks ──────────────────────────────────────────────────────────

function Test-Command([string]$cmd) { $null -ne (Get-Command $cmd -ErrorAction SilentlyContinue) }

if (-not (Test-Command 'az')) {
    Write-Error "az CLI not found. Install from https://aka.ms/installazurecliwindows"
    exit 1
}
if (-not (Test-Command 'gh')) {
    Write-Error "gh CLI not found. Install from https://cli.github.com"
    exit 1
}

$accountCheck = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged in to Azure. Run: az login"
    exit 1
}

$authCheck = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Not logged in to GitHub. Run: gh auth login"
    exit 1
}

Write-Host "✓ Preflight checks passed" -ForegroundColor Green
Write-Host ""

# ── SQL admin password ────────────────────────────────────────────────────────

if ($env:AZURE_SQL_ADMIN_PASSWORD) {
    $SqlAdminPassword = $env:AZURE_SQL_ADMIN_PASSWORD
    Write-Host "✓ SQL admin password read from AZURE_SQL_ADMIN_PASSWORD env var" -ForegroundColor Green
} else {
    $securePassword = Read-Host -Prompt "SQL admin password" -AsSecureString
    $SqlAdminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )
}

# ── Set GitHub Actions secret ─────────────────────────────────────────────────

Write-Host "Setting AZURE_SQL_ADMIN_PASSWORD as a GitHub Actions secret..."
$SqlAdminPassword | gh secret set AZURE_SQL_ADMIN_PASSWORD
if ($LASTEXITCODE -ne 0) { Write-Error "Failed to set GitHub secret"; exit 1 }
Write-Host "✓ GitHub secret set" -ForegroundColor Green
Write-Host ""

# ── Register required resource providers ─────────────────────────────────────

Write-Host "Registering required Azure resource providers..."
az provider register -n Microsoft.Web --wait
az provider register -n Microsoft.App --wait
az provider register -n Microsoft.ContainerRegistry --wait
Write-Host "✓ Resource providers registered"
Write-Host ""

# ── Compile and deploy Bicep ──────────────────────────────────────────────────

$variantDir = if ($Variant -eq 'AppService') { 'azure-app-service' } else { 'azure-container-apps' }
$bicepFile = Join-Path $scriptDir "$variantDir\main.bicep"
$armFile   = Join-Path $scriptDir "$variantDir\main.compiled.json"

try {
    Write-Host "Compiling Bicep..."
    az bicep build --file $bicepFile --outfile $armFile
    if ($LASTEXITCODE -ne 0) { Write-Error "Bicep compilation failed"; exit 1 }
    Write-Host "✓ Compiled" -ForegroundColor Green
    Write-Host ""

    Write-Host "Deploying infrastructure stack (this takes ~5-10 minutes)..."
    az stack sub create `
        --name stack-webprojectazureprefix `
        --location $Location `
        --template-file $armFile `
        --parameters `
            location=$Location `
            staticWebAppLocation=$Location `
            sqlAdminLogin=sqladmin `
            "sqlAdminPassword=$SqlAdminPassword" `
        --deny-settings-mode none `
        --action-on-unmanage detachAll `
        --yes `
        --output table

    if ($LASTEXITCODE -ne 0) { Write-Error "Infrastructure deployment failed"; exit 1 }
    Write-Host ""
    Write-Host "✓ Infrastructure deployed" -ForegroundColor Green
    Write-Host ""
} finally {
    if (Test-Path $armFile) { Remove-Item $armFile -Force }
}

# ── Next steps ────────────────────────────────────────────────────────────────

$repoName = gh repo view --json nameWithOwner -q .nameWithOwner

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Bootstrap complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Push a commit to main to trigger the first full deployment:"
Write-Host "     git commit --allow-empty -m 'chore: trigger first container deployment'"
Write-Host "     git push"
Write-Host ""
Write-Host "  2. Watch the pipeline at:"
Write-Host "     https://github.com/$repoName/actions"
Write-Host ""
Write-Host "  From now on, all infrastructure changes via PR to infra/** are deployed"
Write-Host "  automatically by infra.yml. All app deploys trigger via push to main."

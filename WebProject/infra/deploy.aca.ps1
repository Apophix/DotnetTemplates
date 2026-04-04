#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys all WebProject container infrastructure to Azure using a Deployment Stack.
    Creates/updates the stack-webprojectazureprefix deployment stack at subscription scope,
    which owns rg-webprojectazureprefix and all resources within it.
    Run from the repo root or the infra/ directory.

.PARAMETER Location
    Azure region. Defaults to 'centralus'.

.PARAMETER SqlAdminPassword
    SQL Server administrator password. Prompted securely if not provided.

.PARAMETER WhatIf
    Runs az stack sub validate instead of creating/updating the stack.

.EXAMPLE
    ./infra/deploy.ps1

.EXAMPLE
    ./infra/deploy.ps1 -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string] $Location = 'centralus',

    [Parameter()]
    [securestring] $SqlAdminPassword,

    [Parameter()]
    [switch] $WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Debug-Log([string] $msg) {
    Write-Host "[DEBUG] $msg" -ForegroundColor DarkGray
}

Debug-Log "PowerShell version : $($PSVersionTable.PSVersion)"
Debug-Log "OS                 : $($PSVersionTable.OS)"
Debug-Log "CWD                : $(Get-Location)"

# Verify az is reachable
$azCmd = Get-Command az -ErrorAction SilentlyContinue
if (-not $azCmd) {
    Write-Error 'az CLI not found in PATH'
    exit 1
}
Debug-Log "az path            : $($azCmd.Source)"
Debug-Log "az version         :"
az version
Debug-Log "az bicep version   :"
az bicep version

# az.cmd is a batch file; calling it from a PS script goes through an extra
# cmd.exe layer that causes exit 255 on deployment commands. Call Python
# directly instead — PS handles .exe args reliably with no cmd.exe middleman.
$azDir     = Split-Path $azCmd.Source
$pythonExe = (Resolve-Path (Join-Path $azDir '..\python.exe')).Path
Debug-Log "Python path        : $pythonExe"

if (-not $SqlAdminPassword) {
    $SqlAdminPassword = Read-Host 'SQL admin password' -AsSecureString
}

$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlAdminPassword)
)

Debug-Log "Location           : $Location"
Debug-Log "WhatIf             : $WhatIf"

# Resolve the infra directory regardless of where the script is called from
$scriptDir = Split-Path $MyInvocation.MyCommand.Path
$bicepFile = (Resolve-Path (Join-Path $scriptDir 'main.bicep')).Path
$armFile   = [IO.Path]::ChangeExtension($bicepFile, '.compiled.json')

Debug-Log "main.bicep         : $bicepFile"
Debug-Log "modules/ exists    : $(Test-Path (Join-Path $scriptDir 'modules'))"

# Compile Bicep -> ARM JSON using the working az bicep path.
# az stack sub create invokes the Bicep compiler through a different internal
# lookup that fails on some systems; passing pre-compiled ARM JSON avoids it.
Debug-Log "Compiling          : $bicepFile"
az bicep build --file $bicepFile --outfile $armFile 2>&1
Debug-Log "az bicep build exit: $LASTEXITCODE"
if ($LASTEXITCODE -ne 0) {
    Write-Error 'Bicep compilation failed'
    exit 1
}
Debug-Log "Compiled to        : $armFile"

try {
    if ($WhatIf) {
        Write-Host 'Validating WebProject deployment stack...' -ForegroundColor Cyan

        & $pythonExe -IBm azure.cli stack sub validate `
            --name stack-webprojectazureprefix `
            --location $Location `
            --template-file $armFile `
            --parameters "location=$Location" "staticWebAppLocation=$Location" sqlAdminLogin=sqladmin "sqlAdminPassword=$plainPassword" `
            --deny-settings-mode none `
            --output table
    }
    else {
        Write-Host 'Deploying WebProject container infrastructure...' -ForegroundColor Cyan

        & $pythonExe -IBm azure.cli stack sub create `
            --name stack-webprojectazureprefix `
            --location $Location `
            --template-file $armFile `
            --parameters "location=$Location" "staticWebAppLocation=$Location" sqlAdminLogin=sqladmin "sqlAdminPassword=$plainPassword" `
            --deny-settings-mode none `
            --action-on-unmanage deleteAll `
            --yes `
            --output table
    }
}
finally {
    Remove-Item $armFile -ErrorAction SilentlyContinue
    Debug-Log "Cleaned up         : $armFile"
}

Debug-Log "Exit code          : $LASTEXITCODE"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host 'Deployment complete.' -ForegroundColor Green

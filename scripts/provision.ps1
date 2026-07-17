<#
.SYNOPSIS
    Provisions and deploys the XiaoCao Foundry chat app end-to-end.

.DESCRIPTION
    1. Deploys the Static Web App + Function App into the customer's resource group.
    2. Grants the Function App's managed identity access to the Foundry project.
    3. Builds and deploys the Function App (API) and the Static Web App (UI).
    The app is live and configured immediately after this script completes.

.EXAMPLE
    ./scripts/provision.ps1 `
        -SubscriptionId "00000000-0000-0000-0000-000000000000" `
        -ResourceGroup "rg-xiaocao" `
        -FoundryAgentName "support-agent" `
        -FoundryEndpoint "https://my-proj.services.ai.azure.com/api/projects/my-proj" `
        -FoundryResourceId "/subscriptions/.../resourceGroups/rg-ai/providers/Microsoft.CognitiveServices/accounts/my-foundry"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $SubscriptionId,
    [Parameter(Mandatory = $true)] [string] $ResourceGroup,
    [Parameter(Mandatory = $true)] [string] $FoundryAgentName,
    [Parameter(Mandatory = $true)] [string] $FoundryEndpoint,
    [Parameter(Mandatory = $true)] [string] $FoundryResourceId,
    [string] $Location = "eastus2",
    [string] $SwaLocation = "eastus2",
    [string] $NamePrefix = "xiaocao"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Require-Command($name) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        throw "Required command '$name' was not found on PATH."
    }
}

Require-Command az
Require-Command npm

Write-Host "==> Setting subscription context" -ForegroundColor Cyan
az account set --subscription $SubscriptionId | Out-Null

Write-Host "==> Ensuring resource group '$ResourceGroup'" -ForegroundColor Cyan
az group create --name $ResourceGroup --location $Location | Out-Null

Write-Host "==> Deploying infrastructure (Bicep)" -ForegroundColor Cyan
$deployName = "xiaocao-$(Get-Date -Format yyyyMMddHHmmss)"
$outputs = az deployment group create `
    --resource-group $ResourceGroup `
    --name $deployName `
    --template-file "$root/infra/main.bicep" `
    --parameters `
        location=$Location `
        swaLocation=$SwaLocation `
        namePrefix=$NamePrefix `
        foundryEndpoint=$FoundryEndpoint `
        agentName=$FoundryAgentName `
    --query properties.outputs -o json | ConvertFrom-Json

$functionAppName = $outputs.functionAppName.value
$principalId     = $outputs.functionAppPrincipalId.value
$swaName         = $outputs.swaName.value
$swaHostname     = $outputs.swaDefaultHostname.value

Write-Host "    Function App : $functionAppName"
Write-Host "    SWA          : $swaName ($swaHostname)"

Write-Host "==> Granting Foundry access to the Function App identity" -ForegroundColor Cyan
# 'Azure AI Developer' lets the identity create threads/runs against the agent.
az role assignment create `
    --assignee-object-id $principalId `
    --assignee-principal-type ServicePrincipal `
    --role "Azure AI Developer" `
    --scope $FoundryResourceId 2>$null | Out-Null
Write-Host "    Role assignment ensured."

Write-Host "==> Building & deploying the Function App (API)" -ForegroundColor Cyan
Push-Location "$root/api"
try {
    npm install
    npm run build
    if (Get-Command func -ErrorAction SilentlyContinue) {
        func azure functionapp publish $functionAppName --javascript
    }
    else {
        Write-Warning "Azure Functions Core Tools (func) not found; falling back to zip deploy."
        $zip = Join-Path $env:TEMP "xiaocao-api.zip"
        if (Test-Path $zip) { Remove-Item $zip -Force }
        Compress-Archive -Path (Join-Path (Get-Location) '*') -DestinationPath $zip -Force
        az functionapp deployment source config-zip `
            --resource-group $ResourceGroup `
            --name $functionAppName `
            --src $zip | Out-Null
    }
}
finally {
    Pop-Location
}

Write-Host "==> Building & deploying the Static Web App (UI)" -ForegroundColor Cyan
Push-Location $root
try {
    npm install
    $env:VITE_AGENT_NAME = $FoundryAgentName
    npm run build

    $token = az staticwebapp secrets list `
        --name $swaName `
        --resource-group $ResourceGroup `
        --query "properties.apiKey" -o tsv

    npx --yes @azure/static-web-apps-cli deploy "./dist" `
        --deployment-token $token `
        --env "production"
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "==> Done. Your chat UI is live at: https://$swaHostname" -ForegroundColor Green

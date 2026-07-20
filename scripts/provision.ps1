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
        -FoundryResourceId "/subscriptions/<sub>/resourceGroups/rg-ai/providers/Microsoft.CognitiveServices/accounts/my-foundry"

    Note: FoundryResourceId must be the bare ARM resource id (NOT a portal URL).
    Get it with: az cognitiveservices account show -n <account> -g <rg> --query id -o tsv
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $SubscriptionId,
    [Parameter(Mandatory = $true)] [string] $ResourceGroup,
    [Parameter(Mandatory = $true)] [string] $FoundryAgentName,
    [Parameter(Mandatory = $true)] [string] $FoundryEndpoint,
    [Parameter(Mandatory = $true)] [string] $FoundryResourceId,
    [ValidateSet("test", "production")] [string] $EnvironmentType = "test",
    [string] $Location = "eastasia",
    [string] $SwaLocation = "eastasia",
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

# --- Validate & normalize inputs -------------------------------------------

function Invoke-Az {
    param([Parameter(Mandatory)][string[]] $Args, [string] $ErrorMessage = "Azure CLI command failed.")
    $result = & az @Args
    if ($LASTEXITCODE -ne 0) {
        throw "$ErrorMessage (az exit $LASTEXITCODE)"
    }
    return $result
}

# The Foundry resource id must be a bare ARM resource id, not a portal URL.
# A common mistake is pasting the browser address bar (https://portal.azure.com/#@.../resource/subscriptions/...).
# Recover the id if a portal URL was supplied, otherwise validate the format.
if ($FoundryResourceId -match '/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.CognitiveServices/accounts/[^/?#]+') {
    $FoundryResourceId = $Matches[0]
}
else {
    throw "FoundryResourceId does not contain a valid Cognitive Services account resource id. " +
          "Expected '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<name>'. " +
          "Get it with: az cognitiveservices account show -n <account> -g <rg> --query id -o tsv"
}
Write-Host "    Foundry resource id : $FoundryResourceId" -ForegroundColor DarkGray

# Derive the project name from the endpoint so we can also grant at project scope.
$projectName = $null
if ($FoundryEndpoint -match '/projects/([^/?#]+)') {
    $projectName = $Matches[1]
}

Write-Host "==> Setting subscription context" -ForegroundColor Cyan
Invoke-Az @('account', 'set', '--subscription', $SubscriptionId) "Failed to set subscription context." | Out-Null

Write-Host "==> Ensuring resource group '$ResourceGroup'" -ForegroundColor Cyan
Invoke-Az @('group', 'create', '--name', $ResourceGroup, '--location', $Location) "Failed to create resource group." | Out-Null

Write-Host "==> Deploying infrastructure (Bicep)" -ForegroundColor Cyan
$deployName = "xiaocao-$(Get-Date -Format yyyyMMddHHmmss)"
$outputsJson = az deployment group create `
    --resource-group $ResourceGroup `
    --name $deployName `
    --template-file "$root/infra/main.bicep" `
    --parameters `
        location=$Location `
        swaLocation=$SwaLocation `
        namePrefix=$NamePrefix `
        environmentType=$EnvironmentType `
        foundryEndpoint=$FoundryEndpoint `
        agentName=$FoundryAgentName `
    --query properties.outputs -o json
if ($LASTEXITCODE -ne 0) {
    throw "Infrastructure deployment failed. Review the Bicep error above (common cause: subscription quota for the Function App Consumption plan)."
}
$outputs = $outputsJson | ConvertFrom-Json

$functionAppName = $outputs.functionAppName.value
$functionHostname = $outputs.functionAppHostname.value
$principalId     = $outputs.functionAppPrincipalId.value
$swaName         = $outputs.swaName.value
$swaHostname     = $outputs.swaDefaultHostname.value

if (-not $functionAppName -or -not $principalId -or -not $swaName) {
    throw "Infrastructure deployment did not return the expected outputs."
}

Write-Host "    Environment  : $EnvironmentType"
Write-Host "    Function App : $functionAppName"
Write-Host "    SWA          : $swaName ($swaHostname)"

Write-Host "==> Granting Foundry access to the Function App identity" -ForegroundColor Cyan
# 'Azure AI Developer' lets the identity create threads/runs against the agent.
# Assign at the account scope and (if resolvable) the project sub-scope, since the
# Foundry data plane may enforce access at the project level.
$scopes = @($FoundryResourceId)
if ($projectName) {
    $scopes += "$FoundryResourceId/projects/$projectName"
}
foreach ($scope in $scopes) {
    $existing = az role assignment list --assignee $principalId --scope $scope --role "Azure AI Developer" --query "[0].id" -o tsv 2>$null
    if ($existing) {
        Write-Host "    Role already present at $scope" -ForegroundColor DarkGray
        continue
    }
    az role assignment create `
        --assignee-object-id $principalId `
        --assignee-principal-type ServicePrincipal `
        --role "Azure AI Developer" `
        --scope $scope | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to assign 'Azure AI Developer' at scope: $scope"
    }
    Write-Host "    Granted 'Azure AI Developer' at $scope"
}
Write-Host "    Note: RBAC can take a few minutes to propagate to the Foundry data plane." -ForegroundColor DarkGray

Write-Host "==> Resolving agent id (so the API never has to list agents at runtime)" -ForegroundColor Cyan
# Resolving the id once here avoids a per-cold-instance listAgents() call, which is
# both slow and prone to transient 401s while RBAC propagates. The Function prefers
# AZURE_AI_AGENT_ID when present and only falls back to name lookup otherwise.
$agentId = $null
try {
    $aiToken = az account get-access-token --resource "https://ai.azure.com" --query accessToken -o tsv 2>$null
    if ($LASTEXITCODE -eq 0 -and $aiToken) {
        $listUri = "$FoundryEndpoint/assistants?api-version=2025-05-01"
        $resp = Invoke-RestMethod -Uri $listUri -Headers @{ Authorization = "Bearer $aiToken" } -ErrorAction Stop
        $match = $resp.data | Where-Object { $_.name -eq $FoundryAgentName } | Select-Object -First 1
        if ($match) { $agentId = $match.id }
    }
}
catch {
    Write-Warning "Could not pre-resolve agent id ($($_.Exception.Message)). The API will resolve it by name at runtime."
}

if ($agentId) {
    Write-Host "    Resolved '$FoundryAgentName' -> $agentId"
    az functionapp config appsettings set `
        --resource-group $ResourceGroup `
        --name $functionAppName `
        --settings AZURE_AI_AGENT_ID=$agentId | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set AZURE_AI_AGENT_ID app setting."
    }
}
else {
    Write-Warning "Agent id not resolved; falling back to runtime name lookup. If you see intermittent 500s, set AZURE_AI_AGENT_ID manually."
}

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
    # Production links the Function App at same-origin /api. The free/test tier has no
    # linked backend, so the static site must call the Function App URL directly (CORS).
    if ($EnvironmentType -eq "production") {
        $env:VITE_API_BASE = ""
    }
    else {
        $env:VITE_API_BASE = "https://$functionHostname"
    }
    npm run build

    $token = az staticwebapp secrets list `
        --name $swaName `
        --resource-group $ResourceGroup `
        --query "properties.apiKey" -o tsv

    # Deploy only the built UI. The API is a separately-deployed linked
    # Function App, so we point --api-location at nothing and skip workflow
    # inference with --no-use-keychain-free config via env token.
    npx --yes @azure/static-web-apps-cli deploy "./dist" `
        --deployment-token $token `
        --env "production"
    if ($LASTEXITCODE -ne 0) {
        throw "Static Web Apps deployment failed (exit $LASTEXITCODE)."
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "==> Done. Your chat UI is live at: https://$swaHostname" -ForegroundColor Green

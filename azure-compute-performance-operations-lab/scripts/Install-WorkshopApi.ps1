[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory = $true)]
    [string]$VmssName,
    [string]$ScriptPath = (Join-Path $PSScriptRoot "install-order-api.sh")
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI (az) is required."
}
if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Install script not found: $ScriptPath"
}

$installScript = Get-Content -Raw -LiteralPath $ScriptPath
if ($installScript -notmatch "order-api.service") {
    throw "The install script does not contain the expected order-api service."
}

$mode = az vmss show -g $ResourceGroup -n $VmssName --query orchestrationMode -o tsv
if ($LASTEXITCODE -ne 0 -or -not $mode) {
    throw "Could not read VMSS orchestration mode."
}

$vmIds = @()
if ($mode -eq "Flexible") {
    $vmIds = @(
        (az vm list -g $ResourceGroup `
            --query "[?starts_with(name, '$VmssName')].id" -o tsv) `
            -split "\r?\n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )
} else {
    $instanceIds = @(
        (az vmss list-instances -g $ResourceGroup -n $VmssName `
            --query "[].instanceId" -o tsv) `
            -split "\r?\n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )
    $vmIds = $instanceIds | ForEach-Object {
        if ($_ -notmatch "^\d+$") {
            throw "Uniform VMSS returned a non-numeric instance ID: [$_]"
        }
        "vmss:$($_)"
    }
}

if ($vmIds.Count -eq 0) {
    throw "No VMSS instances were found."
}

# Base64 avoids PowerShell/Azure CLI argument splitting of multiline shell scripts.
$payload = [Convert]::ToBase64String(
    [Text.Encoding]::UTF8.GetBytes($installScript)
)
$remoteCommand = "echo '$payload' | base64 -d > /tmp/install-order-api.sh && chmod 700 /tmp/install-order-api.sh && bash /tmp/install-order-api.sh"

foreach ($vmId in $vmIds) {
    Write-Host "Installing workshop API on [$vmId]"
    if ($vmId.StartsWith("vmss:")) {
        $instanceId = $vmId.Substring(5)
        $raw = az vmss run-command invoke -g $ResourceGroup -n $VmssName `
            --instance-id $instanceId `
            --command-id RunShellScript `
            --scripts $remoteCommand
    } else {
        $raw = az vm run-command invoke --ids $vmId `
            --command-id RunShellScript `
            --scripts $remoteCommand
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Azure run-command failed for [$vmId]."
    }
    $response = $raw | ConvertFrom-Json
    $message = $response.value[0].message
    Write-Host $message
    if ($message -notmatch "Workshop API installation succeeded") {
        throw "Workshop API installation was not verified on [$vmId]."
    }
}

Write-Host "All VMSS instances passed the workshop API installation check."


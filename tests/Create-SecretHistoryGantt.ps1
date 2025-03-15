param (
    [string]$KeyVaultName,
    [string[]]$SecretNames,
    [string]$OutputMarkdownFile = "SecretRotationHistory.md",
    [switch]$Compact
)

# Ensure Az module is installed
if (!(Get-Module -ListAvailable -Name Az.KeyVault))
{
    Write-Host "Installing Az.KeyVault module..."
    Install-Module -Name Az.KeyVault -Scope CurrentUser -Force
}

# Login if necessary
if (!(Get-AzContext))
{
    Connect-AzAccount
}

# Function to get secret versions
function Get-SecretHistory
{
    param (
        [string]$KeyVaultName,
        [string]$SecretName
    )

    $history = @()
    # Get all secret versions
    $versions = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -IncludeVersions

    foreach ($version in $versions)
    {
        $secretValue = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -Version $version.Version -AsPlainText
        $expiration = if ($version.Expires)
        {
            $version.Expires
        }
        else
        {
            $null
        }

        $history += [PSCustomObject]@{
            SecretName = $SecretName
            Version = $version.Version
            Timestamp = $version.Created
            Expires = $expiration
            Value = $secretValue
        }
    }

    return ,$history
}

# Generate Markdown content
$mermaidDiagram = @"
# Azure Key Vault Secret Rotation History

``````mermaid
"@

if ($Compact)
{
    $mermaidDiagram += @"
`n---
displayMode: compact
---
"@
}

$mermaidDiagram += @"
`ngantt
    title Secret Rotation Timeline
    dateFormat  YYYY-MM-DD HH:mm:ss
    axisFormat  %H:%M:%S
    
"@

# Default to all secrets in the specified vault if none provided
if (-not $SecretNames -or $SecretNames.Count -eq 0)
{
    Write-Host "No secret names provided. Retrieving all secrets from Key Vault: $KeyVaultName" -ForegroundColor Yellow
    $SecretNames = Get-AzKeyVaultSecret -VaultName $KeyVaultName | Select-Object -ExpandProperty Name
}

# All sorted together version
#$allHistories = @()
#foreach ($secret in $SecretNames) {
#    $allHistories += Get-SecretHistory -KeyVaultName $KeyVaultName -SecretName $secret
#}
#
## Sort all history records by timestamp (newest first)
#$allHistorySorted = $allHistories | Sort-Object Timestamp
#
#$mermaidDiagram += "  section Secrets`n"
#foreach ( $item in $allHistorySorted ) {
#    $secretLabel = "$($item.SecretName) "
#    $startTime = $item.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
#    $endTime = $item.Expires.ToString("yyyy-MM-dd HH:mm:ss")
#    
#    $mermaidDiagram += "    $secretLabel  : $startTime, $endTime`n"
#}

foreach ($secret in $SecretNames)
{
    $mermaidDiagram += "`n  section $secret`n"

    $history = Get-SecretHistory -KeyVaultName $KeyVaultName -SecretName $secret
    # Sort each secret's history by creation time (oldest first)
    $history = $history | Sort-Object Timestamp

    foreach ($version in $history)
    {
        $startTime = $version.Timestamp.ToString("yyyy-MM-dd HH:mm:ss")
        if ($version.Expires -eq $null)
        {
            # For versions without an expiry, use a milestone with 0-day duration
            $mermaidDiagram += "    Version $( $version.Version ) : milestone, $startTime, 0d`n"
        }
        else
        {
            $endTime = $version.Expires.ToString("yyyy-MM-dd HH:mm:ss")
            $mermaidDiagram += "    Version $( $version.Version ) : $startTime, $endTime`n"
        }
    }
}

# Close Mermaid block
$mermaidDiagram += "`n``````"

# Write to Markdown file
Set-Content -Path $OutputMarkdownFile -Value $mermaidDiagram

Write-Host "Mermaid Gantt chart written to $OutputMarkdownFile"

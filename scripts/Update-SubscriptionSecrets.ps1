param(
    [string]$KeyVaultName,
    [string]$Prefix
)

Write-Output "Executing Update-SubscriptionSecrets.ps1 on Key Vault: $KeyVaultName, Secret Prefix: $Prefix"

# Ensure we are authenticated
if (-not (Get-AzContext))
{
    Write-Output "Not authenticated. Running Connect-AzAccount..."
    Connect-AzAccount -Identity
}

# Fetch secret
$primarySecretName = "$Prefix-PrimaryKey"
$secondarySecretName = "$Prefix-SecondaryKey"
$activeSecretName = "$Prefix-ActiveKey"

$primarySecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $primarySecretName
$secondarySecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $primarySecretName
$activeSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $primarySecretName

Write-Output "Tags: $( $primarySecret.Tags | ConvertTo-Json -Depth 2 )"

$tags = $primarySecret.Tags

$rotationCandidate = $null
$currentDate = Get-Date

$lifespanString = $primarySecret.Tags["Age"]
$lifespan = [System.Xml.XmlConvert]::ToTimeSpan($lifespanString)

Write-Output "Using date $currentDate for expiration check. $Prefix has a lifespan of $lifespan ($lifespanString)"

if ( $primarySecret.Tags.ContainsKey("ForceRotation"))
{
    $rotationCandidate = $primarySecret
    $rotationReason = "Primary key has ForceRotation tag."
}
elseif($null -eq $primarySecret.Expires)
{
    $rotationCandidate = $primarySecret
    $rotationReason = "Primary key has no expiration date"
}
elseif ($secondarySecret.Tags.ContainsKey("ForceRotation"))
{
    $rotationCandidate = $secondarySecret
    $rotationReason = "Secondary key has ForceRotation tag."
}
elseif($null -eq $secondarySecret.Expires)
{
    $rotationCandidate = $secondarySecret
    $rotationReason = "Secondary key has no expiration date"
}
elseif ($primarySecret.Expires -gt $currentDate)
{
    $rotationCandidate = $primarySecret
    $rotationReason = "Primary key has expired."
}
elseif ($secondarySecret.Expires -gt $currentDate)
{
    $rotationCandidate = $secondarySecret
    $rotationReason = "Secondary key has expired."
}

if ($rotationCandidate) {
    Write-Output "Rotation Candidate: $($rotationCandidate.Name)"
    Write-Output "Reason for Rotation: $rotationReason"
} else {
    Write-Output "No rotation required."
}

if ($primarySecret)
{
    # Log Secret Tags
    Write-Output "Secret '$primarySecretName' found in Key Vault '$KeyVaultName'."
}
else
{
    Write-Output "Secret '$primarySecretName' not found in Key Vault '$KeyVaultName'."
}

Write-Output "Update-SubscriptionSecrets.ps1 execution completed."

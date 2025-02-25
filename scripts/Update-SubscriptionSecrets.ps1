param(
    [string]$KeyVaultName,
    [string]$Prefix
)

Write-Output "Executing Update-SubscriptionSecrets.ps1 on Key Vault: $KeyVaultName, Secret Prefix: $Prefix"

# Fetch secret
$primarySecretName = "$Prefix-PrimaryKey"
$secondarySecretName = "$Prefix-SecondaryKey"
$activeSecretName = "$Prefix-ActiveKey"

$primarySecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $primarySecretName
$secondarySecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secondarySecretName
$activeSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $activeSecretName

$tags = $primarySecret.Tags

$rotationCandidate = $null
$currentDate = [System.DateTime]::UtcNow
#$currentDate = Get-Date
$rotatePrimary = $false
$rotateSecondary = $false

# Get configuration values from the primary tag
$lifespanString = $primarySecret.Tags["Age"]
$lifespan = [System.Xml.XmlConvert]::ToTimeSpan($lifespanString)

Write-Host "$Prefix has an age of $($age.TotalSeconds) seconds"

# Ensure that the primary and secondary secret have an Origin tag. This is the date that is used to calculate the expiration date windows
# It ensures that even if the script is run late, or paused for some time, the expirtation dates will always be consistent and a multiple
# of age from the Origin time.

$primaryOrigin = $null

if (-not $primarySecret.Tags.ContainsKey("Origin")) {
    $primaryOrigin = $currentDate  # ISO 8601 format
    $primarySecret.Tags["Origin"] = $primaryOrigin.ToString("o")

#    $secondaryOrigin = $currentDate.AddSeconds($age.TotalSeconds / 2)
#    $secondarySecret.Tags["Origin"] = $secondaryOrigin.ToString("o")
    Write-Output "Primary secret missing Origin. Setting primary origin to $primaryOrigin and secondary origin to $secondaryOrigin."
}
else
{
    $primaryOrigin = [DateTime]::Parse($primarySecret.Tags["Origin"])
}

$secondaryOrigin = $primaryOrigin.AddSeconds($age.TotalSeconds / 2)

Write-Output "Using date $currentDate for expiration check. $Prefix has a lifespan of $lifespan ($lifespanString)"

if ( $primarySecret.Tags.ContainsKey("ForceRotation") -and $secondarySecret.Tags.ContainsKey("ForceRotation"))
{
    $rotatePrimary = $true
    $rotateSecondary = $true
    $primaryReason = "Primary and secondary keys have ForceRotation tag."
    $secondaryReason = $primaryReason
    
    Write-Output "Both keys are being rotated. This may cause some downtime"
}
elseif ( $primarySecret.Tags.ContainsKey("ForceRotation"))
{
    $rotatePrimary = $true
    $primaryReason = "Primary key has ForceRotation tag."
}
elseif($null -eq $primarySecret.Expires)
{
    $rotatePrimary = $true
    $primaryReason = "Primary key has no expiration date"
}
elseif ($secondarySecret.Tags.ContainsKey("ForceRotation"))
{
    $rotateSecondary = $true
    $secondaryReason = "Secondary key has ForceRotation tag."
}
elseif($null -eq $secondarySecret.Expires)
{
    $rotateSecondary = $true
    $secondaryReason = "Secondary key has no expiration date"
}
elseif ($primarySecret.Expires.ToUniversalTime() -gt $currentDate)
{
    $rotatePrimary = $true
    $primaryReason = "Primary key has expired."
}
elseif ($secondarySecret.Expires.ToUniversalTime() -gt $currentDate)
{
    $rotateSecondary = $true
    $secondaryReason = "Secondary key has expired."
}

if($rotatePrimary -and $rotateSecondary) {
    # Todo: Maybe some special logic to give a 5 minute wait time between key rotations?
}


if ($rotatePrimary)
{
    Write-Output "Secret '$primarySecretName' will be rotated for reason: $primaryReason."

    $primarySecret = & "$PSScriptRoot/Rotate-KeyVaultSecret.ps1" -Secret $primarySecret -CurrentDate $currentDate -KeyVaultName $KeyVaultName -Age $lifespan -Origin $primaryOrigin
}

if ($rotateSecondary)
{
    Write-Output "Secret '$secondarySecretName' will be rotated for reason: $primaryReason."

    $secondarySecret = & "$PSScriptRoot/Rotate-KeyVaultSecret.ps1" -Secret $secondarySecret -CurrentDate $currentDate -KeyVaultName $KeyVaultName -Age $lifespan -Origin $secondaryOrigin
}

if (-not ($rotatePrimary -or $rotateSecondary)) {
    Write-Output "No keys need to be rotated for $Prefix."
}
else
{
    if ($primarySecret.Expires -gt $secondarySecret.Expires) {
        $latestSecret = $primarySecret
        Write-Output "Primary secret selected (expires $($primarySecret.Expires))."
    } else {
        $latestSecret = $secondarySecret
        Write-Output "Secondary secret selected (expires $($secondarySecret.Expires))."
    }

    $activeSecretTags = @{
        'Source' =  $latestSecret.Name
    }
    
    Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $activeSecretName -SecretValue $latestSecret.SecretValue -Tag $activeSecretTags -Expires $latestSecret.Expires
}

Write-Output "Update-SubscriptionSecrets.ps1 execution completed."


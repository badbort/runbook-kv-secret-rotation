param(
    [string]$KeyVaultName,
    [string]$Prefix
)

$InformationPreference = "Continue"

Write-Host "Executing Update-SubscriptionSecrets.ps1 on Key Vault: $KeyVaultName, Secret Prefix: $Prefix =============================="

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
$rotatePrimary = $false
$rotateSecondary = $false

# Get configuration values from the primary tag
$lifespanString = $primarySecret.Tags["Age"]
$lifespan = [System.Xml.XmlConvert]::ToTimeSpan($lifespanString)

# Ensure that the primary and secondary secret have an Origin tag. This is the date that is used to calculate the expiration date windows
# It ensures that even if the script is run late, or paused for some time, the expirtation dates will always be consistent and a multiple
# of age from the Origin time.

$primaryOrigin = $null

# Origin is considered the date that the secret rotaton should always align with. No matter if the script was
# late, or there was a forced rotation, the expiration should always fall on a multiple of Age from the Origin
if ($primarySecret.Expires -eq $null)
{
    $primaryOrigin = $currentDate
    Write-Host "Primary secret does not have expiration. Using date $primaryOrigin for origin" -ForegroundColor Yellow
}
else
{
    #    $primaryOrigin = [DateTime]::Parse($primarySecret.Tags["Origin"])
    $primaryOrigin = $primarySecret.Expires
}

$secondaryOrigin = $primaryOrigin.AddTicks($lifespan.Ticks * -2.5)

# Old tag based Origin approach
#if (-not $primarySecret.Tags.ContainsKey("Origin")) {
#    $primaryOrigin = $currentDate  # ISO 8601 format
##    $primarySecret.Tags["Origin"] = $primaryOrigin.ToString("o")
#
##    $secondaryOrigin = $currentDate.AddSeconds($age.TotalSeconds / 2)
##    $secondarySecret.Tags["Origin"] = $secondaryOrigin.ToString("o")
#    Write-Information "Primary secret missing Origin. Setting primary origin to $primaryOrigin and secondary origin to $secondaryOrigin."
#}
#else
#{
#    $primaryOrigin = [DateTime]::Parse($primarySecret.Tags["Origin"])
#}

# Write-Information "Using date $currentDate for expiration check. $Prefix has a lifespan of $lifespan ($lifespanString)"

if ($primarySecret.Tags.ContainsKey("ForceRotation") -and $secondarySecret.Tags.ContainsKey("ForceRotation"))
{
    $rotatePrimary = $true
    $rotateSecondary = $true
    $primaryReason = "Primary and secondary keys have ForceRotation tag."
    $secondaryReason = $primaryReason

    Write-Host "Both keys are being rotated due to ForceRotation tag. This may cause some downtime." -ForegroundColor Magenta
}
elseif ( $primarySecret.Tags.ContainsKey("ForceRotation"))
{
    $rotatePrimary = $true
    $primaryReason = "Primary key has ForceRotation tag."
}
elseif ($secondarySecret.Tags.ContainsKey("ForceRotation"))
{
    $rotateSecondary = $true
    $secondaryReason = "Secondary key has ForceRotation tag."
}
elseif($primarySecret.Expires -eq $null)
{
    $rotatePrimary = $true
    $primaryReason = "Primary key has no expiration date"
}
elseif($null -eq $secondarySecret.Expires)
{
    $rotateSecondary = $true
    $secondaryReason = "Secondary key has no expiration date"
}
elseif ($primarySecret.Expires.ToUniversalTime() -lt $currentDate)
{
    $rotatePrimary = $true
    $primaryReason = "Primary key has expired."
}
elseif ($secondarySecret.Expires.ToUniversalTime() -lt $currentDate)
{
    $rotateSecondary = $true
    $secondaryReason = "Secondary key has expired."
}

if ($rotatePrimary -and $rotateSecondary)
{
    # Todo: Maybe some special logic to give a 5 minute wait time between key rotations?
}

if ($rotatePrimary)
{
    Write-Host "Rotating secret '$primarySecretName' for reason: $primaryReason" -ForegroundColor Blue
    $primarySecret = & "$PSScriptRoot/Rotate-KeyVaultSecret.ps1" -Secret $primarySecret -CurrentDate $currentDate -KeyVaultName $KeyVaultName -Age $lifespan -Origin $primaryOrigin
}

if ($rotateSecondary)
{
    Write-Host "Rotating secret '$secondarySecretName' for reason: $secondaryReason" -ForegroundColor Blue
    $secondarySecret = & "$PSScriptRoot/Rotate-KeyVaultSecret.ps1" -Secret $secondarySecret -CurrentDate $currentDate -KeyVaultName $KeyVaultName -Age $lifespan -Origin $secondaryOrigin
}

# Update active secret
if (-not ($rotatePrimary -or $rotateSecondary))
{
    Write-Host "No keys were changed for $Prefix." -ForegroundColor Green
}
else
{
    $latestSecret = $null

    if ($primarySecret.Expires -gt $secondarySecret.Expires)
    {
        $latestSecretName = $primarySecretName
        $latestSecret = $primarySecret
        Write-Host "ActiveKey updated: Primary secret selected (expires $( $primarySecret.Expires ))." -ForegroundColor Cyan
    }
    else
    {
        $latestSecretName = $secondarySecretName
        $latestSecret = $secondarySecret
        Write-Host "ActiveKey updated: Secondary secret selected (expires $( $secondarySecret.Expires ))." -ForegroundColor Cyan
    }

    $activeSecretTags = @{
        'Source' = $latestSecret.Name
    }

    Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $activeSecretName -SecretValue $latestSecret.SecretValue -Tag $activeSecretTags -Expires $latestSecret.Expires
}

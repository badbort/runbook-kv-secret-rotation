param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [string]$KeyVaultName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [object]$Secret,
    [Parameter(Mandatory=$true)]
    [DateTime]$CurrentDate,
    [Parameter(Mandatory=$true)]
    [DateTime]$Origin,
    [Parameter(Mandatory=$true)]
    [TimeSpan]$Age
)


function Generate-RandomPassword
{
    return & "$PSScriptRoot/Get-RandomPassword.ps1" -Length 4
}

$newSecretValue = Generate-RandomPassword
$secretName = $Secret.Name

$tags = $Secret.Tags.Clone()

# Always remove ForceRotation as we have succeeded
if ($tags.ContainsKey("ForceRotation")) {
    $tags.Remove("ForceRotation")
}

$elapsed = ($CurrentDate - $Origin).Ticks
$periodsElapsed = [math]::Floor($elapsed / $Age.Ticks)
$newExpiry = $Origin.AddTicks($Age.Ticks * ($periodsElapsed + 1))

Write-Host "Rotating secret '$secretName'. New expiry will be $newExpiry (calculated from Origin $Origin)."

# Create the new version of the secret with the new value, calculated expiry, and updated tags.
$newSecret = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName `
        -SecretValue (ConvertTo-SecureString $newSecretValue -AsPlainText -Force) `
        -Expires $newExpiry `
        -Tag $tags

Write-Host "$secretName was rotated. Expiration $newExpiry (calculated from Origin $Origin)." -ForegroundColor Green

return $newSecret
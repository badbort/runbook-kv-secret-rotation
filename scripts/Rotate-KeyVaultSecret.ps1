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

$newSecretValue = & "$PSScriptRoot/Get-RandomPassword.ps1" -Length 4
$secretName = $Secret.Name

$tags = $Secret.Tags.Clone()

if ($tags.ContainsKey("ForceRotation")) {
    $tags.Remove("ForceRotation")
}

$elapsed = ($CurrentDate - $Origin).Ticks
$periodsElapsed = [math]::Floor($elapsed / $Age.Ticks)
$newExpiry = $origin.AddTicks($Age.Ticks * ($periodsElapsed + 1))

Write-Output "Rotating secret '$secretName'. New expiry will be $newExpiry (calculated from Origin $origin)."

# Create the new version of the secret with the new value, calculated expiry, and updated tags.
$newSecret = Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName `
        -SecretValue (ConvertTo-SecureString $newSecretValue -AsPlainText -Force) `
        -Expires $newExpiry `
        -Tag $tags

Write-Output "Rotated:"
Write-Output $newSecret

$newSecret
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [string]$KeyVaultName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [object]$Secret,
    [Parameter(Mandatory=$true)]
    [datetime]$CurrentDate
)

$newSecretValue = & "$PSScriptRoot/Get-RandomPassword.ps1" -Length 4
$secretName = $Secret.Name

$newTags = $Secret.Tags.Clone()

if ($newTags.ContainsKey("ForceRotation")) {
    $newTags.Remove("ForceRotation")
}

$origin = [datetime]$newTags["Origin"]

$elapsed = ($CurrentDate - $origin).Ticks
$periodsElapsed = [math]::Floor($elapsed / $Lifespan.Ticks)
$newExpiry = $origin.AddTicks($Lifespan.Ticks * ($periodsElapsed + 1))

Write-Output "Rotating secret '$secretName'. New expiry will be $newExpiry (calculated from Origin $origin)."

# Create the new version of the secret with the new value, calculated expiry, and updated tags.
Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secretName `
        -SecretValue (ConvertTo-SecureString $newSecretValue -AsPlainText -Force) `
        -Expires $newExpiry `
        -Tag $newTags
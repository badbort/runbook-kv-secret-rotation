param(
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName
)

Write-Host "Starting removal of previous secret versions from Key Vault: $KeyVaultName" -ForegroundColor Cyan

$secrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName

foreach ($purgedSecret in $secrets)
{
    Write-Host ($purgedSecret | Format-List * -Force | Out-String)
    
    $purgeSecretName = $purgedSecret.Name
    $secretValue = $purgedSecret.SecretValue
    $secretTags = $purgedSecret.Tags
    $secretExpires = $purgedSecret.Expires

    # Delete the secret (this deletes all versions)
    Write-Host "Deleting secret: $purgeSecretName"
    try
    {
        Remove-AzKeyVaultSecret -VaultName $KeyVaultName -Name $purgeSecretName -Force
        Write-Host "  Successfully deleted secret: $purgeSecretName" -ForegroundColor Green
    }
    catch
    {
        Write-Host "  Failed to delete secret: $purgeSecretName. Error: $_" -ForegroundColor Red
        continue
    }

    # Pause briefly to ensure deletion completes before re-creation.
    Start-Sleep -Seconds 5

    # Re-create the secret with the same value, tags, and expiration.
    Write-Host "Recreating secret: $purgeSecretName"
    try {
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $purgeSecretName `
            -SecretValue $secretValue -Expires $secretExpires -Tag $secretTags
        Write-Host "  Successfully recreated secret: $purgeSecretName" -ForegroundColor Green
    }
    catch {
        Write-Host "  Failed to recreate secret: $purgeSecretName. Error: $_" -ForegroundColor Red
    }
}

Write-Host "Purging removed secrets" -ForegroundColor Cyan

$purgeSecrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName -InRemovedState

foreach ($purgedSecret in $purgeSecrets)
{
    Write-Host ($purgedSecret | Format-List * -Force | Out-String)
    $purgeSecretName = $purgedSecret.Name

    # Delete the secret (this deletes all versions)
    Write-Host "Deleting secret: $purgeSecretName"
    try
    {
        Remove-AzKeyVaultSecret -VaultName $KeyVaultName -Name $purgeSecretName -Force -InRemovedState
        Write-Host "  Successfully deleted secret: $purgeSecretName" -ForegroundColor Green
    }
    catch
    {
        Write-Host "  Failed to delete secret: $purgeSecretName. Error: $_" -ForegroundColor Red
        continue
    }
}

Write-Host "Completed removal of previous secret versions." -ForegroundColor Cyan

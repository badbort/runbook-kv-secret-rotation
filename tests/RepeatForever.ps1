param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [string]$TeamName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [string]$KeyVaultName
)

Write-Host "=========================================="
Write-Host " Running Secret Rotation Loop "
Write-Host "=========================================="

# Get the timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$tfDir = "$PSScriptRoot\..\infrastructure"

# Run Terraform apply, stream output to console and log file
& terraform -chdir=$tfDir apply -auto-approve

# Infinite loop to run Terraform apply every minute
while ($true) {
    & "$PSScriptRoot/../scripts/Update-TeamKeyVault.ps1" -KeyVaultName $KeyVaultName -TeamName $TeamName

    Write-Host "===== Waiting 5 seconds before next apply =====" -ForegroundColor Gray
    Start-Sleep -Seconds 5
}

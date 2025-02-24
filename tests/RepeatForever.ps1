param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [string]$TeamName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [string]$KeyVaultName
)

Write-Host "=========================================="
Write-Host " Running Terraform Apply - Auto Approve "
Write-Host "=========================================="

# Get the timestamp
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "[$timestamp] Running terraform apply..."

$tfDir = "$PSScriptRoot\..\infrastructure"

# Run Terraform apply, stream output to console and log file
& terraform -chdir=$tfDir apply -auto-approve

# Infinite loop to run Terraform apply every minute
while ($true) {
    Write-Host "=========================================="
    Write-Host " Running Terraform Apply - Auto Approve "
    Write-Host "=========================================="

    & "$PSScriptRoot/../scripts/Update-TeamKeyVault.ps1" -KeyVaultName $KeyVaultName -TeamName $TeamName

    Write-Host "Waiting 30 seconds before next apply..."
    Start-Sleep -Seconds 30
}

# MyAutomationModule.psm1
# Load all function files dynamically

$modulePath = Split-Path -Parent $MyInvocation.MyCommand.Path
Get-ChildItem -Path $modulePath -Filter "*.ps1" | ForEach-Object {
    Write-Verbose "Importing function file: $($_.FullName)" -Verbose
    . $_.FullName
}

Export-ModuleMember -Function Update-SubscriptionSecrets, Update-DestinationKeyVault

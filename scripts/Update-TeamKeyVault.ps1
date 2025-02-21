param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [string]$TeamName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [string]$KeyVaultName
)

Write-Output "Executing Update-TeamKeyVault.ps1"
Write-Output "Team: $TeamName"
Write-Output "Key Vault: $KeyVaultName"
Write-Output "Env variables:"
Get-ChildItem -Path Env:* | ForEach-Object { Write-Output "$($_.Name)=$($_.Value)" }


if($env:AUTOMATION_ASSET_ACCOUNTID){
    
}

# Ensure we are authenticated
if (-not (Get-AzContext))
{
    Write-Output "Not authenticated. Running Connect-AzAccount..."
    Connect-AzAccount -Identity
}

# Get all secrets matching "*-PrimaryKey"
$secrets = Get-AzKeyVaultSecret -VaultName $KeyVaultName | Where-Object { $_.Name -match "-PrimaryKey$" }

if (-not $secrets)
{
    Write-Output "No primary key secrets found in Key Vault '$KeyVaultName'."
    exit 0
}

Write-Output "PSScriptRoot: $PSScriptRoot"
Write-Output "PSPrivateMetadata.JobId: $($PSPrivateMetadata.JobId)"

$total = $secrets.Length
$currentSecret = 0

foreach ($secret in $secrets)
{
    # Extract secret prefix from the secret name
    $prefix = $secret.Name -replace "-PrimaryKey", ""

    # Get secret metadata (tags)
    $secretDetails = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $secret.Name
    $tags = $secretDetails.Tags

    if ($tags)
    {
        Write-Output "Tags for $( $secret.Name ): $( $tags | ConvertTo-Json -Depth 2 )"
    }
    else
    {
        Write-Output "No tags found for $( $secret.Name )"
    }

    if(-not $tags.ContainsKey("Age")) {
        Write-Output "Skipping $prefix as is has no defined rotation"
        continue
    }
    
    Write-Output "Processing Subscription: $prefix"

    # Call Update-SubscriptionSecrets.ps1

    # For now we cannot run scripts inline in 7.2. When this is supported the scripts should be invoked using the same
    # mechanism when running locally and running from the main runbook
    # https://learn.microsoft.com/en-us/answers/questions/1656487/support-for-inline-child-scripts-in-powershell-7-2
    if ($PSPrivateMetadata.JobId -and $false) {
        # Azure Automation
        $parameters = @{
            "Table" = $tableName
            "KeyVaultName" = $KeyVaultName
            "Prefix" = $prefix
        }

        Write-Host "Running SubscriptionSecrets runbook"

        Start-AzAutomationRunbook -Name "Update-SubscriptionSecrets" -Parameters $parameters
    } else {
        
        Write-Host "Running SubscriptionSecrets locally"
        
        & "$PSScriptRoot/Update-SubscriptionSecrets.ps1" -KeyVaultName $KeyVaultName -Prefix $prefix
    }
    
    # If DestinationSecret tag exists, invoke Update-DestinationKeyVault.ps1
    if ($tags -and $tags.ContainsKey("DestinationSecret"))
    {
        $destinationSecretId = $tags["DestinationSecret"]
        Write-Output "DestinationSecret found: $destinationSecretId"

        & "$PSScriptRoot/Update-DestinationKeyVault.ps1" -SubscriptionId $prefix -DestinationSecretId $destinationSecretId
    }

#    Write-Progress -Activity "Processing subscriptions" -Status "Step $currentSecret of $total" -PercentComplete (($currentSecret / $total) * 100)
}

Write-Output "Update-TeamKeyVault.ps1 execution completed."

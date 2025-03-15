#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.7.0" }

Import-Module Pester -ErrorAction Stop

Describe "Rotate-KeyVaultSecret Tests" {

    # Helper: Create a dummy secret object with optional Age and Origin.
    function New-DummySecret {
        param (
            [Parameter(Mandatory = $true)]
            [string]$Name,
            [TimeSpan]$Age = $null,
            [DateTime]$Origin = $null,
            [hashtable]$AdditionalTags = @{}
        )

        $tags = @{}
        if ($Age) {
            $tags["Age"] = $Age.ToString()
        }
        if ($Origin) {
            $tags["Origin"] = $Origin.ToString("o")
        }
        foreach ($key in $AdditionalTags.Keys) {
            $tags[$key] = $AdditionalTags[$key]
        }

        return [PSCustomObject]@{
            Name        = $Name
            Tags        = $tags
            # Dummy values for Expires and Created (they aren't used for expiry calculation)
            Expires     = (Get-Date).AddHours(1)
            Created     = (Get-Date).AddMinutes(-10)
            SecretValue = (ConvertTo-SecureString "InitialSecretValue" -AsPlainText -Force)
            Id          = "https://dummy.vault.azure.net/secrets/$Name/dummyversion"
        }
    }

    # Common dummy variables.
    $dummyKeyVault = "dummyVault"
    $dummySecretName = "Test-Secret"

    # Variable to capture parameters passed to Set-AzKeyVaultSecret.
    $script:setSecretParams = $null

    # Mocks for external dependencies are defined inside BeforeAll.
    BeforeAll {
        # When Get-RandomPassword.ps1 is called, always return "dummyPassword".
        Mock -CommandName Generate-RandomPassword -MockWith { return "dummyPassword" }

        # Capture parameters for Set-AzKeyVaultSecret.
        Mock -CommandName Set-AzKeyVaultSecret -MockWith {
            param(
                [string]$VaultName,
                [string]$Name,
                [System.Security.SecureString]$SecretValue,
                [hashtable]$Tag,
                [DateTime]$Expires
            )
            $script:setSecretParams = @{
                VaultName   = $VaultName
                Name        = $Name
                SecretValue = $SecretValue
                Tag         = $Tag
                Expires     = $Expires
            }
            return [PSCustomObject]$script:setSecretParams
        }
    }

    BeforeEach {
        # Reset captured parameters before each test.
        $script:setSecretParams = $null
    }

    Context "When CurrentDate equals Origin" {
        It "should set expiry to Origin + Age" {
            $Origin = Get-Date "2023-01-01T00:00:00Z"
            $Age = [TimeSpan]::FromHours(1)
            $CurrentDate = $Origin

            $Secret = New-DummySecret -Name $dummySecretName -Age $Age -Origin $Origin

            $result = & "$PSScriptRoot\Rotate-KeyVaultSecret.ps1" `
                -KeyVaultName $dummyKeyVault -Secret $Secret -CurrentDate $CurrentDate -Origin $Origin -Age $Age

            # Expected: since no time has elapsed, next period is 1 Age from Origin.
            $expectedExpiry = $Origin.Add($Age)
            $result.Expires | Should -BeExactly $expectedExpiry
        }
    }

    Context "When CurrentDate is between multiples" {
        It "should set expiry to the next multiple of Age from Origin" {
            $Origin = Get-Date "2023-01-01T00:00:00Z"
            $Age = [TimeSpan]::FromHours(1)
            $CurrentDate = $Origin.AddMinutes(30)

            $Secret = New-DummySecret -Name $dummySecretName -Age $Age -Origin $Origin

            $result = & "$PSScriptRoot\Rotate-KeyVaultSecret.ps1" `
                -KeyVaultName $dummyKeyVault -Secret $Secret -CurrentDate $CurrentDate -Origin $Origin -Age $Age

            # Expected expiry: still Origin + 1 Age.
            $expectedExpiry = $Origin.Add($Age)
            $result.Expires | Should -BeExactly $expectedExpiry
        }
    }

    Context "When CurrentDate equals a multiple of Age from Origin" {
        It "should set expiry to the next multiple (i.e. add one more Age)" {
            $Origin = Get-Date "2023-01-01T00:00:00Z"
            $Age = [TimeSpan]::FromHours(1)
            $CurrentDate = $Origin.AddHours(1)

            $Secret = New-DummySecret -Name $dummySecretName -Age $Age -Origin $Origin

            $result = & "$PSScriptRoot\Rotate-KeyVaultSecret.ps1" `
                -KeyVaultName $dummyKeyVault -Secret $Secret -CurrentDate $CurrentDate -Origin $Origin -Age $Age

            # Calculation:
            # periodsElapsed = Floor(1 hour / 1 hour) = 1, then next expiry = Origin + (1+1)*Age = Origin + 2 hours.
            $expectedExpiry = $Origin.AddHours(2)
            $result.Expires | Should -BeExactly $expectedExpiry
        }
    }

    Context "When CurrentDate is well beyond multiple periods" {
        It "should calculate the next multiple correctly" {
            $Origin = Get-Date "2023-01-01T00:00:00Z"
            $Age = [TimeSpan]::FromMinutes(30)
            # Set CurrentDate to 140 minutes after Origin.
            $CurrentDate = $Origin.AddMinutes(140)

            $Secret = New-DummySecret -Name $dummySecretName -Age $Age -Origin $Origin

            $result = & "$PSScriptRoot\Rotate-KeyVaultSecret.ps1" `
                -KeyVaultName $dummyKeyVault -Secret $Secret -CurrentDate $CurrentDate -Origin $Origin -Age $Age

            # Calculation:
            # 140 minutes elapsed, Age is 30 minutes → periodsElapsed = Floor(140/30) = 4.
            # Next expiry = Origin + (4+1)*30 minutes = Origin + 150 minutes.
            $expectedExpiry = $Origin.AddMinutes(150)
            $result.Expires | Should -BeExactly $expectedExpiry
        }
    }
}

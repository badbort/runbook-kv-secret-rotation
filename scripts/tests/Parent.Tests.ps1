# Tests\Parent.Tests.ps1

Import-Module Pester -ErrorAction Stop

BeforeAll {
    . "$PSScriptRoot\..\Parent.ps1"
}

Describe "Parent Script Tests" {

    BeforeAll {
        Mock -CommandName Get-ChildOutput -MockWith { "Mocked Child Output" }
    }
    
    It "returns expected output when Get-ChildOutput is mocked" {
        $result = Do-ParentWork
        $result | Should -Be "Parent got: Mocked Child Output"
    }
}

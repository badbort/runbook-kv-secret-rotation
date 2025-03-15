# Parent.ps1

function Get-ChildOutput {
    # Calls the child script and returns its output.
    return & "$PSScriptRoot\Child.ps1"
}

function Do-ParentWork {
    $childOutput = Get-ChildOutput
    return "Parent got: $childOutput"
}

# When the script is run, output the result.
Do-ParentWork

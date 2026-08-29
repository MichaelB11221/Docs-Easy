function Invoke-ExecAll {
    <#
    .SYNOPSIS
        Executes all scripts (.ps1, .cmd, .bat, .vbs) and merges all .reg files in the current directory.
    .DESCRIPTION
        Runs each file with .\filename style so it works in any directory.
    #>

    Write-Host "Executing all scripts and merging registry files in $PWD" -ForegroundColor Cyan

    # PowerShell scripts
    Get-ChildItem -Filter *.ps1 | ForEach-Object {
        Write-Host "Running PowerShell script: $_"
        & .\$_
    }

    # CMD/BAT scripts
    Get-ChildItem -Include *.cmd, *.bat | ForEach-Object {
        Write-Host "Running batch script: $_"
        & .\$_
    }

    # VBScript files
    Get-ChildItem -Filter *.vbs | ForEach-Object {
        Write-Host "Running VBScript: $_"
        cscript //nologo .\$_
    }

    # Registry files
    Get-ChildItem -Filter *.reg | ForEach-Object {
        Write-Host "Merging registry file: $_"
        reg import .\$_
    }

    Write-Host "✅ Done." -ForegroundColor Green
}

# Create alias
Set-Alias execall Invoke-ExecAll

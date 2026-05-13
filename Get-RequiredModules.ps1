function Get-RequiredModules {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    # Check if file exists
    if (-not (Test-Path $ScriptPath)) {
        Write-Error "File not found: $ScriptPath"
        return
    }

    # Read script content
    $scriptContent = Get-Content -Path $ScriptPath -Raw

    # Extract modules from `#Requires -Modules`
    $requiresModules = [regex]::Matches($scriptContent, '#Requires\s+-Modules\s+([^\r\n]+)') | ForEach-Object { $_.Groups[1].Value.Trim() }

    # Extract modules from `Import-Module`
    $importModules = [regex]::Matches($scriptContent, 'Import-Module\s+([''"]?)([^''""\s]+)\1') | ForEach-Object { $_.Groups[2].Value.Trim() }

    # Combine and remove duplicates
    $allModules = @($requiresModules) + @($importModules) | Select-Object -Unique

    # Output the modules
    if ($allModules.Count -gt 0) {
        Write-Output "Required Modules for '$ScriptPath':"
        $allModules | ForEach-Object { Write-Output "- $_" }
        return $allModules
    } else {
        Write-Output "No required modules found in '$ScriptPath'."
        return @()
    }
}

# Example Usage
# Get-RequiredModules -ScriptPath "C:\Path\To\YourScript.ps1"
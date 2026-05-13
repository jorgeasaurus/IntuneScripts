function New-DynamicDeviceModelGroups {
    <#
    .SYNOPSIS
        Creates dynamic Entra groups for device models based on operating system.

    .DESCRIPTION
        Retrieves requested Intune managed devices from Microsoft Graph with pagination, identifies
        unique device models per operating system, and creates OS-scoped dynamic
        membership groups for each model.

        The generated membership rules use Entra dynamic device properties. Intune reports
        broad operating system values such as iOS and macOS, but Entra deviceOSType values
        can be more specific, so this function maps each supported OS to an Entra rule
        fragment before creating the group.

    .PARAMETER OperatingSystems
        Array of operating systems to filter devices by. Valid values: Windows, iOS, Android, macOS.

    .PARAMETER GroupNamePrefix
        Prefix for generated group display names. The default is All.

    .PARAMETER WhatIf
        Shows what would happen if the cmdlet runs. The cmdlet is not run.

    .PARAMETER Confirm
        Prompts you for confirmation before running the cmdlet.

    .EXAMPLE
        New-DynamicDeviceModelGroups -OperatingSystems "Windows"

        Creates dynamic groups for all Windows device models.

    .EXAMPLE
        New-DynamicDeviceModelGroups -OperatingSystems "Windows", "macOS" -WhatIf

        Shows what groups would be created for Windows and macOS devices without actually creating them.

    .EXAMPLE
        New-DynamicDeviceModelGroups -OperatingSystems "Windows" -GroupNamePrefix "Prod"

        Creates dynamic groups using names like Prod - Windows - Model - Latitude 5450.

    .NOTES
        Requires Microsoft Graph PowerShell SDK with appropriate permissions:
        - DeviceManagementManagedDevices.Read.All
        - Group.ReadWrite.All

        Connect before running:
        Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "Group.ReadWrite.All"
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Existing public command creates groups for multiple device models.')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Windows", "iOS", "Android", "macOS")]
        [string[]]$OperatingSystems,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$GroupNamePrefix = "All"
    )

    $graphContext = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $graphContext) {
        $exception = [System.InvalidOperationException]::new('Microsoft Graph is not connected. Run Connect-MgGraph -Scopes "DeviceManagementManagedDevices.Read.All", "Group.ReadWrite.All" before calling this function.')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'MicrosoftGraphNotConnected',
            [System.Management.Automation.ErrorCategory]::ConnectionError,
            $null
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $uniqueOperatingSystems = $OperatingSystems | Select-Object -Unique
    $operatingSystemFilter = ($uniqueOperatingSystems | ForEach-Object { "operatingSystem eq '$($_)'" }) -join " or "
    $encodedOperatingSystemFilter = [System.Uri]::EscapeDataString($operatingSystemFilter)

    $allDevices = [System.Collections.Generic.List[object]]::new()
    $existingGroups = [System.Collections.Generic.List[object]]::new()

    Write-Verbose "Retrieving managed devices from Microsoft Graph..."
    $uri = "beta/deviceManagement/managedDevices?`$select=id,model,operatingSystem&`$filter=$encodedOperatingSystemFilter"

    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        if ($response.Value) {
            $allDevices.AddRange($response.Value)
        }
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    Write-Verbose "Retrieved $($allDevices.Count) total managed devices."
    Write-Verbose "Retrieving existing dynamic groups for duplicate checking..."

    $groupUri = "beta/groups?`$select=id,displayName,mailNickname&`$filter=groupTypes/any(g:g eq 'DynamicMembership')"

    do {
        $groupResponse = Invoke-MgGraphRequest -Method GET -Uri $groupUri -ErrorAction Stop
        if ($groupResponse.Value) {
            $existingGroups.AddRange($groupResponse.Value)
        }
        $groupUri = $groupResponse.'@odata.nextLink'
    } while ($groupUri)

    $existingByDisplayName = @{}
    $existingByMailNickname = @{}

    foreach ($group in $existingGroups) {
        if (-not [string]::IsNullOrWhiteSpace($group.displayName)) {
            $existingByDisplayName[$group.displayName] = $group
        }

        if (-not [string]::IsNullOrWhiteSpace($group.mailNickname)) {
            $existingByMailNickname[$group.mailNickname] = $group
        }
    }

    foreach ($os in $uniqueOperatingSystems) {
        Write-Verbose "Processing $os devices..."

        $osDevices = $allDevices | Where-Object { $_.operatingSystem -eq $os }

        if ($osDevices.Count -eq 0) {
            Write-Warning "No $os devices found to process."
            continue
        }

        $models = $osDevices |
            ForEach-Object { $_.model } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique

        Write-Verbose "Found $($models.Count) unique $os device models."

        if ($models.Count -eq 0) {
            Write-Warning "No $os devices with model data found to process."
            continue
        }

        $osRule = switch ($os) {
            "Windows" { 'device.deviceOSType -eq "Windows"' }
            "iOS" { '(device.deviceOSType -eq "iPad") -or (device.deviceOSType -eq "iPhone")' }
            "Android" { '(device.deviceOSType -startsWith "Android") -or (device.deviceOSType -eq "AndroidForWork")' }
            "macOS" { 'device.deviceOSType -contains "Mac"' }
        }

        foreach ($model in $models) {
            $modelName = [string]$model
            $groupDisplayName = "$GroupNamePrefix - $os - Model - $modelName"
            $groupDisplayName = $groupDisplayName -replace '[<>:"/\\|?*]', '' -replace '[\[\]]', '' -replace '\s+', ' ' -replace '^\s+|\s+$', ''

            $mailNickname = $groupDisplayName -replace '[^a-zA-Z0-9.-]', '' -replace '\.+', '.' -replace '^-+|-+$', '' -replace '^\.+|\.+$', ''
            $mailNickname = $mailNickname.ToLower()

            if ([string]::IsNullOrEmpty($mailNickname) -or $mailNickname.Length -lt 3) {
                $mailNickname = "model-$($os)-$($modelName -replace '[^a-zA-Z0-9]', '')".ToLower()
            }

            $existingGroup = $existingByDisplayName[$groupDisplayName]
            if (-not $existingGroup) {
                $existingGroup = $existingByMailNickname[$mailNickname]
            }

            if ($existingGroup) {
                Write-Verbose "Group already exists: $groupDisplayName"

                [PSCustomObject]@{
                    OperatingSystem = $os
                    DeviceModel     = $modelName
                    GroupName       = $groupDisplayName
                    Status          = "AlreadyExists"
                    GroupId         = $existingGroup.id
                    Reason          = "Group already exists"
                    Error           = $null
                }
                continue
            }

            $escapedModel = $modelName -replace '`', '``' -replace '"', '`"'
            $membershipRule = "($osRule) -and (device.deviceModel -eq `"$escapedModel`")"

            if (-not $PSCmdlet.ShouldProcess($groupDisplayName, "Create dynamic Entra group")) {
                $status = if ($WhatIfPreference) { "Previewed" } else { "Declined" }

                [PSCustomObject]@{
                    OperatingSystem = $os
                    DeviceModel     = $modelName
                    GroupName       = $groupDisplayName
                    Status          = $status
                    GroupId         = $null
                    Reason          = "ShouldProcess returned false"
                    Error           = $null
                }
                continue
            }

            $params = @{
                displayName                   = $groupDisplayName
                mailEnabled                   = $false
                mailNickname                  = $mailNickname
                securityEnabled               = $true
                groupTypes                    = @("DynamicMembership")
                membershipRule                = $membershipRule
                membershipRuleProcessingState = "On"
            }

            try {
                $result = Invoke-MgGraphRequest -Method POST -Uri "beta/groups" -Body ($params | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction Stop

                $existingByDisplayName[$groupDisplayName] = $result
                $existingByMailNickname[$mailNickname] = $result

                Write-Verbose "Created group: $groupDisplayName"

                [PSCustomObject]@{
                    OperatingSystem = $os
                    DeviceModel     = $modelName
                    GroupName       = $groupDisplayName
                    Status          = "Created"
                    GroupId         = $result.id
                    Reason          = $null
                    Error           = $null
                }
            }
            catch {
                $errorDetails = $_.Exception.Message

                if ($_.ErrorDetails.Message) {
                    try {
                        $errorObject = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction Stop
                        if ($errorObject.error.message) {
                            $errorDetails = $errorObject.error.message
                        }
                    }
                    catch {
                        Write-Debug "Failed to parse Graph error response JSON: $($_.Exception.Message)"
                    }
                }

                Write-Error "Failed to create group '$groupDisplayName': $errorDetails"

                [PSCustomObject]@{
                    OperatingSystem = $os
                    DeviceModel     = $modelName
                    GroupName       = $groupDisplayName
                    Status          = "Failed"
                    GroupId         = $null
                    Reason          = "Graph request failed"
                    Error           = $errorDetails
                }
            }
        }
    }
}

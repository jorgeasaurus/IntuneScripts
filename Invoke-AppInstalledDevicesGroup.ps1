<#
.AUTHOR
    jorgeasaurus
.DESCRIPTION
    This function manages a group of devices with a specified application installed.
    It adds devices to the group if the application is detected and removes devices from the group if the application is no longer detected.
.PARAMETER AppDisplayName
    The display name of the application to search for.
.EXAMPLE
    Invoke-AppInstalledDevicesGroup -AppDisplayName "Adobe Acrobat (64-bit)"
    This example manages a group of devices with Adobe Acrobat (64-bit) installed.
.NOTES
    Required Powershell Modules:
    Name                                              Version
    ----                                              -------
    Microsoft.Graph.Authentication                    2.15.0
    Microsoft.Graph.Beta.DeviceManagement             2.15.0
    Microsoft.Graph.Beta.Groups                       2.15.0
    Microsoft.Graph.Beta.Identity.DirectoryManagement 2.15.0

    Required Microsoft Graph API Permissions:
    - DeviceManagementConfiguration.ReadWrite.All
    - DeviceManagementManagedDevices.ReadWrite.All
    - Directory.ReadWrite.All
    - Group.ReadWrite.All
    - GroupMember.ReadWrite.All
    - Device.ReadWrite.All
#>
function Invoke-AppInstalledDevicesGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppDisplayName
    )

    try {
        # Retrieve detected installations of the specified application
        $DetectedInstalls = Get-MgBetaDeviceManagementDetectedApp -Filter "displayname eq '$AppDisplayName'" -ErrorAction Stop

        if ($null -ne $DetectedInstalls) {

            # Retrieve hostnames of devices where the application is detected
            $DetectedInstallHostnames = $DetectedInstalls | ForEach-Object {
                $DetectedInstall = $_
                Get-MgBetaDeviceManagementDetectedAppManagedDevice -DetectedAppId $DetectedInstall.id -ErrorAction Stop | Select-Object DeviceName
            }

            # Define group details
            $GroupName = "$($AppDisplayName -replace '[^a-zA-Z0-9]', '')_Installed_Devices" # Remove space and characters for MailNickname
            $GroupDescription = "Devices with [$AppDisplayName] installed"

            # Check if the group already exists
            $Group = Get-MgBetaGroup -Filter "displayName eq '$GroupName'" -ErrorAction Stop | Select-Object -First 1

            # Create the group if it doesn't exist
            if (-not $Group) {
                $GroupParams = @{
                    DisplayName     = $GroupName
                    Description     = $GroupDescription
                    MailEnabled     = $false
                    MailNickname    = $GroupName
                    SecurityEnabled = $true
                    GroupTypes      = @()
                }
                $Group = New-MgBetaGroup @GroupParams
                Write-Host "Group '$GroupName' created."
            }

            # Get current members of the group
            $CurrentGroupMembers = Get-MgBetaGroupMember -GroupId $Group.Id -ErrorAction Stop | ForEach-Object { Get-MgBetaDevice -DeviceId $_.Id -ErrorAction Stop }

            # Loop through detected installations to add devices to the group
            $DetectedInstallHostnames | ForEach-Object {

                $DetectedInstallHostname = $_

                # Check if the device is already a member of the group
                $IsInGroup = $CurrentGroupMembers | Where-Object { $_.DisplayName -eq $DetectedInstallHostname.DeviceName }

                # Add the device to the group if it's not already a member
                if (-not $IsInGroup) {

                    $deviceObject = Get-MgBetaDevice -Filter "displayname eq '$($DetectedInstallHostname.DeviceName)'" -ErrorAction Stop

                    New-MgBetaGroupMember -GroupId $group.Id -DirectoryObjectId $deviceObject.id -ErrorAction Stop

                    Write-Host "Added $($DetectedInstallHostname.DeviceName) to group '$GroupName'."
                }
            }

            # Clean up: Remove devices from the group if they no longer have the app installed
            $CurrentGroupMembers | ForEach-Object {

                $GroupMember = $_

                $IsStillDetected = $DetectedInstallHostnames | Where-Object { $_.DeviceName -eq $GroupMember.DisplayName }

                # Remove the device from the group if it's no longer detected
                if (-not $IsStillDetected) {

                    $deviceObject = Get-MgBetaDevice -Filter "displayname eq '$($GroupMember.DisplayName)'" -ErrorAction Stop

                    Remove-MgBetaGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $deviceObject.id -ErrorAction Stop

                    Write-Host "Removed $($GroupMember.DisplayName) from group '$GroupName' as '$AppDisplayName' is no longer detected."
                }
            }
        }
        else {
            Write-Host "No installs found for '$AppDisplayName' in your tenant."
        }
    }
    catch {
        Write-Warning "$($error[0].exception.message)"
    }
}
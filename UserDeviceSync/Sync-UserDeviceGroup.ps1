#Requires -Module Microsoft.Graph.Authentication
#Requires -Module Microsoft.Graph.Beta.Groups
#Requires -Module Microsoft.Graph.Beta.Users
#Requires -Module Microsoft.Graph.Beta.Devices.CorporateManagement
#Requires -Module Microsoft.Graph.Beta.Identity.DirectoryManagement
#Requires -Version 7

<#
.SYNOPSIS
   Synchronizes a device group (named after a given Entra user group) with the managed
   devices of the users in that group – using parallel calls for maximum speed and efficiency.

.DESCRIPTION
   Given an Entra (Azure AD) user group name (populated with users), this script will:
     1. Look up that user group.
     2. Create (if needed) a corresponding device group (named “<UserGroupName>-Devices”).
     3. For each user in the group, concurrently retrieve their managed Intune devices.
     4. Compare the “desired” devices (from the user group) to the current membership of the
        device group.
     5. Concurrently add missing devices and remove devices that no longer belong.

.PARAMETER UserGroupName
    The display name of the Entra group containing the users.

.EXAMPLE
    PS> .\Sync-UserDeviceGroup.ps1 -UserGroupName "Finance Users"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$UserGroupName
)

# Connect to Microsoft Graph with the required scopes.
# Ensure that the Microsoft.Graph.Beta module is installed.
Connect-MgGraph -Scopes "Group.ReadWrite.All", "DeviceManagementManagedDevices.Read.All", "Directory.ReadWrite.All" -NoWelcome

###############################################################################
# Step 1. Get the user group by displayName.
###############################################################################

$userGroup = Get-MgBetaGroup -Filter "displayName eq '$UserGroupName'" | Select-Object -First 1
if (-not $userGroup) {
    Write-Error "User group '$UserGroupName' not found. Exiting..."
    exit
}
Write-Output "Found user group '$UserGroupName' with id '$($userGroup.Id)'"


###############################################################################
# Step 2. Get (or create) the device group.
###############################################################################

$deviceGroupName = "$UserGroupName-Devices"
$deviceGroup = Get-MgBetaGroup -Filter "displayName eq '$deviceGroupName'" | Select-Object -First 1
if (-not $deviceGroup) {
    $groupParams = @{
        DisplayName     = $deviceGroupName
        Description     = "Device group for users in '$UserGroupName'"
        MailEnabled     = $false
        SecurityEnabled = $true
        # MailNickname must be unique; remove spaces if needed.
        MailNickname    = ($deviceGroupName -replace '\s', '')
        GroupTypes      = @()  # An empty array creates a basic security group.
    }
    $deviceGroup = New-MgBetaGroup -BodyParameter $groupParams
    Write-Output "Created device group '$deviceGroupName' with id '$($deviceGroup.Id)'"
} else {
    Write-Output "Found device group '$deviceGroupName' with id '$($deviceGroup.Id)'"
}


###############################################################################
# Step 3. Get all user members from the user group.
###############################################################################

$userMembers = Get-MgBetaGroupMember -GroupId $userGroup.Id -All |
Where-Object { $_.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.user" }
Write-Output "Found $($userMembers.Count) user(s) in group '$UserGroupName'."


###############################################################################
# Step 4. For each user, concurrently get their managed Intune devices.
###############################################################################

# In PowerShell 7 we can use ForEach-Object -Parallel. Note that the Microsoft Graph connection
# might not automatically be available in each parallel runspace. If needed, uncomment the line below
# inside the parallel block to re-establish the connection (and make sure the module is imported):
#
#    Import-Module Microsoft.Graph.Beta; Connect-MgGraph -Scopes "Group.ReadWrite.All", "DeviceManagementManagedDevices.Read.All", "Directory.ReadWrite.All"

$deviceIdsFromUsers = $userMembers | ForEach-Object -Parallel {
    try {
        $Id = $_.Id
        $DisplayName = $_.AdditionalProperties.userPrincipalName
        Write-Host "Retrieving devices for user: '$DisplayName'"
        $devices = Get-MgBetaUserManagedDevice -UserId $_.Id -All
        if ($devices) {
            $deviceIds = $devices | ForEach-Object {
                Write-Host "Found device $($_.DeviceName) (id: $($_.AzureAdDeviceId)) for user '$DisplayName'"
                $_.AzureAdDeviceId
            }
            # Return the device IDs for this user.
            return $deviceIds
        } else {
            Write-Host "No devices found for user: '$DisplayName'"
            return @()
        }
    } catch {
        Write-Error "Error retrieving devices for user '$DisplayName': $_"
        return @()
    }
} -ThrottleLimit 10

# Flatten the array (the parallel block returns an array of arrays).
$desiredDeviceIds = $deviceIdsFromUsers | ForEach-Object { $_ } | Select-Object -Unique
Write-Output "Total unique desired device count: $($desiredDeviceIds.Count)"

###############################################################################
# Step 5. Get the current devices in the device group.
###############################################################################

$currentDevices = Get-MgBetaGroupMember -GroupId $deviceGroup.Id -All |
Where-Object { $_.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.device" }
$currentDeviceIds = $currentDevices | ForEach-Object { $_.AdditionalProperties.deviceId }
Write-Output "Current device group contains $($currentDeviceIds.Count) device(s)."

###############################################################################
# Step 6. Determine which devices to add and remove.
###############################################################################

$devicesToAdd = $desiredDeviceIds | Where-Object { $_ -notin $currentDeviceIds }
$devicesToRemove = $currentDeviceIds | Where-Object { $_ -notin $desiredDeviceIds }

Write-Output "Devices to add: $($devicesToAdd.Count)"
Write-Output "Devices to remove: $($devicesToRemove.Count)"


###############################################################################
# Step 7. Add missing devices concurrently.
###############################################################################

if ($devicesToAdd.Count -gt 0) {
    Write-Output "Adding missing devices..."
    $devicesToAdd | ForEach-Object -Parallel {
        try {
            $device = Get-MgBetaDevice -Filter "DeviceID eq '$_'"
            $params = @{
                "@odata.id" = "https://graph.microsoft.com/beta/directoryObjects/$($device.Id)"
            }
            New-MgBetaGroupMemberByRef -GroupId $using:deviceGroup.Id -BodyParameter $params -ErrorAction Stop
            Write-Output "Added device '$($device.DisplayName)' to group '$($using:deviceGroup.DisplayName)'."
        } catch {
            Write-Error "Error adding device '$($device.DisplayName)':"
            Write-Error "$($_.Exception.Message)"
        }
    } -ThrottleLimit 10
} else {
    Write-Output "No devices to add."
}


###############################################################################
# Step 8. Remove devices that are no longer desired concurrently.
###############################################################################

if ($devicesToRemove.Count -gt 0) {
    Write-Output "Removing devices no longer in the user group..."
    $devicesToRemove | ForEach-Object -Parallel {
        try {
            $device = Get-MgBetaDevice -Filter "DeviceID eq '$_'"
            Remove-MgBetaGroupMemberByRef -GroupId $using:deviceGroup.Id -DirectoryObjectId $($device.Id) -ErrorAction Stop
            Write-Output "Removed device '$($device.DisplayName)' from group '$($using:deviceGroup.DisplayName)'."
        } catch {
            Write-Error "Error removing device '$($device.DisplayName)':"
            Write-Error "$($_.Exception.Message)"
        }
    } -ThrottleLimit 10
} else {
    Write-Output "No devices to remove."
}

Write-Output "Device group synchronization complete."
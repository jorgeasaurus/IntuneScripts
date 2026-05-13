# Sync-UserDeviceGroup.ps1 - README

## Overview
The **Sync-UserDeviceGroup.ps1** script automates the synchronization of an Entra ID (Azure AD) user group's managed devices into a corresponding device group. This ensures that devices assigned to users in a given user group are correctly reflected in a device group with minimal manual intervention.

## Features
- Automatically finds or creates a corresponding device group for a given user group.
- Retrieves all users in the specified user group.
- Fetches managed Intune devices for each user.
- Compares the desired device list with the existing device group membership.
- Concurrently adds missing devices and removes outdated ones using PowerShell 7 parallel execution.

## Prerequisites
### PowerShell Version
- PowerShell **7.0 or later** is required.

### Required PowerShell Modules
Ensure the following modules are installed before running the script:
```powershell
Install-Module Microsoft.Graph.Beta -Scope CurrentUser -Force
```
The script specifically requires:
- **Microsoft.Graph.Beta.Groups**
- **Microsoft.Graph.Beta.Users**
- **Microsoft.Graph.Beta.Devices.CorporateManagement**
- **Microsoft.Graph.Beta.Identity.DirectoryManagement**

### Microsoft Graph API Permissions
The following permissions must be granted to the user running the script:
- `Group.ReadWrite.All`
- `DeviceManagementManagedDevices.Read.All`
- `Directory.ReadWrite.All`

Authenticate using:
```powershell
Connect-MgGraph -Scopes "Group.ReadWrite.All", "DeviceManagementManagedDevices.Read.All", "Directory.ReadWrite.All" -NoWelcome
```

## Usage
### Parameters
| Parameter      | Description                                      | Required |
|--------------|------------------------------------------------|----------|
| `UserGroupName` | The display name of the Entra user group. | Yes |

### Running the Script
To synchronize a user group’s devices, run:
```powershell
.\Sync-UserDeviceGroup.ps1 -UserGroupName "Finance Users"
```

## How It Works
### 1. Connects to Microsoft Graph API
The script establishes a connection using the required permissions.

### 2. Retrieves the User Group
It looks up the specified Entra user group and exits if not found.

### 3. Finds or Creates the Device Group
A device group named `<UserGroupName>-Devices` is searched for. If missing, it is created.

### 4. Retrieves All Users in the User Group
All user members of the specified group are fetched from Microsoft Graph.

### 5. Fetches Managed Intune Devices (Parallel Execution)
Using `ForEach-Object -Parallel`, devices are retrieved concurrently for each user.

### 6. Compares Desired vs. Existing Device Membership
The script determines which devices need to be added or removed.

### 7. Adds Missing Devices (Parallel Execution)
Devices not currently in the group but needed are added concurrently.

### 8. Removes Outdated Devices (Parallel Execution)
Devices that should no longer be in the group are removed concurrently.

### 9. Completion Confirmation
Once synchronization is complete, a confirmation message is displayed.

## Security Considerations
- Ensure the user running the script has appropriate **Graph API permissions**.
- Store credentials securely and avoid hardcoding sensitive information.
- Run the script in a controlled environment to prevent unintended modifications.

## Troubleshooting
### Common Issues & Fixes
| Issue | Resolution |
|-------|------------|
| `User group not found` | Ensure the correct group name is provided. Verify group existence in Entra ID. |
| `No devices found for user` | Ensure users have registered Intune-managed devices. |
| `Access Denied` errors | Verify Graph API permissions and ensure the user has administrative rights. |

## Conclusion
This script provides a robust solution for maintaining **up-to-date Entra ID device groups** by leveraging **Microsoft Graph API** and **parallel processing**. It ensures efficiency, security, and real-time synchronization.

For further customization or support, feel free to reach out. 🚀
# PowerShell Automation Scripts for Intune and Microsoft Graph

This repository contains a collection of PowerShell scripts designed to manage Microsoft Intune and Microsoft Graph API interactions. The scripts automate device and group management tasks, app management, and syncing processes between Intune and Apple services.

## Table of Contents
- [Directory Structure](#directory-structure)
- [Scripts Overview](#scripts-overview)
  - [Remove-GroupMember.ps1](#remove-groupmemberps1)
  - [Invoke-AppInstalledDevicesGroup.ps1](#invoke-appinstalleddevicesgroupps1)
  - [Invoke-IntuneAbmVppSync.ps1](#invoke-intuneabmvppsyncps1)
- [Requirements](#requirements)
- [Usage](#usage)
- [License](#license)

## Directory Structure
```
├── Remove-GroupMember
│   └── Remove-GroupMember.ps1
├── Invoke-AppInstalledDevicesGroup.ps1
└── Invoke-IntuneAbmVppSync.ps1
```

## Scripts Overview

### Remove-GroupMember.ps1
This script removes users from a specified security group if they were created more than a week ago and have enrolled devices in Intune. It uses the Microsoft Graph API (Beta) to automate group member management.

- **Features:**
  - Authenticates to Microsoft Graph API.
  - Checks each group member's account creation date.
  - Removes users with enrolled devices that were created over a week ago.
  
- **Usage:**
  - Update the `$TenantId`, `$ClientId`, and `$CertThumbprint` with your Microsoft Graph credentials.
  - Customize the `$GroupName` to specify the group to manage.

### Invoke-AppInstalledDevicesGroup.ps1
This script manages a group of devices based on whether a specified application is installed. It adds devices with the application to the group and removes those that no longer have the application.

- **Features:**
  - Detects devices with a specific application installed.
  - Automatically creates and updates a device group for the application.
  - Adds or removes devices from the group based on the presence of the application.
  
- **Usage:**
  - Run the script with the `-AppDisplayName` parameter to specify the application.
    ```powershell
    Invoke-AppInstalledDevicesGroup -AppDisplayName "Adobe Acrobat (64-bit)"
    ```
  - Ensure necessary Microsoft Graph permissions are granted for device and group management.

### Invoke-IntuneAbmVppSync.ps1
This script syncs Apple Business Manager (ABM) and Apple Volume Purchase Program (VPP) tokens with Intune. It initiates a sync process to ensure devices and licenses are up to date between Apple services and Intune.

- **Features:**
  - Syncs ABM with Intune.
  - Syncs VPP tokens for Apple licenses with Intune.
  - Provides detailed status updates for sync processes.
  
- **Usage:**
  - Update the `$TenantId`, `$ClientId`, and `$CertThumbprint` with your credentials.
  - Execute the script to trigger the sync process for both ABM and VPP.

## Requirements
- **PowerShell 7+**
- **Microsoft Graph PowerShell SDK**
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Beta.DeviceManagement`
  - `Microsoft.Graph.Beta.Groups`
  - `Microsoft.Graph.Beta.Identity.DirectoryManagement`
- **Required Permissions:**
  - `DeviceManagementConfiguration.ReadWrite.All`
  - `Group.ReadWrite.All`
  - `Directory.ReadWrite.All`
  - `Device.ReadWrite.All`

## Usage
1. Clone this repository to your local machine:
   ```powershell
   git clone https://github.com/jorgeasaurus/IntuneScripts.git
   cd IntuneScripts
   ```
2.	Update each script with your tenant-specific values (e.g., Tenant ID, Client ID, etc.).
3.	Run the scripts in PowerShell, ensuring you have the necessary Microsoft Graph API permissions.

## License

This project is licensed under the MIT License. See the LICENSE file for more information.

Feel free to contribute by submitting a pull request or opening an issue for any bugs or feature requests.

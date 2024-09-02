# Azure AD Security Group Automation Script

## Overview
This PowerShell script automates the management of Azure AD Security Group members in the "ENROLLMENT_ALLOW" group. It identifies users who were created over a week ago and checks if they have any devices enrolled. If they do, they are removed from the group to restrict further device enrollments.

## Prerequisites
- **Microsoft.Graph.Beta** module installed.
- **Tenant ID**, **Client ID**, and **Certificate Thumbprint** for Azure AD authentication.

## Script Workflow
1. **Authenticate** to Microsoft Graph.
2. **Identify** the "ENROLLMENT_ALLOW" group.
3. **Retrieve** group members.
4. **Check** if users were created over a week ago.
5. **Verify** if users have enrolled devices.
6. **Remove** qualifying users from the group.

## Usage
1. Replace placeholders with your **Tenant ID**, **Client ID**, and **Certificate Thumbprint**.
2. Run the script to manage the "ENROLLMENT_ALLOW" group members based on the criteria.

## Important Notes
- The script requires administrative permissions.
- Log outputs are included for each user processed.

## License
This project is licensed under the MIT License. See the LICENSE file for details.
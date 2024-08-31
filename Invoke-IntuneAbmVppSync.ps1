<#
Required Graph API Permissions:

DeviceManagementConfiguration.Read.All
DeviceManagementConfiguration.ReadWrite.All
DeviceManagementServiceConfig.Read.All
DeviceManagementServiceConfig.ReadWrite.All
#>

# Import necessary Microsoft Graph modules
"Authentication",
"Beta.DeviceManagement",
"Beta.DeviceManagement.Actions",
"Beta.DeviceManagement.Enrollment",
"Beta.Devices.CorporateManagement" | ForEach-Object {
    Import-Module "Microsoft.Graph.$_"
}

# Set the security protocol to TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Define connection parameters for Microsoft Graph API
$connectMgGraph = @{
    TenantId              = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" # UPDATE
    Environment           = "Global"
    ClientID              = "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" # UPDATE
    CertificateThumbprint = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX" # UPDATE
}

# Connect to Microsoft Graph using provided credentials
Connect-MgGraph @connectMgGraph -NoWelcome

try {

    # Sync Apple Business Manager with Intune, default is every 8 hours
    $DepOnboardingSettings = Get-MgBetaDeviceManagementDepOnboardingSetting

    foreach ($DepOnboardingSetting in $DepOnboardingSettings) {

        Write-Output "`nSyncing Apple Business Manager with Intune..."

        # Retrieve and display the last successful sync time and synced device count
        Get-MgBetaDeviceManagementDepOnboardingSetting `
            -DepOnboardingSettingId $DepOnboardingSetting.Id | `
            Select-Object LastSuccessfulSyncDateTime, SyncedDeviceCount

        # Initiate the sync process with Apple Device Enrollment Program (DEP)
        $DeviceSync = Sync-MgBetaDeviceManagementDepOnboardingSettingWithAppleDeviceEnrollmentProgram `
            -DepOnboardingSettingId $DepOnboardingSetting.Id `
            -ErrorAction Stop

        # Pause for 15 seconds to allow the sync to initiate
        Start-Sleep -Seconds 15
        
        Write-Output "`nSync initiated successfully."

        $DeviceSync
    }

    Write-Output "----------------------------------------------------------"

    # Sync Intune VPP (Volume Purchase Program) Tokens
    $VPPTokens = Get-MgBetaDeviceAppManagementVppToken

    foreach ($VPPToken in $VPPTokens) {
        Write-Output "`nSyncing VPP Token for Apple ID: '$($VPPToken.AppleId)'..."

        # Initiate the VPP token sync process
        $VPPSync = Sync-MgBetaDeviceAppManagementVppTokenLicense  `
            -VppTokenId $VPPToken.ID `
            -ErrorAction Stop

        # Pause for 15 seconds to allow the sync to initiate
        Start-Sleep -Seconds 15
        
        Write-Output "`nSync initiated successfully."

        # Retrieve and display the last sync status and time
        Get-MgBetaDeviceAppManagementVppToken `
            -VppTokenId $VPPToken.ID | `
            Select-Object DisplayName, LastSyncDateTime, LastSyncStatus
    }

} catch {
    # Error handling for Microsoft Graph API operations
    if ($Error[0].Exception.Message -match '"Message":\s*"([^"]+)"') {
        $message = $matches[1] -split " - "
        Write-Output "`nError: $($message[0])"
    } else {
        Write-Output "`nError: $($Error[0])"
    }
}
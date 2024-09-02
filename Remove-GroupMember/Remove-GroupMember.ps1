# Ensure the Microsoft.Graph.Beta module is installed and imported
Import-Module Microsoft.Graph.Beta -ErrorAction Stop

# Authenticate to Microsoft Graph
$TenantId = "YourTenantID"
$ClientId = "YourClientID"
$CertThumbprint = "YourCertThumbprint"

$connectionParams = @{
    TenantId              = $TenantId
    ClientId              = $ClientId
    CertificateThumbprint = $CertThumbprint
    Environment           = "Global"
}

Connect-MgGraph @connectionParams

$GroupName = "ENROLLMENT_ALLOW"

# Define the Security Group ID
$Group = Get-MgBetaGroup -Filter "Displayname eq '$GroupName'"

# Get members of the Security Group
$groupMembers = Get-MgBetaGroupMember -GroupId $Group.Id -All

# Set the threshold date (one week ago)
$oneWeekAgo = (Get-Date).AddDays(-7)

# $member = $groupMembers

foreach ($member in $groupMembers) {
    # Get the user's creation date
    $user = Get-MgBetaUser -UserId $member.Id
    $creationDate = $user.CreatedDateTime

    # Check if the user was created over a week ago
    if ($creationDate -lt $oneWeekAgo) {
        Write-Output "User $($user.DisplayName) was created on $creationDate (over a week ago), checking enrolled devices."

        # Check if the user has any devices
        $devices = Get-MgBetaUserRegisteredDevice -UserId $member.Id -ErrorAction SilentlyContinue

        if ($devices.Count -gt 0) {
            # Remove the user from the security group
            Write-Output "User $($user.DisplayName) has one or more devices enrolled."
            Remove-MgBetaGroupMemberDirectoryObjectByRef -GroupId $Group.Id -DirectoryObjectId $user.Id -ErrorAction Stop
            Write-Output "User $($user.DisplayName) has been removed from the group."
        } else {
            Write-Output "User $($user.DisplayName) has no devices associated."
        }
    } else {
        Write-Output "User $($user.DisplayName) was created less than a week ago."
    }
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
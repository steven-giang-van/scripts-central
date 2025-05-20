# Load modules
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups

# Connect with required permissions
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

# Set group and filter
$groupName = "Team Name"
$group = Get-MgGroup -Filter "displayName eq '$groupName'"
$groupId = $group.Id

# Apply filters (currently by below)
# Filter users by department and enabled accounts
$filter = "(department eq 'Technology' or department eq 'Research & Development') and accountEnabled eq true"
$users = Get-MgUser -Filter $filter -All

# Get existing group members' IDs
$existingMembers = Get-MgGroupMember -GroupId $groupId -All | Select-Object -ExpandProperty Id

# Add users to group if they are not already members
foreach ($user in $users) {
    if ($existingMembers -contains $user.Id) {
        Write-Host "ℹ️ Already a member: $($user.DisplayName)"
        continue
    }

    try {
        New-MgGroupMember -GroupId $groupId -DirectoryObjectId $user.Id
        Write-Host "✅ Added: $($user.DisplayName)"
    } catch {
        Write-Host "❌ Failed: $($user.DisplayName) — $_"
    }
}

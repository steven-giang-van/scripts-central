<#
This will require checking back on the licensed group in case listed users haven't
had their licenses removed.

Requires these modules before running script:

Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module MSOnline -Scope CurrentUser
#>

# Connect to Graph and Exchange Online
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.Read.All", "GroupMember.ReadWrite.All", "Directory.Read.All"
Connect-ExchangeOnline

# Import users from CSV
$users = Import-Csv -Path "/Users/steven/Downloads/UsersToSharedMailbox.csv"

# Get all groups and filter ones that assign licenses
$allGroups = Get-MgGroup -All
$licensedGroups = $allGroups | Where-Object { $_.AssignedLicenses.Count -gt 0 }

foreach ($user in $users) {
    $upn = $user.UserPrincipalName
    Write-Host "`nProcessing $upn..." -ForegroundColor Cyan

    try {
        # 1. Convert to shared mailbox
        Set-Mailbox -Identity $upn -Type Shared
        Write-Host "Converted to shared mailbox." -ForegroundColor Green

        # 2. Prefix display name with 'Zz - ' if not already prefixed
        $originalUser = Get-MgUser -UserId $upn
        if ($originalUser.DisplayName -notlike "Zz - *") {
            $newDisplayName = "Zz - " + $originalUser.DisplayName
            Update-MgUser -UserId $upn -DisplayName $newDisplayName
            Write-Host "Updated display name to: $newDisplayName" -ForegroundColor Green
        } else {
            Write-Host "Display name already prefixed with 'Zz - '. Skipping update." -ForegroundColor Yellow
        }

        # 3. Remove directly assigned licenses
        if ($originalUser.AssignedLicenses.Count -gt 0) {
            $removeLicenses = $originalUser.AssignedLicenses | ForEach-Object { $_.SkuId }
            $licenseRemoval = @{
                addLicenses = @()
                removeLicenses = $removeLicenses
            }
            Update-MgUserLicense -UserId $upn -BodyParameter $licenseRemoval
            Write-Host "Removed direct license(s)." -ForegroundColor Green
        }

        # 4. Remove from a specific group (replace with your group's name or ID)
        $targetGroup = Get-MgGroup -Filter "displayName eq 'Slingshot All'" | Select-Object -First 1

        if ($targetGroup) {
            $groupMembers = Get-MgGroupMember -GroupId $targetGroup.Id -All
            $match = $groupMembers | Where-Object { $_.AdditionalProperties.userPrincipalName -eq $upn }

            if ($match -and $match.Id) {
                Remove-MgGroupMemberByRef -GroupId $targetGroup.Id -DirectoryObjectId $match.Id
                Write-Host "Removed from group: $($targetGroup.DisplayName)" -ForegroundColor Yellow
            }
            else {
                Write-Host "Not in the group: $($targetGroup.DisplayName)" -ForegroundColor Yellow
            }		
        }

        # 5. Final cleanup - check and remove any leftover license fragments (missing dependencies)
        $licenseDetails = Get-MgUserLicenseDetail -UserId $upn
        if ($licenseDetails.Count -gt 0) {
            $orphanedLicenses = $licenseDetails | ForEach-Object { $_.SkuId }
            if ($orphanedLicenses.Count -gt 0) {
                Set-MgUserLicense -UserId $upn -RemoveLicenses $orphanedLicenses -AddLicenses @(
		@(
			        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphAssignedLicense]@{
				        SkuId = [Guid]::Parse("e2be619b-b125-455f-8660-fb503e431a5d")
    				}
			)
		)
                Write-Host "Cleaned up orphaned license remnants." -ForegroundColor Magenta
            }
        }

	$userGroups = Get-MgUserMemberOf -UserId $upn -All
        foreach ($groupRef in $userGroups) {
            $group = Get-MgGroup -GroupId $groupRef.Id
            if ($group.AssignedLicenses.Count -gt 0) {
                Write-Host "Removing $upn from licensed group: $($group.DisplayName)" -ForegroundColor Yellow
                try {
                    Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $originalUser.Id
                } catch {
                    Write-Host "Failed to remove from $($group.DisplayName): $_" -ForegroundColor Red
                }
            }
        }

        # Optional: Wait for licensing sync (usually 5–15 minutes)
        Start-Sleep -Seconds 10  # <-- Increase if needed

        # 6. Final license cleanup (if any direct remnants remain)
        $licenseDetails = Get-MgUserLicenseDetail -UserId $upn
        if ($licenseDetails.Count -gt 0) {
            $orphanedLicenses = $licenseDetails | ForEach-Object { $_.SkuId }
            if ($orphanedLicenses.Count -gt 0) {
                $safeAdd = @(
                    [Microsoft.Graph.PowerShell.Models.MicrosoftGraphAssignedLicense]@{
                        SkuId = [Guid]::Empty
                    }
                )
                try {
                    Set-MgUserLicense -UserId $upn -AddLicenses $safeAdd -RemoveLicenses $orphanedLicenses
                    Write-Host "Cleaned up orphaned license remnants." -ForegroundColor Magenta
                } catch {
                    Write-Host "License cleanup failed for ${upn}: $_" -ForegroundColor Red
                }
            }
        }

    } catch {
        Write-Host "Error processing ${upn}: $_" -ForegroundColor Red
    }
}

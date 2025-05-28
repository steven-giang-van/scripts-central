# Connect to Graph and Exchange Online
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.Read.All", "GroupMember.ReadWrite.All", "Directory.Read.All"
Connect-ExchangeOnline

$failedUsers = @()

# Prompt for UserPrincipalName
$upn = Read-Host "Enter the User Principal Name (UPN) of the user to process"

Write-Host "`nProcessing $upn..." -ForegroundColor Cyan

try {
    Set-Mailbox -Identity $upn -Type Shared
    Write-Host "Converted to shared mailbox." -ForegroundColor Green

    $originalUser = Get-MgUser -UserId $upn
    if ($originalUser.DisplayName -notlike "Zz - *") {
        $newDisplayName = "Zz - " + $originalUser.DisplayName
        Update-MgUser -UserId $upn -DisplayName $newDisplayName
        Write-Host "Updated display name to: $newDisplayName" -ForegroundColor Green
    } else {
        Write-Host "Display name already prefixed. Skipping update." -ForegroundColor Yellow
    }

    if ($originalUser.AssignedLicenses.Count -gt 0) {
        $removeLicenses = $originalUser.AssignedLicenses | ForEach-Object { $_.SkuId }
        Update-MgUserLicense -UserId $upn -BodyParameter @{
            addLicenses = @()
            removeLicenses = $removeLicenses
        }
        Write-Host "Removed direct license(s)." -ForegroundColor Green
    }

    $userGroups = Get-MgUserMemberOf -UserId $upn -All
    foreach ($groupRef in $userGroups) {
        try {
            $group = Get-MgGroup -GroupId $groupRef.Id
            Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $originalUser.Id
            Write-Host "Removed from group: $($group.DisplayName)" -ForegroundColor Yellow
        } catch {
            Write-Host "Failed to remove from group: $($groupRef.Id): $_" -ForegroundColor Red
        }
    }

    Start-Sleep -Seconds 10

    $licenseDetails = Get-MgUserLicenseDetail -UserId $upn
    if ($licenseDetails.Count -gt 0) {
        $orphanedLicenses = $licenseDetails | ForEach-Object { $_.SkuId }
        if ($orphanedLicenses.Count -gt 0) {
            $slingshotGroup = Get-MgGroup -Filter "displayName eq 'Slingshot All'" | Select-Object -First 1
            if ($slingshotGroup) {
                try {
                    Add-MgGroupMemberByRef -GroupId $slingshotGroup.Id -BodyParameter @{
                        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($originalUser.Id)"
                    }
                    Write-Host "Temporarily added to 'Slingshot All'." -ForegroundColor Cyan

                    Remove-MgGroupMemberByRef -GroupId $slingshotGroup.Id -DirectoryObjectId $originalUser.Id
                    Write-Host "Removed from 'Slingshot All' again." -ForegroundColor Cyan
                } catch {
                    Write-Host "Error with Slingshot All reassignment: $_" -ForegroundColor Red
                }
            }

            $remaining = Get-MgUserLicenseDetail -UserId $upn
            if ($remaining.Count -gt 0) {
                $remainingSkuIds = $remaining | ForEach-Object { $_.SkuId }
                Write-Host "⚠️ Still has remaining licenses after group reassignment: $($remainingSkuIds -join ', ')" -ForegroundColor Red
                $failedUsers += [PSCustomObject]@{
                    UserPrincipalName = $upn
                    RemainingLicenses = ($remainingSkuIds -join ', ')
                }
            } else {
                Write-Host "✅ License cleanup successful after group reassignment." -ForegroundColor Green
            }
        }
    }

} catch {
    Write-Host "❌ Error processing ${upn}: $_" -ForegroundColor Red
}

# Final summary
if ($failedUsers.Count -gt 0) {
    Write-Host "`n=== License Removal Failures ===" -ForegroundColor Red
    $failedUsers | Format-Table -AutoSize
    $failedUsers | Export-Csv -Path "./FailedLicenseRemovals.csv" -NoTypeInformation
} else {
    Write-Host "`nAll users cleaned up successfully!" -ForegroundColor Green
}

Import-Module MicrosoftTeams
Connect-MicrosoftTeams

# Prompt for CSV file path
$defaultPath = "$HOME/Documents/teams-to-archive.csv"
$csvPath = Read-Host "Enter the path to your CSV file (or press Enter for default: $defaultPath)"
if ([string]::IsNullOrWhiteSpace($csvPath)) {
    $csvPath = $defaultPath
}

# Load team names from CSV
$teamsToArchive = Import-Csv -Path $csvPath

# Cache all existing Teams
$allTeams = Get-Team

# Track missing teams or failures
$notArchived = @()

foreach ($team in $teamsToArchive) {
    $matchedTeam = $allTeams | Where-Object { $_.DisplayName -eq $team.DisplayName }

    if ($matchedTeam) {
        Write-Host "Archiving: $($matchedTeam.DisplayName)" -ForegroundColor Green

        try {
            Set-TeamArchivedState -GroupId $matchedTeam.GroupId -Archived $true -SetSpoSiteReadOnlyForMembers $true
            Write-Host "Archived with SharePoint site lock: $($matchedTeam.DisplayName)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Primary archive attempt failed for $($matchedTeam.DisplayName). Retrying without SharePoint lock..."
            try {
                Set-TeamArchivedState -GroupId $matchedTeam.GroupId -Archived $true
                Write-Host "Archived (without SP lock): $($matchedTeam.DisplayName)" -ForegroundColor Yellow
            }
            catch {
                Write-Error "Archiving failed entirely for $($matchedTeam.DisplayName): $_"
                $notArchived += [PSCustomObject]@{
                    DisplayName = $team.DisplayName
                    Status      = "Error"
                    Message     = $_.Exception.Message
                }
            }
        }
    }
    else {
        Write-Warning "Team not found: $($team.DisplayName)"
        $notArchived += [PSCustomObject]@{
            DisplayName = $team.DisplayName
            Status      = "Not Found"
            Message     = "No matching team found"
        }
    }
}

# Output summary
if ($notArchived.Count -gt 0) {
    Write-Host "`nSome teams could not be archived:" -ForegroundColor Yellow
    $notArchived | ForEach-Object {
        Write-Host "- $($_.DisplayName): $($_.Status) ($($_.Message))" -ForegroundColor Red
    }

    $outputPath = "$HOME/Documents/teams-archive-errors.csv"
    $notArchived | Export-Csv -Path $outputPath -NoTypeInformation
    Write-Host "`nIssues exported to: $outputPath" -ForegroundColor Cyan
}
else {
    Write-Host "`n✅ All teams were archived successfully." -ForegroundColor Green
}

# Bulk Archive Microsoft Teams

Requires Powershell to run script. If on macOS, install pwsh to run in Terminal.
Additionally, install the Teams module via these commands one-by-one:
```
Install-Module -Name PowerShellGet -Force -AllowClobber
Install-Module -Name MicrosoftTeams -Force
Import-Module MicrosoftTeams
```

A Powershell script that can bulk archive a list of teams in Microsoft by reading through a CSV
list. Running the script will prompt you to enter the path to the CSV file. At the end of the
operation, an error log is created for any teams that were not archived. 

A sample CSV is provided. All you need to do is fill the list below DisplayName with the teams.

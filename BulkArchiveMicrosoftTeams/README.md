# Bulk Archive Microsoft Teams

Requires Powershell to run script. If on macOS, install pwsh to run in Terminal.
Additionally, install the Teams module via these commands one-by-one:
```
Install-Module -Name PowerShellGet -Force -AllowClobber
Install-Module -Name MicrosoftTeams -Force
Import-Module MicrosoftTeams
```

A Powershell script that can bulk archive a list of teams in Microsoft by reading through a CSV
list. Running the script will prompt you to enter the path to the CSV file. a sample CSV is
provided.

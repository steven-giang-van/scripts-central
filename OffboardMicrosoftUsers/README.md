# Offboard Microsoft Users

A multi-step Powershell script that will go through a list of users and perform numerous operations. 
Two scripts are provided for either single or bulk operations. A sample CSV template file is provided.

The script was made primarily to run with macOS Terminal using pwsh. Tweaking may be needed to run on Windows.

These modules are required to run the script:
```
Install-Module Microsoft.Graph -Scope CurrentUser
Install-Module ExchangeOnlineManagement -Scope CurrentUser
Install-Module MSOnline -Scope CurrentUser
```

**NOTE:** Edit the file path to your user list on line 17 in OffboardMicrosoftUserBulk.ps1:
```
# Import users from CSV
$users = Import-Csv -Path "/Users/{user}/SampleList.csv"
```

The following steps are the operations the script will perform in order:

1. Convert user's mailbox to be shared
2. Prepend "Zz - " to user's display name
3. Removes user's Microsoft license
4. Removes user from all group membership
5. If license was not removed after step 3 and 4, attempt to remove orphaned services to remove license again or re-assign group license to remove.

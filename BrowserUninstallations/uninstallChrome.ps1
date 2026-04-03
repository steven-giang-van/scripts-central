Write-Host "=== Google Chrome Uninstall ==="



# Kill Chrome if running
if (Get-Process chrome -ErrorAction SilentlyContinue) {
   Write-Host "Stopping Chrome processes..."
   Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force
} else {
   Write-Host "Chrome processes not running."
}



# --- SYSTEM INSTALL CHECK ---
$chromeSystemPaths = @(
   "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
   "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe"
)



$chromeInstalled = $false



foreach ($exe in $chromeSystemPaths) {
   if (Test-Path $exe) {
       $chromeInstalled = $true
       $setupPath = $exe -replace "chrome.exe", "setup.exe"



       if (Test-Path $setupPath) {
           Write-Host "Uninstalling system Chrome from $setupPath"
           Start-Process $setupPath -ArgumentList "--uninstall --system-level --force-uninstall" -Wait
       }
   }
}



if (-not $chromeInstalled) {
   Write-Host "System Chrome not detected."
}



# --- PER USER UNINSTALL ---
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {



   $chromeExe = Join-Path $_.FullName "AppData\Local\Google\Chrome\Application\chrome.exe"



   if (Test-Path $chromeExe) {
       $setup = $chromeExe -replace "chrome.exe", "setup.exe"



       if (Test-Path $setup) {
           Write-Host "Uninstalling Chrome for user: $($_.Name)"
           Start-Process $setup -ArgumentList "--uninstall --force-uninstall" -Wait
       }
   }
}



# --- CLEANUP (CHROME ONLY) ---
Write-Host "Cleaning Chrome-specific folders..."



Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {



   $chromePath = Join-Path $_.FullName "AppData\Local\Google\Chrome"



   if (Test-Path $chromePath) {
       Write-Host "Removing $chromePath"
       Remove-Item $chromePath -Recurse -Force -ErrorAction SilentlyContinue
   } else {
       Write-Host "Chrome folder not found for $($_.Name)"
   }
}



# System cleanup (only if exists)
$chromeProgramPaths = @(
   "C:\Program Files\Google\Chrome",
   "C:\Program Files (x86)\Google\Chrome"
)



foreach ($path in $chromeProgramPaths) {
   if (Test-Path $path) {
       Write-Host "Removing $path"
       Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
   }
}



Write-Host "Chrome uninstall completed."

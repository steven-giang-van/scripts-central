Write-Host "=== Mozilla Firefox Uninstall ==="

# Kill Firefox if running
if (Get-Process firefox -ErrorAction SilentlyContinue) {
    Write-Host "Stopping Firefox processes..."
    Get-Process firefox | Stop-Process -Force
} else {
    Write-Host "Firefox not running."
}

# --- CHECK IF FIREFOX EXISTS ---
$firefoxPaths = @(
    "C:\Program Files\Mozilla Firefox\firefox.exe",
    "C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
)

$firefoxInstalled = $false

foreach ($path in $firefoxPaths) {
    if (Test-Path $path) {
        $firefoxInstalled = $true
    }
}

if ($firefoxInstalled) {

    Write-Host "Firefox detected, proceeding with uninstall..."

    $uninstallKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($key in $uninstallKeys) {
        Get-ItemProperty $key -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*Mozilla Firefox*"
        } | ForEach-Object {

            if ($_.UninstallString) {
                $cmd = $_.UninstallString

                if ($cmd -notmatch "/S") {
                    $cmd += " /S"
                }

                Write-Host "Running Firefox uninstall..."
                Start-Process "cmd.exe" -ArgumentList "/c $cmd" -Wait
            }
        }
    }

} else {
    Write-Host "Firefox not detected. Skipping uninstall."
}

# --- CLEANUP ---
Write-Host "Cleaning Firefox folders..."

Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {

    $roaming = Join-Path $_.FullName "AppData\Roaming\Mozilla Firefox"
    $local   = Join-Path $_.FullName "AppData\Local\Mozilla Firefox"

    if (Test-Path $roaming) {
        Write-Host "Removing $roaming"
        Remove-Item $roaming -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $local) {
        Write-Host "Removing $local"
        Remove-Item $local -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# System cleanup
$firefoxSystemPaths = @(
    "C:\Program Files\Mozilla Firefox",
    "C:\Program Files (x86)\Mozilla Firefox"
)

foreach ($path in $firefoxSystemPaths) {
    if (Test-Path $path) {
        Write-Host "Removing $path"
        Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Firefox uninstall completed."

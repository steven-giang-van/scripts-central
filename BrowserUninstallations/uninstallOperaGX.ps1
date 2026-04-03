Write-Host "=== Opera GX Uninstall ==="

# Kill Opera processes
if (Get-Process opera -ErrorAction SilentlyContinue) {
    Write-Host "Stopping Opera processes..."
    Get-Process opera -ErrorAction SilentlyContinue | Stop-Process -Force
} else {
    Write-Host "Opera processes not running."
}

$excludedProfiles = @("Public", "Default", "Default User", "All Users")

$operaFound = $false

# --- PER USER UNINSTALL ---
Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {

    if ($excludedProfiles -contains $_.Name) { return }

    $userPath = $_.FullName
    $operaExe = Join-Path $userPath "AppData\Local\Programs\Opera GX\opera.exe"

    if (Test-Path $operaExe) {
        $operaFound = $true
        $installer = $operaExe -replace "opera.exe", "installer.exe"

        if (Test-Path $installer) {
            Write-Host "Uninstalling Opera GX for user: $($_.Name)"
            Start-Process $installer -ArgumentList "--uninstall --silent" -Wait
        } else {
            Write-Host "Installer not found for $($_.Name), skipping uninstall."
        }
    } else {
        Write-Host "Opera GX not found for $($_.Name)"
    }
}

if (-not $operaFound) {
    Write-Host "Opera GX not detected on system."
}

# --- CLEANUP ---
Write-Host "Cleaning Opera GX folders..."

Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue | ForEach-Object {

    if ($excludedProfiles -contains $_.Name) { return }

    $paths = @(
        "AppData\Local\Programs\Opera GX",
        "AppData\Local\Opera Software",
        "AppData\Roaming\Opera Software"
    )

    foreach ($relPath in $paths) {
        $fullPath = Join-Path $_.FullName $relPath

        if (Test-Path $fullPath) {
            Write-Host "Removing $fullPath"
            Remove-Item $fullPath -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "Path not found: $fullPath"
        }
    }
}

Write-Host "Opera GX uninstall completed."

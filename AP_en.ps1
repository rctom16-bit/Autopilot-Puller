# Windows Autopilot CSV Generator
# Feb 2026 - V1.1 (Improved English Version)

# 1. Administrative Privileges Check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrative privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Clear-Host
Write-Host "Windows Autopilot Info Collector" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Gray

$tempPath = "C:\Windows\Temp"
$scriptName = "Get-WindowsAutoPilotInfo.ps1"
$scriptPath = Join-Path $tempPath $scriptName

Set-ExecutionPolicy RemoteSigned -Scope Process -Force | Out-Null

# 2. Smarter Dependency Handling (Offline Support)
if (-not (Test-Path $scriptPath)) {
    Write-Host "`nDownloading Microsoft script..." -ForegroundColor Yellow
    try {
        Save-Script -Name Get-WindowsAutoPilotInfo -Path $tempPath -Force -ErrorAction Stop
        # Note: Save-Script sometimes creates a versioned subfolder. 
        # We ensure the script is directly in $tempPath for easier execution.
        $downloadedFile = Get-ChildItem -Path $tempPath -Filter $scriptName -Recurse | Select-Object -First 1
        if ($downloadedFile -and $downloadedFile.FullName -ne $scriptPath) {
            Move-Item -Path $downloadedFile.FullName -Destination $scriptPath -Force
        }
    } catch {
        Write-Host "Critical Error: Could not download the Autopilot script." -ForegroundColor Red
        Write-Host "Please ensure you have an internet connection for the first run." -ForegroundColor White
        Read-Host "`nPress Enter to exit..."
        exit
    }
} else {
    Write-Host "`nUsing existing local script found in $tempPath" -ForegroundColor Gray
}

# 3. Filename & Path Safety
Write-Host "`nEnter filename (leave empty for Serial Number):" -ForegroundColor Green
$filenameInput = Read-Host " > "

if ([string]::IsNullOrWhiteSpace($filenameInput)) { 
    $serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber 
    $filename = "${serialNumber}_Autopilot.csv"
    Write-Host " -> Serial detected: $serialNumber" -ForegroundColor Yellow
} else {
    $filename = $filenameInput
    if ($filename -notlike '*.csv') { $filename += '.csv' }
}

# Sanitize filename (remove illegal characters)
$invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
$filename = $filename -replace "[$([Regex]::Escape($invalidChars))]", "_"
Write-Host " -> Final Filename: $filename" -ForegroundColor Magenta

# 4. Robust USB Detection
$usbDrive = (Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter -and $_.OperationalStatus -eq 'OK' } | Select-Object -First 1).DriveLetter

if ($usbDrive) { 
    $outputPath = Join-Path "${usbDrive}:\" $filename
    Write-Host " -> USB Drive ($($usbDrive):) detected and ready." -ForegroundColor Yellow
} else {
    $outputPath = Join-Path $tempPath $filename
    Write-Host " -> No USB drive found. Using fallback: $tempPath" -ForegroundColor Yellow
}

# Execution
Write-Host "`nGenerating CSV: $outputPath" -ForegroundColor Blue
try {
    & $scriptPath -OutputFile $outputPath -ErrorAction Stop
} catch {
    Write-Host "`nExecution failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Validation
if (Test-Path $outputPath) {
    $sizeKB = [math]::Round((Get-Item $outputPath).Length / 1KB, 1)
    Write-Host "`nSuccess! File generated." -ForegroundColor Green
    Write-Host "Path: $outputPath" -ForegroundColor White
    Write-Host "Size: $sizeKB KB" -ForegroundColor Cyan
} else {
    Write-Host "`nError: The output file was not created." -ForegroundColor Red
}

Write-Host "`nProcess finished. Press Enter to exit..."
Read-Host

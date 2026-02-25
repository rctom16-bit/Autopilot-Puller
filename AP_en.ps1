# Windows Autopilot CSV Generator
# Feb 2026 - V1.3.2 (UTF-8 Compatibility)

# Set UTF8 Encoding for the console to support fancy characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Administrative Privileges Check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host " [!] Requesting Administrative privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

function Show-Banner {
    Clear-Host
    Write-Host @"
    
  █████╗ ██╗   ██╗████████╗ ██████╗ ██████╗ ██╗██╗      ██████╗ ████████╗
 ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗██╔══██╗██║██║     ██╔═══██╗╚══██╔══╝
 ███████║██║   ██║   ██║   ██║   ██║██████╔╝██║██║     ██║   ██║   ██║   
 ██╔══██║██║   ██║   ██║   ██║   ██║██╔═══╝ ██║██║     ██║   ██║   ██║   
 ██║  ██║╚██████╔╝   ██║   ╚██████╔╝██║     ██║███████╗╚██████╔╝   ██║   
 ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝ ╚═╝     ╚═╝╚══════╝ ╚═════╝    ╚═╝   
                                                                         
    >> WINDOWS AUTOPILOT INFO COLLECTOR <<
    
"@ -ForegroundColor Cyan
    Write-Host " ────────────────────────────────────────────────────────────" -ForegroundColor Gray
}

Show-Banner

$tempPath = "C:\Windows\Temp"
$scriptName = "Get-WindowsAutoPilotInfo.ps1"
$scriptPath = Join-Path $tempPath $scriptName

Set-ExecutionPolicy RemoteSigned -Scope Process -Force | Out-Null

# 2. Smarter Dependency Handling (Offline Support)
if (-not (Test-Path $scriptPath)) {
    Write-Host " [i] Downloading Microsoft script..." -ForegroundColor Yellow
    try {
        Save-Script -Name Get-WindowsAutoPilotInfo -Path $tempPath -Force -ErrorAction Stop
        $downloadedFile = Get-ChildItem -Path $tempPath -Filter $scriptName -Recurse | Select-Object -First 1
        if ($downloadedFile -and $downloadedFile.FullName -ne $scriptPath) {
            Move-Item -Path $downloadedFile.FullName -Destination $scriptPath -Force
        }
        Write-Host " [√] Download complete." -ForegroundColor Green
    } catch {
        Write-Host " [X] Critical Error: Could not download script." -ForegroundColor Red
        Write-Host "     Please check your internet connection." -ForegroundColor White
        Read-Host "`n Press Enter to exit..."
        exit
    }
} else {
    Write-Host " [√] Local script ready." -ForegroundColor Gray
}

# 3. Filename & Path Safety
Write-Host "`n [?] Enter filename (leave empty for Serial Number):" -ForegroundColor Green
$filenameInput = Read-Host "  > "

if ([string]::IsNullOrWhiteSpace($filenameInput)) { 
    $serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber 
    $filename = "${serialNumber}_Autopilot.csv"
    Write-Host " [+] Serial detected: $serialNumber" -ForegroundColor Yellow
} else {
    $filename = $filenameInput
    if ($filename -notlike '*.csv') { $filename += '.csv' }
}

# Sanitize filename
$invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
$filename = $filename -replace "[$([Regex]::Escape($invalidChars))]", "_"
Write-Host " [+] Target Filename: $filename" -ForegroundColor Magenta

# 4. Robust USB Detection
$usbDrive = (Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter -and $_.OperationalStatus -eq 'OK' } | Select-Object -First 1).DriveLetter

if ($usbDrive) { 
    $outputPath = Join-Path "${usbDrive}:\" $filename
    Write-Host " [+] Target: USB Drive ($($usbDrive):)" -ForegroundColor Yellow
} else {
    $outputPath = Join-Path $tempPath $filename
    Write-Host " [!] Target: No USB found. Using fallback ($tempPath)" -ForegroundColor Yellow
}

# Execution
Write-Host "`n [*] Generating CSV..." -ForegroundColor Blue
try {
    & $scriptPath -OutputFile $outputPath -ErrorAction Stop
} catch {
    Write-Host " [X] Execution failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Validation
if (Test-Path $outputPath) {
    $sizeKB = [math]::Round((Get-Item $outputPath).Length / 1KB, 1)
    Write-Host "`n ────────────────────────────────────────────────────────────" -ForegroundColor Gray
    Write-Host " [SUCCESS]" -ForegroundColor Green -NoNewline
    Write-Host " File saved to: $outputPath ($sizeKB KB)" -ForegroundColor White
    
    # Open folder and select file
    if (Test-Path $outputPath) {
        $absolutePath = (Resolve-Path $outputPath).Path
        Start-Process explorer.exe -ArgumentList "/select,`"$absolutePath`""
    }
} else {
    Write-Host " [!] Error: The output file was not created." -ForegroundColor Red
}

Write-Host "`n [DONE] Press Enter to exit..." -ForegroundColor Cyan
Read-Host

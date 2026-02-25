# Windows Autopilot CSV Generator
# Feb 2026 - V1.4.0 (Added direct Intune upload via config.json)

# 1. Administrative Privileges Check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host " [!] Requesting Administrative privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

function Show-Banner {
    Clear-Host
    Write-Host "
    ___   __  __________  ____  ____  __    ____  ______
   /   | / / / /_  __/ __ \/ __ \/  _/ /   / __ \/_  __/
  / /| |/ / / / / / / / / / /_/ // // /   / / / / / /
 / ___ / /_/ / / / / /_/ / ____// // /___/ /_/ / / /
/_/  |_\____/ /_/  \____/_/   /___/_____/\____/ /_/

      >> WINDOWS AUTOPILOT INFO COLLECTOR <<
    " -ForegroundColor Cyan
    Write-Host " --------------------------------------------------------" -ForegroundColor Gray
}

Show-Banner

$tempPath = "C:\Windows\Temp"
$scriptName = "Get-WindowsAutoPilotInfo.ps1"
$scriptPath = Join-Path $tempPath $scriptName
$scriptDir = Split-Path -Parent $PSCommandPath
$configPath = Join-Path $scriptDir "config.json"

Set-ExecutionPolicy RemoteSigned -Scope Process -Force | Out-Null

# 2. Load config.json if available
$config = $null
if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        if (-not ($config.TenantId -and $config.ClientId -and $config.ClientSecret)) {
            Write-Host " [!] config.json found but incomplete. Upload mode disabled." -ForegroundColor Yellow
            $config = $null
        } else {
            Write-Host " [OK] Config loaded. Intune upload available." -ForegroundColor Green
        }
    } catch {
        Write-Host " [!] config.json could not be parsed. Upload mode disabled." -ForegroundColor Yellow
        $config = $null
    }
}

# 3. Smarter Dependency Handling
if (-not (Test-Path $scriptPath)) {
    Write-Host " [i] Downloading Microsoft script..." -ForegroundColor Yellow
    try {
        Save-Script -Name Get-WindowsAutoPilotInfo -Path $tempPath -Force -ErrorAction Stop
        $downloadedFile = Get-ChildItem -Path $tempPath -Filter $scriptName -Recurse | Select-Object -First 1
        if ($downloadedFile -and $downloadedFile.FullName -ne $scriptPath) {
            Move-Item -Path $downloadedFile.FullName -Destination $scriptPath -Force
        }
        Write-Host " [OK] Download complete." -ForegroundColor Green
    } catch {
        Write-Host " [X] Critical Error: Could not download script." -ForegroundColor Red
        Write-Host "     Please check your internet connection." -ForegroundColor White
        Read-Host "`n Press Enter to exit..."
        exit
    }
} else {
    Write-Host " [OK] Local script ready." -ForegroundColor Gray
}

# 4. Mode Selection
$uploadMode = $false
if ($config) {
    Write-Host "`n [?] Select output mode:" -ForegroundColor Green
    Write-Host "     [1] Save CSV to USB / Local" -ForegroundColor White
    Write-Host "     [2] Upload directly to Intune" -ForegroundColor White
    $modeInput = Read-Host "  > "
    if ($modeInput -eq "2") { $uploadMode = $true }
}

# 5. Filename & Path Safety
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

# 6. Robust USB Detection
$usbDrive = (Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -and $_.DriveLetter -and $_.OperationalStatus -eq 'OK' } | Select-Object -First 1).DriveLetter

if ($usbDrive) {
    $outputPath = Join-Path "${usbDrive}:\" $filename
    Write-Host " [+] Target: USB Drive ($($usbDrive):)" -ForegroundColor Yellow
} else {
    $outputPath = Join-Path $tempPath $filename
    Write-Host " [!] Target: No USB found. Using fallback ($tempPath)" -ForegroundColor Yellow
}

# 7. Generate CSV
Write-Host "`n [*] Generating CSV..." -ForegroundColor Blue
try {
    & $scriptPath -OutputFile $outputPath -ErrorAction Stop
} catch {
    Write-Host " [X] Execution failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 8. Validate & Output
if (Test-Path $outputPath) {
    $sizeKB = [math]::Round((Get-Item $outputPath).Length / 1KB, 1)
    Write-Host "`n --------------------------------------------------------" -ForegroundColor Gray
    Write-Host " [OK] " -ForegroundColor Green -NoNewline
    Write-Host "CSV saved to: $outputPath ($sizeKB KB)" -ForegroundColor White

    if ($uploadMode) {
        Write-Host "`n [*] Authenticating with Microsoft Graph..." -ForegroundColor Blue
        try {
            $tokenBody = @{
                grant_type    = "client_credentials"
                client_id     = $config.ClientId
                client_secret = $config.ClientSecret
                scope         = "https://graph.microsoft.com/.default"
            }
            $tokenResponse = Invoke-RestMethod -Method Post `
                -Uri "https://login.microsoftonline.com/$($config.TenantId)/oauth2/v2.0/token" `
                -Body $tokenBody -ErrorAction Stop
            $accessToken = $tokenResponse.access_token
            Write-Host " [OK] Authenticated." -ForegroundColor Green
        } catch {
            Write-Host " [X] Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "`n [DONE] Press Enter to exit..." -ForegroundColor Cyan
            Read-Host
            exit
        }

        Write-Host " [*] Uploading to Intune..." -ForegroundColor Blue
        try {
            $csvData = Import-Csv -Path $outputPath
            $headers = @{ Authorization = "Bearer $accessToken"; "Content-Type" = "application/json" }

            foreach ($device in $csvData) {
                $body = @{
                    serialNumber              = $device."Device Serial Number"
                    hardwareIdentifier        = $device."Hardware Hash"
                    groupTag                  = ""
                    assignedUserPrincipalName = ""
                } | ConvertTo-Json

                Invoke-RestMethod -Method Post `
                    -Uri "https://graph.microsoft.com/v1.0/deviceManagement/importedWindowsAutopilotDeviceIdentities" `
                    -Headers $headers -Body $body -ErrorAction Stop

                Write-Host " [OK] Uploaded: $($device.'Device Serial Number')" -ForegroundColor Green
            }

            Write-Host "`n --------------------------------------------------------" -ForegroundColor Gray
            Write-Host " [SUCCESS] " -ForegroundColor Green -NoNewline
            Write-Host "Device registered in Intune Autopilot." -ForegroundColor White
            Write-Host "         Note: May take a few minutes to appear in Intune." -ForegroundColor Gray
        } catch {
            Write-Host " [X] Upload failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        $absolutePath = (Resolve-Path $outputPath).Path
        Start-Process explorer.exe -ArgumentList "/select,`"$absolutePath`""
    }
} else {
    Write-Host " [!] Error: The output file was not created." -ForegroundColor Red
}

Write-Host "`n [DONE] Press Enter to exit..." -ForegroundColor Cyan
Read-Host

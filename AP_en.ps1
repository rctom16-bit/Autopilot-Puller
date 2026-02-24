# Windows Autopilot CSV Generator - Robin Oertel
# Feb 2026 - V1.0 (English Version)

Clear-Host
Write-Host "Windows Autopilot Info Collector" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Gray

$tempPath = "C:\Windows\Temp"

Set-ExecutionPolicy RemoteSigned -Scope Process -Force | Out-Null

Write-Host "`nLoading Microsoft script..." -ForegroundColor Yellow
#Script install
Save-Script -Name Get-WindowsAutoPilotInfo -Path $tempPath -Force | Out-Null
Install-Script -Name Get-WindowsAutoPilotInfo -Force | Out-Null

#Read Host waits for User entry
Write-Host "`nEnter filename:" -ForegroundColor Green
$filename = Read-Host " (Enter = Auto)"

#If the entered Filename is not filled, the script automatically fills in the serial number as a name
if (!$filename.Trim()) { 
    $serialNumber = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber 
	$filename = "${serialNumber}_Autopilot.csv".Replace('/','_').Replace('\','_')
    Write-Host " -> Serial: $serialNumber" -ForegroundColor Yellow
	Write-Host " -> $filename" -ForegroundColor Magenta
} else {
    if ($filename -notlike '*.csv') { 
        $filename += '.csv'
        Write-Host " -> CSV: $filename" -ForegroundColor Magenta
    }
}
#Path parameters, if D is not found it will save the csv in C:\Windows\Temp. You can change the D: path to any other you want
$scriptPath = "$tempPath\Get-WindowsAutoPilotInfo.ps1"
$outputPath = "D:\$filename"

#If you change D: above change it here too
#Testing if D: path is available
if (!(Test-Path 'D:')) { 
    $outputPath = "C:\Windows\Temp\$filename"
    Write-Host "D: Path not found, file will be saved here -> C:\Windows\Temp" -ForegroundColor Yellow
}

Write-Host "`nGenerating: $outputPath" -ForegroundColor Blue
& $scriptPath -OutputFile $outputPath

#Output when success
if (Test-Path $outputPath) {
    $sizeKB = [math]::Round((Get-Item $outputPath).Length / 1KB, 1)
    Write-Host "`nDone generating the File!" -ForegroundColor Green
    Write-Host "$outputPath" -ForegroundColor White
    Write-Host "Size: $sizeKB KB" -ForegroundColor Cyan
	
#Output when error
} else {
    Write-Host "`nError!" -ForegroundColor Red
}

Write-Host "`nPress Enter to exit..."
Read-Host

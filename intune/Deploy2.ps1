# Set the working directory explicitly (adjust the path as needed)
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location -Path $ScriptDirectory

# Silent installation of the MSI
$MsiPath = Join-Path $ScriptDirectory "computer-logon-for-entra-id-win64.msi"
$LogFilePath = "C:\Windows\Logs\nano_Install.log"

Start-Process -FilePath "C:\Windows\System32\msiexec.exe" -Wait -ArgumentList "/i `"$MsiPath`" /qn /norestart /L*vx `"$LogFilePath`""

# Paths for copying the config file
$Destination = "$env:ProgramData\Deepnet Security\clo-entra-id\"
$Source = Join-Path $ScriptDirectory "config.json"

# Create the destination folder if it doesn't exist
if (!(Test-Path -Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force
}

# Copy the config file to the destination
Copy-Item -Path $Source -Destination $Destination -Force

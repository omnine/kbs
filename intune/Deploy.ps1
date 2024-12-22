# Silent installation of the MSI, do NOT use .\computer-logon-for-entra-id-win64.msi
Start-Process -FilePath "C:\Windows\System32\msiexec.exe" -Wait -ArgumentList '/i computer-logon-for-entra-id-win64.msi /qn /norestart /L*vx "C:\Windows\Logs\nano_Install.log"'

# Paths for copying the config file
$Destination = "$env:ProgramData\Deepnet Security\clo-entra-id\"
$Source = ".\config.json"

# Create the destination folder if it doesn't exist
if (!(Test-Path -Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force
}

# Copy the config file to the destination
Copy-Item -Path $Source -Destination $Destination -Force

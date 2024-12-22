if (Test-Path "$env:ProgramData\Deepnet Security\clo-entra-id\config.json") {
    Write-Host ("The customized config file was found...")
    exit 0	
}
else {
    Write-Host ("Not customized config file was found...")
    exit 1	
}

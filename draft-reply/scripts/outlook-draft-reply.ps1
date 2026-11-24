# Opens a Reply All window for the email selected in Classic Outlook, with the Markdown in
# $env:TEMP\claude_reply.txt rendered as HTML above the original thread. Never sends.
# Must run under Windows PowerShell 5.1 (powershell.exe): PowerShell 7 has no Marshal.GetActiveObject.
# The Markdown conversion runs in pwsh (PowerShell 7) via outlook-md-to-html.ps1.
$htmlPath = "$env:TEMP\claude_reply.html"
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'outlook-md-to-html.ps1') -InPath "$env:TEMP\claude_reply.txt" -OutPath $htmlPath
if ($LASTEXITCODE -ne 0) { throw "Markdown conversion failed" }
$draft = Get-Content $htmlPath -Raw -Encoding UTF8

$ol = [Runtime.InteropServices.Marshal]::GetActiveObject('Outlook.Application')
$mail = $ol.ActiveExplorer().Selection.Item(1)
$reply = $mail.ReplyAll()
$body = $reply.HTMLBody

# Put the draft just inside <body> (above any reply signature and the quoted thread).
$m = [regex]::Match($body, '<body[^>]*>', 'IgnoreCase')
if ($m.Success) {
    $reply.HTMLBody = $body.Insert($m.Index + $m.Length, $draft + '<br>')
} else {
    $reply.HTMLBody = $draft + '<br>' + $body
}
$reply.Display()

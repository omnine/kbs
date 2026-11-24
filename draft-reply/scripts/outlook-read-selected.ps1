# Prints the subject, sender and body of the email selected in Classic Outlook, and saves its
# attachments (inline images included) to $env:TEMP\claude_outlook_attachments, listing them at the end.
# Must run under Windows PowerShell 5.1 (powershell.exe): PowerShell 7 has no Marshal.GetActiveObject.
$ol = [Runtime.InteropServices.Marshal]::GetActiveObject('Outlook.Application')
$mail = $ol.ActiveExplorer().Selection.Item(1)

# Remember exactly which email this was, so outlook-draft-reply.ps1 replies to it even if the
# user selects another email in the meantime. Line 1: EntryID, line 2: StoreID, line 3: subject.
$idFile = Join-Path $env:TEMP 'claude_outlook_selected.txt'
[IO.File]::WriteAllLines($idFile, [string[]]@($mail.EntryID, $mail.Parent.StoreID, $mail.Subject), [Text.UTF8Encoding]::new($false))

Write-Output ('Subject: ' + $mail.Subject)
Write-Output ('From: ' + $mail.SenderName)
Write-Output ('To: ' + $mail.To)
if ($mail.CC) { Write-Output ('CC: ' + $mail.CC) }
Write-Output ('Received: ' + $mail.ReceivedTime)
Write-Output '---BODY---'
Write-Output $mail.Body

# This folder belongs to this script alone; it is emptied on every run so it only holds the current email's files.
$dir = Join-Path $env:TEMP 'claude_outlook_attachments'
if (Test-Path $dir) { Remove-Item (Join-Path $dir '*') -Recurse -Force }
else { New-Item -ItemType Directory -Path $dir | Out-Null }

Write-Output '---ATTACHMENTS---'
$count = $mail.Attachments.Count
if ($count -eq 0) { Write-Output '(none)'; return }

$html = $mail.HTMLBody
$invalid = [regex]::Escape(-join [IO.Path]::GetInvalidFileNameChars())
for ($i = 1; $i -le $count; $i++) {
    $a = $mail.Attachments.Item($i)
    $name = $a.FileName
    if (-not $name) { $name = $a.DisplayName }
    if (-not $name) { $name = "attachment$i" }
    # Index prefix keeps names unique (e.g. several image001.png across forwarded mails).
    $file = '{0:D2}_{1}' -f $i, ($name -replace "[$invalid]", '_')
    $path = Join-Path $dir $file

    # Inline = an image the HTML body shows via cid:, e.g. a pasted screenshot or a signature logo.
    $inline = $false
    try {
        $cid = $a.PropertyAccessor.GetProperty('http://schemas.microsoft.com/mapi/proptag/0x3712001F')
        if ($cid -and $html -and $html.Contains("cid:$cid")) { $inline = $true }
    } catch { }

    try {
        $a.SaveAsFile($path)
        $kb = [math]::Ceiling((Get-Item $path).Length / 1KB)
        Write-Output ('{0}  ({1} KB{2})' -f $path, $kb, $(if ($inline) { ', inline' } else { '' }))
    } catch {
        Write-Output ('NOT SAVED: {0}  ({1})' -f $name, $_.Exception.Message)
    }
}

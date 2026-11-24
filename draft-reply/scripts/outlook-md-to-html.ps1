# Converts a Markdown file to an email-safe HTML fragment with inline styles
# (Outlook's Word renderer ignores most <style> CSS, so every tag is styled inline).
# Needs PowerShell 7 (pwsh) for ConvertFrom-Markdown.
param(
    [string]$InPath  = "$env:TEMP\claude_reply.txt",
    [string]$OutPath = "$env:TEMP\claude_reply.html"
)

$md = Get-Content $InPath -Raw -Encoding UTF8
$html = (ConvertFrom-Markdown -InputObject $md).Html

# Emails use single line breaks ("Best regards,<newline>Name"): keep them inside paragraphs.
$html = $html -replace '(?s)<p>(.*?)</p>', { '<p>' + ($_.Groups[1].Value -replace '\r?\n', '<br>') + '</p>' }

$mono ="font-family:Consolas,'Courier New',monospace; font-size:10pt;"
$border = '#d0d7de'

# Code blocks first, so the inline <code> rule below doesn't also hit them.
$html = $html -replace '<pre><code[^>]*>', "<pre style=""$mono background:#f6f8fa; border:1px solid $border; padding:8pt; margin:0 0 10pt; white-space:pre-wrap;""><code style=""$mono"">"

$styles = [ordered]@{
    'p'          = 'margin:0 0 10pt;'
    'h1'         = 'font-size:16pt; font-weight:bold; margin:14pt 0 6pt;'
    'h2'         = 'font-size:14pt; font-weight:bold; margin:12pt 0 6pt;'
    'h3'         = 'font-size:12pt; font-weight:bold; margin:10pt 0 4pt;'
    'ul'         = 'margin:0 0 10pt; padding-left:24pt;'
    'ol'         = 'margin:0 0 10pt; padding-left:24pt;'
    'li'         = 'margin:0 0 4pt;'
    'code'       = "$mono background:#f3f3f3; padding:0 3px;"
    'blockquote' = "margin:0 0 10pt; padding:0 0 0 10pt; border-left:3px solid $border; color:#555555;"
    'table'      = 'border-collapse:collapse; margin:0 0 10pt;'
    'th'         = "border:1px solid $border; padding:4pt 8pt; background:#f3f3f3; text-align:left; font-weight:bold;"
    'td'         = "border:1px solid $border; padding:4pt 8pt; vertical-align:top;"
    'hr'         = "border:none; border-top:1px solid $border; margin:12pt 0;"
}
foreach ($tag in $styles.Keys) {
    # Matches <tag> and <tag attr...>, but not tags already given a style above.
    $html = $html -replace "<$tag(?=[\s>])(?![^>]*\sstyle=)", "<$tag style=""$($styles[$tag])"""
}
$html = $html -replace '<a (?![^>]*\sstyle=)', '<a style="color:#0563C1;" '

# Tight lists render <li><p>..</p></li> in loose mode; drop the extra paragraph gap.
$html = $html -replace '(<li[^>]*>)\s*<p style="[^"]*">', '$1<p style="margin:0;">'

$out = '<div style="font-family:Calibri,Arial,sans-serif; font-size:11pt; color:#000000;">' + $html + '</div>'
[IO.File]::WriteAllText($OutPath, $out, [Text.UTF8Encoding]::new($false))

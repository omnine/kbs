# draft-reply

My first Claude Code command. `/draft-reply` reads the email you have selected in Classic Outlook, looks into the issue in the codebase you are working in, and opens a **Reply All** draft in Outlook with the answer already written above the original thread. You review the draft, edit it if needed, and send it yourself: nothing is ever sent automatically.

## How it works

```
Outlook (selected email) ──► outlook-read-selected.ps1 ──► Claude Code
                                (subject, body, attachments)      │
                                                                  ▼
                                                    searches / reads the codebase
                                                                  │
                                              writes %TEMP%\claude_reply.txt (Markdown)
                                                                  ▼
                 outlook-draft-reply.ps1 ──► outlook-md-to-html.ps1 (Markdown → inline-styled HTML)
                         │
                         ▼
             Outlook Reply All window, draft inserted above the thread (not sent)
```

| File | Purpose |
|---|---|
| `commands/draft-reply.md` | The slash command: the instructions Claude follows |
| `scripts/outlook-read-selected.ps1` | Prints subject, sender, recipients and body of the selected email; saves attachments to `%TEMP%\claude_outlook_attachments` |
| `scripts/outlook-md-to-html.ps1` | Converts the Markdown reply into email-safe HTML with inline styles (Outlook's Word renderer ignores most CSS) |
| `scripts/outlook-draft-reply.ps1` | Opens a Reply All window with the HTML draft inserted above the signature and quoted thread |

## Prerequisites

- **Windows** with **Classic Outlook** (desktop Outlook from Microsoft 365 / Office). The *new* Outlook for Windows and Outlook on the web have no COM automation and do not work.
- **Outlook running**, with the email you want to answer selected in the main window.
- **Windows PowerShell 5.1** (`powershell.exe`, built into Windows). The Outlook scripts must run here, because PowerShell 7 has no `Marshal.GetActiveObject`.
- **PowerShell 7** (`pwsh`) on `PATH`. The Markdown-to-HTML step uses its `ConvertFrom-Markdown` cmdlet. Install it with `winget install Microsoft.PowerShell` if `pwsh -v` fails.
- **Claude Code** installed (CLI, desktop app or IDE extension).
- Claude Code and Outlook running at the **same privilege level**. If one runs as Administrator and the other doesn't, `GetActiveObject` can't see Outlook.

## Deploy

The command expects the scripts at `%USERPROFILE%\.claude\scripts\`. Install it for your user, so it is available in every project:

```powershell
# from the draft-reply folder
New-Item -ItemType Directory -Force "$env:USERPROFILE\.claude\commands", "$env:USERPROFILE\.claude\scripts" | Out-Null
Copy-Item .\commands\draft-reply.md "$env:USERPROFILE\.claude\commands\"
Copy-Item .\scripts\*.ps1 "$env:USERPROFILE\.claude\scripts\"
```

Then restart Claude Code (or start a new session) and check that `/draft-reply` appears when you type `/`.

The scripts are launched with `-ExecutionPolicy Bypass`, so you don't need to change your system execution policy.

**Optional, fewer permission prompts:** Claude asks before running each PowerShell command. To allow the two Outlook scripts without asking, add the commands to `permissions.allow` in `%USERPROFILE%\.claude\settings.json` (or run `/permissions` in Claude Code and allow them when first prompted).

To update later, copy the files again. To uninstall, delete `draft-reply.md` from `~\.claude\commands` and the three `outlook-*.ps1` files from `~\.claude\scripts`.

## Use

1. Open Classic Outlook and **select** the email you want to answer (a single click in the message list is enough; it doesn't need to be opened).
2. Start Claude Code **in the project the email is about**, for example the repo of the product the customer is asking about. Claude searches that working directory to investigate.
3. Run the command:

   | Command | What happens |
   |---|---|
   | `/draft-reply` | Reads the email, investigates, and opens a Reply All draft in Outlook |
   | `/draft-reply --no-draft` | Lookup only: reports in the terminal what the email asks, what the code shows (with `file:line` references) and what it would reply. No draft is opened; you can ask for one later in the same conversation |
   | `/draft-reply <instructions>` | Adds your own guidance, e.g. `/draft-reply check the RADIUS timeout handling, keep it short` |
   | `/draft-reply --no-draft <instructions>` | Both of the above |

4. Review the draft window Outlook opens: check the facts, adjust the tone, then press **Send** yourself.

### Attachments

Attachments, including screenshots pasted into the email, are saved to `%TEMP%\claude_outlook_attachments`, which is emptied on every run. Claude reads the ones that matter (images, PDFs, text and logs) and skips signature logos. It never runs or extracts attachments such as archives, executables or scripts; if one of those looks important, it tells you instead.

### Files left in %TEMP%

| Path | Content |
|---|---|
| `%TEMP%\claude_outlook_attachments\` | Attachments of the last email read |
| `%TEMP%\claude_reply.txt` | Last reply as Markdown |
| `%TEMP%\claude_reply.html` | Last reply as HTML |

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Operation unavailable (Exception from HRESULT: 0x800401E3 (MK_E_UNAVAILABLE))` | Outlook isn't running, you're using the new Outlook, or Outlook and Claude Code run at different privilege levels (one as Administrator). |
| `Method invocation failed ... GetActiveObject` | The script ran under PowerShell 7. Run it with `powershell.exe`, as the command does. |
| `Markdown conversion failed` or `pwsh is not recognized` | PowerShell 7 isn't installed or isn't on `PATH`. |
| Wrong email answered / `Array index out of bounds` | Nothing (or a different item) was selected in the active Outlook window. Select the email and run again. |
| `.ps1 cannot be loaded because running scripts is disabled` | The script was run without `-ExecutionPolicy Bypass`; use the command lines from `commands/draft-reply.md`. |

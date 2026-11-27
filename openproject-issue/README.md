# openproject-issue

A [Claude Code](https://claude.com/claude-code) skill that creates issues (work packages) in
[OpenProject](https://www.openproject.org/) through its REST API v3.

Ask Claude something like *"file a bug in OpenProject for the login 500 error"*, or run
`/openproject-issue <project> <subject> [type] [details...]`. Claude collects the fields, shows you a
one-line summary, and after you confirm it creates the work package and reports its ID and URL.

Works on **Windows, Linux and macOS**: Claude uses the PowerShell helper on Windows and the Python
helper elsewhere.

## Files

| File | Purpose |
|---|---|
| `SKILL.md` | The skill definition: frontmatter (name, trigger description, allowed tools) and the instructions Claude follows |
| `scripts/New-OpenProjectIssue.ps1` | Windows helper (PowerShell 5.1 / 7+) that does the API work: auth, name-to-ID lookups, validation, creation |
| `scripts/new_openproject_issue.py` | Linux/macOS helper with the same behaviour (Python 3.8+, standard library only, no `pip install`) |

## Install

Copy this folder into your Claude Code skills directory (personal or project level):

```bash
# Linux/macOS, personal: available in every project
mkdir -p ~/.claude/skills && cp -r openproject-issue ~/.claude/skills/

# or project level: only in this repo
mkdir -p .claude/skills && cp -r openproject-issue .claude/skills/
```

```powershell
# Windows, personal
Copy-Item -Recurse openproject-issue "$HOME\.claude\skills\"

# or project level
Copy-Item -Recurse openproject-issue ".claude\skills\"
```

The README is ignored by Claude Code; only `SKILL.md` and the scripts matter.

`SKILL.md` refers to the scripts under `~/.claude/skills/openproject-issue/scripts/`.
If you install at project level, change those paths in `SKILL.md`.

Start a new Claude Code session; the skill shows up as `/openproject-issue`.

## Configuration

Both scripts read two environment variables:

| Variable | Value |
|---|---|
| `OPENPROJECT_URL` | Base URL, e.g. `https://openproject.example.com` |
| `OPENPROJECT_API_KEY` | Personal API token: OpenProject → **My account** → **Access tokens** → **API** |

Set them yourself, outside the chat, so the token never appears in the conversation:

```bash
# Linux/macOS: add to ~/.bashrc (or ~/.zshrc, ~/.profile)
export OPENPROJECT_URL="https://openproject.example.com"
export OPENPROJECT_API_KEY="<token>"
```

```powershell
# Windows
[Environment]::SetEnvironmentVariable("OPENPROJECT_URL", "https://openproject.example.com", "User")
[Environment]::SetEnvironmentVariable("OPENPROJECT_API_KEY", "<token>", "User")
```

Restart the terminal (and Claude Code) afterwards so the new values are picked up.

## How it works

1. **Auth**: HTTP Basic with user `apikey` and the token as password.
2. **Name resolution**: type, priority, status and assignee are given by name. The script fetches
   `/api/v3/projects/{id}/types`, `/api/v3/priorities`, `/api/v3/statuses` and
   `/api/v3/projects/{id}/available_assignees`, then matches case-insensitively: an exact match first,
   otherwise a unique partial match. Assignees also match on login and email. An ambiguous or unknown
   name fails with the list of valid values.
3. **Payload**: a HAL+JSON body with `subject`, `description` (markdown), dates, `estimatedTime`
   (ISO 8601 `PT{n}H`) and `_links` for type, priority, status, assignee and parent.
4. **Dry run**: `-DryRun` / `--dry-run` posts to `/api/v3/projects/{id}/work_packages/form`, which validates the
   payload and returns per-field errors without creating anything.
5. **Create**: `POST /api/v3/projects/{id}/work_packages` (with `?notify=false` when `-NoNotify` / `--no-notify` is set).

Both scripts send the token only in the `Authorization` header from inside the process, so it never
shows up in a command line or the process list.

## Using the scripts directly

The scripts also work on their own, without Claude.

Linux/macOS:

```bash
s=./scripts/new_openproject_issue.py

python3 "$s" --project my-project --list
python3 "$s" --project my-project --subject "Login page returns 500" --type Bug --dry-run
python3 "$s" --project my-project --subject "Login page returns 500" --type Bug   --priority High --assignee jane --due-date 2026-12-05 --description-file desc.md
```

Windows:

```powershell
$s = ".\scripts\New-OpenProjectIssue.ps1"

# list types / priorities / statuses / assignees for a project
& $s -Project my-project -List

# validate only
& $s -Project my-project -Subject "Login page returns 500" -Type Bug -DryRun

# create
& $s -Project my-project -Subject "Login page returns 500" -Type Bug `
     -Priority High -Assignee "jane" -DueDate 2026-12-05 `
     -Description "**Steps**`n1. Open /login`n2. Submit empty form`n`n**Actual:** HTTP 500"
```

| Python | PowerShell | Notes |
|---|---|---|
| `--project` | `-Project` | Required. Identifier or numeric id |
| `--subject` | `-Subject` | Required, except in list mode |
| `--type` | `-Type` | Name, default `Task`; must be enabled in the project |
| `--description` / `--description-file` | `-Description` / `-DescriptionFile` | Markdown |
| `--priority`, `--status` | `-Priority`, `-Status` | Name |
| `--assignee` | `-Assignee` | Name, login or email; a partial match is fine if it's unique |
| `--start-date`, `--due-date` | `-StartDate`, `-DueDate` | `yyyy-MM-dd` |
| `--estimated-hours` | `-EstimatedHours` | Number, sent as `PT{n}H` |
| `--parent` | `-Parent` | Parent work package id |
| `--no-notify` | `-NoNotify` | No email notifications |
| `--dry-run` | `-DryRun` | Validate only, create nothing |
| `--list` | `-List` | Print the lookup tables and exit |

## Safety behaviour built into the skill

- Claude confirms with a one-line summary before creating, because a new work package changes a
  shared tracker and can email people.
- Claude never asks for the token in chat, never echoes it, and never passes it on a command line.
- Claude asks only when the project or subject is missing, and doesn't invent facts for bug descriptions.

## Troubleshooting

| Error | Cause |
|---|---|
| `python3: command not found` | Install Python 3 (`apt install python3`, `dnf install python3`), or use the PowerShell script with `pwsh` |
| 401 | Token wrong or expired |
| 403 | User lacks the **Add work packages** permission in the project |
| 404 on the project | Wrong identifier, or the user can't see the project |
| 422 | Missing required field (often a required custom field) or the type isn't enabled in the project. Run a dry run to see each field's error |

Custom fields aren't script parameters. For those, call the API directly: plain values go at the top
level as `customFieldN`; list or user values go under `_links.customFieldN.href`.

## References

- OpenProject API v3 work packages: https://www.openproject.org/docs/api/endpoints/work-packages/
- Your server's interactive docs: `<OPENPROJECT_URL>/api/docs`
- Claude Code skills: https://docs.claude.com/en/docs/claude-code/skills

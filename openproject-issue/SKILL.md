---
name: openproject-issue
description: Create an issue (work package) in OpenProject through its REST API v3. Use when the user asks to create, file, open or log an issue, bug, task, feature or work package in OpenProject, or runs /openproject-issue. Can also list a project's types, priorities, statuses and assignees.
argument-hint: "<project> <subject> [type] [details...]"
allowed-tools: PowerShell, Bash, Read
---

# Create an OpenProject issue

Use one of the two helper scripts in this skill's `scripts/` folder
(normally `~/.claude/skills/openproject-issue/scripts/`). They behave the same: they handle auth,
look up IDs from names (type, priority, status, assignee), and print the new work package's ID and URL.

| Platform | Script | Needs |
|---|---|---|
| Linux, macOS | `new_openproject_issue.py` | Python 3.8+ (standard library only) |
| Windows | `New-OpenProjectIssue.ps1` | PowerShell 5.1 or 7+ |

On Windows without PowerShell, the Python script works too. On Linux with `pwsh` installed, the
PowerShell script works too.

User arguments: $ARGUMENTS

## Prerequisites

You need two environment variables:
- `OPENPROJECT_URL`: the base URL, e.g. `https://openproject.example.com`
- `OPENPROJECT_API_KEY`: a personal API token (OpenProject → My account → Access tokens → API)

If either is missing, the script stops with an error. Tell the user to set it themselves, for example:
```bash
# Linux/macOS: add to ~/.bashrc or ~/.profile, then open a new shell
export OPENPROJECT_URL="https://openproject.example.com"
export OPENPROJECT_API_KEY="<token>"
```
```powershell
# Windows
[Environment]::SetEnvironmentVariable("OPENPROJECT_API_KEY", "<token>", "User")
```
Never ask the user to paste the token into chat. Never echo the token, and never put it in a command line.

## Steps

1. **Collect the inputs** from `$ARGUMENTS` and the conversation:
   - project: an identifier like `my-project`, or a numeric id
   - subject
   - type: defaults to `Task`
   - optional: description, priority, assignee, status, start/due dates, estimate, parent id

   Ask only when the project or the subject is missing. If the user described a bug, write a short
   markdown description (Steps to reproduce / Expected / Actual) from what they said. Don't invent facts.
2. **Check names when unsure.** If you don't know which types or assignee names exist, run with list mode first.
3. **Confirm before creating.** Creating a work package changes the shared tracker and can email people.
   Unless the user's request already said to go ahead, show a one-line summary
   (project, type, subject, assignee, priority) and wait for a yes.
   Dry-run mode checks the payload against the server without creating anything.
4. **Create** the work package and report its ID and URL to the user.

## Usage on Linux / macOS (Bash)

```bash
s=~/.claude/skills/openproject-issue/scripts/new_openproject_issue.py

# list types / priorities / statuses / assignees for a project
python3 "$s" --project my-project --list

# validate only
python3 "$s" --project my-project --subject "Login page returns 500" --type Bug --dry-run

# create
python3 "$s" --project my-project --subject "Login page returns 500" --type Bug \
  --priority High --assignee jane --due-date 2026-12-05 \
  --description-file /path/to/desc.md
```

## Usage on Windows (PowerShell)

```powershell
$s = "$HOME/.claude/skills/openproject-issue/scripts/New-OpenProjectIssue.ps1"

& $s -Project my-project -List
& $s -Project my-project -Subject "Login page returns 500" -Type Bug -DryRun
& $s -Project my-project -Subject "Login page returns 500" -Type Bug `
     -Priority High -Assignee "jane" -DueDate 2026-12-05 `
     -Description "**Steps**`n1. Open /login`n2. Submit empty form`n`n**Actual:** HTTP 500"
```

For long descriptions, write the markdown to a temp file in the scratchpad and pass it as a file
(`--description-file` / `-DescriptionFile`). That avoids quoting problems.

## Parameters

| Python | PowerShell | Notes |
|---|---|---|
| `--project` | `-Project` | Required. Identifier or numeric id |
| `--subject` | `-Subject` | Required, except in list mode |
| `--type` | `-Type` | Name, default `Task`; must be enabled in the project |
| `--description` / `--description-file` | `-Description` / `-DescriptionFile` | Markdown |
| `--priority`, `--status` | `-Priority`, `-Status` | Name |
| `--assignee` | `-Assignee` | Name, login or email; a partial match is fine if it's unique |
| `--start-date`, `--due-date` | `-StartDate`, `-DueDate` | `yyyy-MM-dd` |
| `--estimated-hours` | `-EstimatedHours` | Number, sent as ISO 8601 duration `PT{n}H` |
| `--parent` | `-Parent` | Parent work package id |
| `--no-notify` | `-NoNotify` | Adds `?notify=false` so no emails go out |
| `--dry-run` | `-DryRun` | Validates through `/work_packages/form` and creates nothing |
| `--list` | `-List` | Prints the lookup tables and exits |

## Errors

- **422**: a required field is missing, often a required custom field, or the type isn't enabled
  in the project. Run a dry run to see each field's error. Custom fields aren't parameters, so for
  those call the API directly. Plain values go at the top level as `customFieldN`; list or user values go
  under `_links.customFieldN.href`.
- **401**: the token is wrong or expired.
- **403**: the user lacks the "Add work packages" permission in that project.
- **404** on the project: wrong identifier, or the user can't see the project.

API reference: `<OPENPROJECT_URL>/api/docs`, or https://www.openproject.org/docs/api/endpoints/work-packages/

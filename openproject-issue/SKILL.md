---
name: openproject-issue
description: Create an issue (work package) in OpenProject through its REST API v3. Use when the user asks to create, file, open or log an issue, bug, task, feature or work package in OpenProject, or runs /openproject-issue. Can also list a project's types, priorities, statuses and assignees.
argument-hint: "<project> <subject> [type] [details...]"
allowed-tools: PowerShell, Bash, Read
---

# Create an OpenProject issue

Use the helper script `scripts/New-OpenProjectIssue.ps1` in this skill's folder
(`~/.claude/skills/openproject-issue/scripts/New-OpenProjectIssue.ps1`). It handles
auth, looks up IDs from names (type, priority, status, assignee), and prints the new work package's ID and URL.

User arguments: $ARGUMENTS

## Prerequisites

You need two environment variables:
- `OPENPROJECT_URL`: the base URL, e.g. `https://openproject.example.com`
- `OPENPROJECT_API_KEY`: a personal API token (OpenProject → My account → Access tokens → API)

If either is missing, the script stops with an error. Tell the user to set it themselves, for example:
```powershell
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
2. **Check names when unsure.** If you don't know which types or assignee names exist, run with `-List` first.
3. **Confirm before creating.** Creating a work package changes the shared tracker and can email people.
   Unless the user's request already said to go ahead, show a one-line summary
   (project, type, subject, assignee, priority) and wait for a yes.
   `-DryRun` checks the payload against the server without creating anything.
4. **Create** the work package and report its ID and URL to the user.

## Usage

```powershell
$s = "$HOME/.claude/skills/openproject-issue/scripts/New-OpenProjectIssue.ps1"

# list types / priorities / statuses / assignees for a project
& $s -Project my-project -List

# validate only
& $s -Project my-project -Subject "Login page returns 500" -Type Bug -DryRun

# create
& $s -Project my-project -Subject "Login page returns 500" -Type Bug `
     -Priority High -Assignee "jane" -DueDate 2026-12-05 `
     -Description "**Steps**`n1. Open /login`n2. Submit empty form`n`n**Actual:** HTTP 500"
```

For long descriptions, write the markdown to a temp file in the scratchpad and pass `-DescriptionFile <path>`.
That avoids quoting problems.

| Parameter | Notes |
|---|---|
| `-Project` | Required. Identifier or numeric id |
| `-Subject` | Required, except with `-List` |
| `-Type` | Name, default `Task`; must be enabled in the project |
| `-Description` / `-DescriptionFile` | Markdown |
| `-Priority`, `-Status` | Name |
| `-Assignee` | Name, login or email; a partial match is fine if it's unique |
| `-StartDate`, `-DueDate` | `yyyy-MM-dd` |
| `-EstimatedHours` | Number, sent as ISO 8601 duration `PT{n}H` |
| `-Parent` | Parent work package id |
| `-NoNotify` | Adds `?notify=false` so no emails go out |
| `-DryRun` | Validates through `/work_packages/form` and creates nothing |
| `-List` | Prints the lookup tables and exits |

## Errors

- **422**: a required field is missing, often a required custom field, or the type isn't enabled
  in the project. Run `-DryRun` to see each field's error. Custom fields aren't parameters, so for
  those call the API directly. Plain values go at the top level as `customFieldN`; list or user values go
  under `_links.customFieldN.href`.
- **401**: the token is wrong or expired.
- **403**: the user lacks the "Add work packages" permission in that project.
- **404** on the project: wrong identifier, or the user can't see the project.

API reference: `<OPENPROJECT_URL>/api/docs`, or https://www.openproject.org/docs/api/endpoints/work-packages/

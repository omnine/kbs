---
name: wikijs-page
description: Create a page in a self-hosted Wiki.js 3.x wiki through its REST API (/_api). Use when the user asks to create, write, publish, add or post a page, article, doc or how-to in Wiki.js (or "the wiki"), or runs /wikijs-page. Can also check the site and the user's permissions at a path.
argument-hint: "<path> <title> [content or file...]"
allowed-tools: Bash, PowerShell, Read, Write
---

# Create a Wiki.js page

Use the helper script `scripts/new_wikijs_page.py` in this skill's folder
(normally `~/.claude/skills/wikijs-page/scripts/new_wikijs_page.py`). It needs Python 3.8+ and only
the standard library, so it runs on Linux, macOS and Windows. Run it with `python3` on Linux/macOS
and `python` on Windows.

It targets **Wiki.js 3.x** (REST API under `/_api`). Wiki.js 2.x uses a different GraphQL API, so this
script won't work there.

User arguments: $ARGUMENTS

## Prerequisites

Two environment variables:
- `WIKIJS_URL`: the base URL, e.g. `https://wiki.example.com`
- `WIKIJS_TOKEN`: a **personal access token** with the `pages:write` scope
  (Wiki.js → profile menu → Personal Access Tokens). A system API key (Administration → API Keys)
  will **not** work: Wiki.js records a user as each page's author, so it refuses page saves from
  system keys with a 401.

If either is missing, the script stops. Tell the user to set it themselves:
```bash
# Linux/macOS: add to ~/.bashrc or ~/.profile, then open a new shell
export WIKIJS_URL="https://wiki.example.com"
export WIKIJS_TOKEN="<token>"
```
```powershell
# Windows
[Environment]::SetEnvironmentVariable("WIKIJS_TOKEN", "<token>", "User")
```
Never ask the user to paste the token into chat. Never echo the token, and never put it in a command line.

## Rendering

Wiki.js renders markdown to HTML **in the browser editor**. A page saved through the API has no HTML
until something renders it, and until then readers see an empty page. The script handles this:

1. After creating the page it asks the server to render it (`POST …/pages/{id}/render`). That works
   when the **Puppeteer extension** is installed on the server, and gives the exact editor output.
2. As a fallback it also sends an HTML render with the page: from the Python `markdown` package if
   it's installed, or from `--render-file` if given.

If the output says `WARNING: NOT rendered`, the server has no Puppeteer and no HTML was sent.
To avoid that: before creating a page, check `python3 -c "import markdown"`. If that fails,
write an HTML version of the content yourself to a temp file in the scratchpad (plain semantic HTML:
`h1`–`h6` with `id`s, `p`, `ul`/`ol`, `table`, `pre><code`, `a`, `strong`/`em`) and pass it with
`--render-file`. The HTML must say exactly what the markdown says.

## Steps

1. **Collect the inputs** from `$ARGUMENTS` and the conversation:
   - path, e.g. `guides/vpn-setup` (it's lowercased; spaces and underscores become hyphens)
   - title
   - content: markdown. For anything longer than a line, write it to a temp file in the scratchpad
     and pass `--content-file`
   - optional: description, tags, locale, draft

   Ask only when the path, title or content is missing. If the user asks you to write the content
   from material in the conversation or the repo, write it from that material and don't invent facts.
   Don't repeat the title as a `# heading` at the top of the content: Wiki.js shows the title already.
2. **Dry run.** Run with `--dry-run`. It checks that the site resolves, that the user may write
   (and tag) at that path, and that the path is free. Fix anything it reports before going on.
3. **Confirm before creating.** A page goes onto a shared wiki and may notify people watching it.
   Unless the user's request already said to go ahead, show a one-line summary
   (path, title, tags, published or draft) and wait for a yes.
4. **Create** the page and report its URL to the user, along with the `Render` line if it's a warning.

## Usage

```bash
s=~/.claude/skills/wikijs-page/scripts/new_wikijs_page.py

# site info, and your permissions at a path
python3 "$s" --info --path guides/vpn-setup

# check only
python3 "$s" --path guides/vpn-setup --title "VPN setup" --content-file /tmp/vpn.md --dry-run

# create
python3 "$s" --path guides/vpn-setup --title "VPN setup" --content-file /tmp/vpn.md \
  --description "Connecting to the office VPN with IKEv2" --tags vpn,ikev2
```

On Windows the same, with `python` and `$s = "$HOME/.claude/skills/wikijs-page/scripts/new_wikijs_page.py"`.

| Option | Notes |
|---|---|
| `--path` | Required. Page path, without a leading slash |
| `--title` | Required |
| `--content` / `--content-file` | Required. Markdown source (UTF-8 file) |
| `--description` | Short summary shown under the title |
| `--tags` | Comma-separated, may be repeated. Needs the `write:tags` page permission |
| `--locale` | Defaults to the site's primary locale |
| `--editor` | Default `markdown` |
| `--draft` | Create as a draft instead of published |
| `--site` | Site id or hostname. Default: the site that answers on `WIKIJS_URL`'s hostname |
| `--render-file` | HTML render to send with the page (see Rendering) |
| `--no-local-render` | Don't send a python-markdown render |
| `--dry-run` | Check site, permissions and path; create nothing |
| `--info` | Print the site (and with `--path`, your permissions there) and exit |

## Errors

- **401**: the token is missing, wrong, expired or revoked, or it's a system API key. Use a personal
  access token.
- **403**: the token lacks the `pages:write` scope, or the user's group page rules don't allow writing
  (or tagging) at that path. `--info --path <path>` shows what the user may do there.
- **409**: a page already exists at that path (in that locale).
- **400** `pageInvalidPath`: the path has characters other than letters, numbers, hyphens and slashes.
- **404** on the site: `--site` is wrong, or `WIKIJS_URL` isn't a hostname the wiki serves.

API reference: `<WIKIJS_URL>/_api` on the server (Swagger UI), or the source at
https://github.com/requarks/wiki (`backend/api/pages.ts`).

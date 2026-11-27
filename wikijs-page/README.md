# wikijs-page

A [Claude Code](https://claude.com/claude-code) skill that creates pages in a self-hosted
[Wiki.js](https://js.wiki/) **3.x** wiki through its REST API. Built and checked against the
Wiki.js **3.5.0** source.

Ask Claude something like *"write up the SymmetricDS initial-load fix as a wiki page under
guides/sds"*, or run `/wikijs-page <path> <title> [content...]`. Claude writes the markdown, checks
the path and your permissions with a dry run, shows a one-line summary, and after you confirm it
creates the page and gives you its URL.

Works on **Linux, macOS and Windows**: the helper is a single Python 3.8+ script that uses only the
standard library.

> Wiki.js 2.x has a different (GraphQL) API. This skill is for 3.x only.

## Files

| File | Purpose |
|---|---|
| `SKILL.md` | The skill definition: frontmatter (name, trigger description, allowed tools) and the instructions Claude follows |
| `scripts/new_wikijs_page.py` | Helper that does the API work: site lookup, permission and path checks, page creation, render request |

## Install

Copy this folder into your Claude Code skills directory:

```bash
# Linux/macOS, personal: available in every project
mkdir -p ~/.claude/skills && cp -r wikijs-page ~/.claude/skills/
```

```powershell
# Windows, personal
Copy-Item -Recurse wikijs-page "$HOME\.claude\skills\"
```

For a project-level install, copy it to `.claude/skills/` in the repo instead and change the script
path in `SKILL.md`. The README is ignored by Claude Code.

Optional, recommended when the server has no Puppeteer extension (see [Rendering](#rendering)):

```bash
pip install markdown
```

## Configuration

| Variable | Value |
|---|---|
| `WIKIJS_URL` | Base URL, e.g. `https://wiki.example.com` |
| `WIKIJS_TOKEN` | Personal access token with the **`pages:write`** scope |

### Getting a token

In Wiki.js, open your profile menu → **Personal Access Tokens** → create one with the
`pages:write` scope. Personal access tokens must be enabled by an admin under
**Administration → Authentication**.

Use a **personal** token, not a system API key from Administration → API Keys. Wiki.js records a user
as the author of every page, and a system key acts for groups rather than a user, so page saves
with one fail with 401. The token acts as you: your groups and page rules decide where it may write.

Set the variables yourself, outside the chat, so the token never appears in the conversation:

```bash
# Linux/macOS: ~/.bashrc, ~/.zshrc or ~/.profile
export WIKIJS_URL="https://wiki.example.com"
export WIKIJS_TOKEN="<token>"
```

```powershell
# Windows
[Environment]::SetEnvironmentVariable("WIKIJS_URL", "https://wiki.example.com", "User")
[Environment]::SetEnvironmentVariable("WIKIJS_TOKEN", "<token>", "User")
```

Restart the terminal and Claude Code afterwards.

## How it works

All calls go to `<WIKIJS_URL>/_api` with `Authorization: Bearer <token>`.

1. **Site**: `GET /_api/sites/current` finds the site that answers on the URL's hostname
   (Wiki.js 3 can host several sites). `--site` takes a site id or hostname instead.
2. **Dry run** (`--dry-run`):
   - `POST /_api/sites/{site}/pages/userPermissions` returns what you may do at the path
     (`write:pages`, and `write:tags` when tags are given).
   - `GET /_api/sites/{site}/pages/{hash}` checks that the path is free. The hash is Wiki.js's
     cyrb53 path hash, ported to Python and checked against the original JavaScript.
3. **Create**: `POST /_api/sites/{site}/pages` with `path`, `title`, `editor` (`markdown`),
   `content`, `publishState`, and optionally `description`, `tags`, `locale` and `render`.
4. **Render**: `POST /_api/sites/{site}/pages/{id}/render` queues a server-side render.

### Rendering

Wiki.js 3 turns markdown into HTML **in the browser editor**, not on the server. A page created through
the API is blank to readers, and missing from search, until something renders it. The script covers
this in two layers:

| Server has Puppeteer extension | Local HTML sent | Result |
|---|---|---|
| yes | either | Server renders the page within seconds; identical to the editor's output |
| no | yes (`pip install markdown`, or `--render-file`) | Page shows the locally rendered HTML. Close to, but not exactly, the editor's output (no Wiki.js-specific blocks, diagrams or math). Open the page in the editor and save it once to get the exact render |
| no | no | Page is created but **blank**; the script prints a warning |

When `markdown` isn't installed, the skill tells Claude to write the HTML itself and pass it with
`--render-file`, so you don't get a blank page.

The server sanitizes whatever HTML is sent against your permissions, so `render` can't be used to
inject scripts.

## Using the script directly

```bash
s=./scripts/new_wikijs_page.py

python3 "$s" --info --path guides/vpn-setup
python3 "$s" --path guides/vpn-setup --title "VPN setup" --content-file vpn.md --dry-run
python3 "$s" --path guides/vpn-setup --title "VPN setup" --content-file vpn.md \
  --description "Connecting with IKEv2" --tags vpn,ikev2 --draft
```

| Option | Notes |
|---|---|
| `--path` | Required. Lowercased when stored; spaces and underscores become hyphens |
| `--title` | Required |
| `--content` / `--content-file` | Required. Markdown source (UTF-8 file) |
| `--description` | Short summary shown under the title |
| `--tags` | Comma-separated, may be repeated. Needs the `write:tags` page permission |
| `--locale` | Defaults to the site's primary locale |
| `--editor` | Default `markdown` |
| `--draft` | Draft instead of published |
| `--site` | Site id or hostname; default `current` |
| `--render-file` | HTML render to send with the page |
| `--no-local-render` | Don't send a python-markdown render |
| `--dry-run` | Check only, create nothing |
| `--info` | Print site info (and permissions at `--path`) and exit |

## Safety behaviour built into the skill

- Claude runs a dry run, then confirms with a one-line summary before creating.
- Claude never asks for the token in chat, never echoes it, and never passes it on a command line.
  The script reads it from the environment and sends it only in the `Authorization` header.
- Claude writes content only from what you gave it or what's in the conversation or repo, and keeps
  any HTML render saying exactly what the markdown says.

## Troubleshooting

| Error | Cause |
|---|---|
| 401 | Token wrong, expired or revoked, or it's a system API key. Use a personal access token |
| 403 | Token lacks `pages:write`, or your group page rules don't allow writing (or tagging) at that path. Run `--info --path <path>` |
| 409 | A page already exists at that path in that locale |
| 400 `pageInvalidPath` | Path contains characters other than letters, numbers, hyphens and slashes |
| 404 on the site | Wrong `--site`, or `WIKIJS_URL`'s hostname isn't one the wiki serves |
| `WARNING: NOT rendered` | No Puppeteer on the server and no HTML sent. `pip install markdown`, pass `--render-file`, or open the page in the editor and save it |

## References

- Your server's API docs (Swagger UI): `<WIKIJS_URL>/_api`
- Wiki.js source, `backend/api/pages.ts`: https://github.com/requarks/wiki/blob/3.5.0/backend/api/pages.ts
- Claude Code skills: https://docs.claude.com/en/docs/claude-code/skills

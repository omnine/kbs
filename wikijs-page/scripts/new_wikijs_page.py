#!/usr/bin/env python3
"""Create (or check) a page in a self-hosted Wiki.js 3.x through its REST API (/_api).

Python 3.8+, standard library only. Works on Linux, macOS and Windows.
Optional: `pip install markdown` for a local HTML render when the server has no
Puppeteer extension (see --help and README).

Reads from environment variables:
  WIKIJS_URL    base URL, e.g. https://wiki.example.com
  WIKIJS_TOKEN  personal access token with the pages:write scope
                (Profile -> Personal Access Tokens). A system API key cannot save pages.

Examples:
  new_wikijs_page.py --info
  new_wikijs_page.py --path guides/vpn --title "VPN setup" --content-file vpn.md --dry-run
  new_wikijs_page.py --path guides/vpn --title "VPN setup" --content-file vpn.md --tags vpn,network
"""
import argparse
import json
import os
import re
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request


def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


class ApiError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


class Client:
    def __init__(self, base, token):
        self.base = base.rstrip("/")
        self.headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}

    def call(self, method, path, body=None):
        data = None
        headers = dict(self.headers)
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json; charset=utf-8"
        req = urllib.request.Request(f"{self.base}/_api{path}", data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as resp:
                raw = resp.read().decode("utf-8")
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                msg = json.loads(raw).get("message") or raw
            except ValueError:
                msg = raw
            raise ApiError(e.code, msg)
        except urllib.error.URLError as e:
            die(f"Cannot reach {self.base}: {e.reason}")


def api_die(e, method, path):
    hint = {
        401: " (token missing, wrong, expired or revoked; a system API key cannot save pages, use a personal access token)",
        403: " (the token lacks the pages:write scope, or your groups' page rules don't allow writing at this path)",
    }.get(e.status, "")
    die(f"Wiki.js API error ({method} /_api{path}) HTTP {e.status}: {e.message}{hint}")


def imul(a, b):
    return (a * b) & 0xFFFFFFFF


def path_hash(s, seed=0):
    """Port of Wiki.js generatePathHash (cyrb53 over UTF-16 code units)."""
    h1 = 0xDEADBEEF ^ seed
    h2 = 0x41C6CE57 ^ seed
    units = s.encode("utf-16-le")
    for i in range(0, len(units), 2):
        ch = units[i] | (units[i + 1] << 8)
        h1 = imul(h1 ^ ch, 2654435761)
        h2 = imul(h2 ^ ch, 1597334677)
    h1 = imul(h1 ^ (h1 >> 16), 2246822507)
    h1 ^= imul(h2 ^ (h2 >> 13), 3266489909)
    h2 = imul(h2 ^ (h2 >> 16), 2246822507)
    h2 ^= imul(h1 ^ (h1 >> 13), 3266489909)
    return format(4294967296 * (2097151 & h2) + h1, "x")


def normalize_path(p):
    """How Wiki.js stores a new page path: no outer slashes, lowercase, spaces/underscores -> hyphens."""
    p = p.strip().strip("/")
    p = re.sub(r"[\s_]+", "-", p).lower()
    return unicodedata.normalize("NFC", p)


def local_render(markdown_text):
    """HTML from python-markdown if it is installed, else None."""
    try:
        import markdown  # type: ignore
    except ImportError:
        return None
    return markdown.markdown(markdown_text, extensions=["extra", "sane_lists", "toc"])


def get_site(c, site):
    path = f"/sites/{urllib.parse.quote(site, safe='')}"
    try:
        return c.call("GET", path)
    except ApiError as e:
        api_die(e, "GET", path)


def page_exists(c, site_id, path, locale):
    q = f"?locale={urllib.parse.quote(locale)}" if locale else ""
    p = f"/sites/{site_id}/pages/{path_hash(path or 'home')}{q}"
    try:
        c.call("GET", p)
        return True
    except ApiError as e:
        if e.status == 404:
            return False
        api_die(e, "GET", p)


def permissions_at(c, site_id, path, locale):
    body = {"path": path}
    if locale:
        body["locale"] = locale
    p = f"/sites/{site_id}/pages/userPermissions"
    try:
        return c.call("POST", p, body)
    except ApiError as e:
        api_die(e, "POST", p)


def main():
    ap = argparse.ArgumentParser(description="Create a page in Wiki.js 3.x via its REST API.")
    ap.add_argument("--path", help="page path, e.g. guides/vpn-setup (no leading slash needed)")
    ap.add_argument("--title")
    ap.add_argument("--content", help="page source (markdown by default)")
    ap.add_argument("--content-file", help="read the page source from this file (UTF-8)")
    ap.add_argument("--description", help="short summary shown under the title")
    ap.add_argument("--tags", action="append", default=[],
                    help="comma-separated; may be repeated. Needs the write:tags page permission")
    ap.add_argument("--locale", help="defaults to the site's primary locale")
    ap.add_argument("--editor", default="markdown", help="default markdown")
    ap.add_argument("--draft", action="store_true", help="create as a draft instead of published")
    ap.add_argument("--site", default="current",
                    help="site id or hostname; default: the site that answers on WIKIJS_URL's hostname")
    ap.add_argument("--render-file",
                    help="HTML render of the content to send (used when the server has no Puppeteer)")
    ap.add_argument("--no-local-render", action="store_true",
                    help="don't send a python-markdown render; rely on the server's renderer only")
    ap.add_argument("--dry-run", action="store_true",
                    help="check site, permissions and path; create nothing")
    ap.add_argument("--info", action="store_true",
                    help="print the site and (with --path) your permissions there, then exit")
    a = ap.parse_args()

    base = os.environ.get("WIKIJS_URL")
    token = os.environ.get("WIKIJS_TOKEN")
    if not base or not token:
        die("Set WIKIJS_URL and WIKIJS_TOKEN environment variables first.")
    c = Client(base, token)

    site = get_site(c, a.site)
    site_id = site["id"]

    if a.info:
        print(f"Site     : {site.get('title', '')} ({site_id})")
        print(f"Hostname : {site.get('hostname', '')}")
        loc = site.get("locales") or {}
        if isinstance(loc, dict) and loc:
            print(f"Locales  : primary={loc.get('primary', '')} active={','.join(loc.get('active', []) or [])}")
        if a.path:
            path = normalize_path(a.path)
            perms = permissions_at(c, site_id, path, a.locale)
            print(f"Path     : {path} ({'exists' if page_exists(c, site_id, path, a.locale) else 'free'})")
            print(f"You may  : {', '.join(perms) if perms else '(nothing)'}")
        return

    if not a.path or not a.title:
        die("--path and --title are required.")
    content = a.content
    if a.content_file:
        with open(a.content_file, encoding="utf-8") as f:
            content = f.read()
    if not content or not content.strip():
        die("Page content is empty: pass --content or --content-file.")
    tags = [t.strip() for group in a.tags for t in group.split(",") if t.strip()]
    path = normalize_path(a.path)

    if a.dry_run:
        problems = []
        perms = permissions_at(c, site_id, path, a.locale)
        if "write:pages" not in perms:
            problems.append("you don't have write:pages at this path")
        if tags and "write:tags" not in perms:
            problems.append("you don't have write:tags at this path, so tags would be refused")
        if page_exists(c, site_id, path, a.locale):
            problems.append("a page already exists at this path")
        print(f"Site     : {site.get('title', '')} ({site_id})")
        print(f"Path     : {path}")
        print(f"Title    : {a.title}")
        print(f"Tags     : {', '.join(tags) or '-'}")
        print(f"State    : {'draft' if a.draft else 'published'}")
        if problems:
            print("NOT READY:")
            for p in problems:
                print(f"  - {p}")
            sys.exit(1)
        print("READY - nothing created.")
        return

    body = {
        "path": path,
        "title": a.title,
        "editor": a.editor,
        "content": content,
        "publishState": "draft" if a.draft else "published",
    }
    if a.description:
        body["description"] = a.description
    if a.locale:
        body["locale"] = a.locale
    if tags:
        body["tags"] = tags
    rendered_locally = False
    if a.render_file:
        with open(a.render_file, encoding="utf-8") as f:
            body["render"] = f.read()
        rendered_locally = True
    elif a.editor == "markdown" and not a.no_local_render:
        html = local_render(content)
        if html is not None:
            body["render"] = html
            rendered_locally = True

    create_path = f"/sites/{site_id}/pages"
    try:
        res = c.call("POST", create_path, body)
    except ApiError as e:
        api_die(e, "POST", create_path)
    page = res.get("page") or {}
    page_id = page.get("id")

    # The markdown pipeline lives in the browser. Ask the server to render the page from its
    # source in its headless browser (Puppeteer extension), so it matches what the editor makes.
    render_path = f"/sites/{site_id}/pages/{page_id}/render"
    try:
        c.call("POST", render_path)
        render_note = "queued on the server (appears within seconds)"
    except ApiError as e:
        if e.status == 503 and rendered_locally:
            render_note = ("used the HTML render sent with the page (server has no Puppeteer). "
                           "Open the page in the editor and save once to get the exact Wiki.js render.")
        elif e.status == 503:
            render_note = ("WARNING: NOT rendered. The server has no Puppeteer extension and no HTML render "
                           "was sent, so readers see an empty page until someone opens it in the editor and "
                           "saves. Fix: `pip install markdown`, pass --render-file, or install Puppeteer on "
                           "the server.")
        else:
            render_note = f"WARNING: render request failed (HTTP {e.status}: {e.message})"

    locale = page.get("locale") or a.locale or ""
    locs = site.get("locales") if isinstance(site.get("locales"), dict) else {}
    url_path = page.get("path", path)
    prefixed = locale and (locs.get("forcePrefix") or locale != locs.get("primary"))
    url = f"{c.base}/{locale}/{url_path}" if prefixed else f"{c.base}/{url_path}"
    print(f"Id       : {page_id}")
    print(f"Title    : {page.get('title', a.title)}")
    print(f"Path     : {url_path}")
    print(f"Locale   : {locale}")
    print(f"State    : {page.get('publishState', body['publishState'])}")
    print(f"Render   : {render_note}")
    print(f"Url      : {url}")


if __name__ == "__main__":
    main()

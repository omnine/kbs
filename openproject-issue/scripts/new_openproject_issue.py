#!/usr/bin/env python3
"""Create (or validate) an OpenProject work package via API v3.

Cross-platform counterpart of New-OpenProjectIssue.ps1 (Linux, macOS, Windows).
Python 3.8+, standard library only.

Reads the server URL and API token from environment variables:
  OPENPROJECT_URL      e.g. https://openproject.example.com
  OPENPROJECT_API_KEY  personal API token (My account -> Access tokens -> API)

Type, priority, status and assignee are given by NAME and resolved to IDs.

Examples:
  new_openproject_issue.py --project my-project --list
  new_openproject_issue.py --project my-project --subject "Login 500" --type Bug --priority High
"""
import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


def die(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


class Client:
    def __init__(self, base, token):
        self.base = base.rstrip("/")
        auth = base64.b64encode(f"apikey:{token}".encode()).decode()
        self.headers = {"Authorization": f"Basic {auth}", "Accept": "application/hal+json"}

    def call(self, method, path, body=None):
        data = None
        headers = dict(self.headers)
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json; charset=utf-8"
        req = urllib.request.Request(self.base + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                err = json.loads(raw)
                details = [err.get("message", "")]
                details += [x.get("message", "") for x in err.get("_embedded", {}).get("errors", [])]
                msg = "; ".join(d for d in details if d)
            except ValueError:
                msg = raw
            die(f"OpenProject API error ({method} {path}) HTTP {e.code}: {msg}")
        except urllib.error.URLError as e:
            die(f"Cannot reach {self.base}: {e.reason}")

    def elements(self, path):
        return self.call("GET", path).get("_embedded", {}).get("elements", [])


def resolve(elements, name, kind, fields=("name",)):
    """Exact case-insensitive match first, otherwise a unique partial match."""
    n = name.lower()

    def vals(e):
        return [str(e.get(f) or "").lower() for f in fields]

    exact = [e for e in elements if n in vals(e)]
    if exact:
        return exact[0]
    partial = [e for e in elements if any(n in v for v in vals(e))]
    if len(partial) == 1:
        return partial[0]
    if partial:
        die(f"{kind} '{name}' is ambiguous. Matches: {', '.join(e['name'] for e in partial)}")
    die(f"{kind} '{name}' not found. Available: {', '.join(e['name'] for e in elements)}")


def main():
    p = argparse.ArgumentParser(description="Create an OpenProject work package via API v3.")
    p.add_argument("--project", required=True, help="project identifier or numeric id")
    p.add_argument("--subject")
    p.add_argument("--type", default="Task")
    p.add_argument("--description", help="markdown")
    p.add_argument("--description-file", help="path to a markdown file")
    p.add_argument("--priority")
    p.add_argument("--status")
    p.add_argument("--assignee", help="name, login or email (partial match ok)")
    p.add_argument("--start-date", help="yyyy-MM-dd")
    p.add_argument("--due-date", help="yyyy-MM-dd")
    p.add_argument("--estimated-hours")
    p.add_argument("--parent", type=int, help="parent work package id")
    p.add_argument("--no-notify", action="store_true")
    p.add_argument("--dry-run", action="store_true", help="validate via the /form endpoint, create nothing")
    p.add_argument("--list", action="store_true", help="list types, priorities, statuses, assignees and exit")
    a = p.parse_args()

    base = os.environ.get("OPENPROJECT_URL")
    token = os.environ.get("OPENPROJECT_API_KEY")
    if not base or not token:
        die("Set OPENPROJECT_URL and OPENPROJECT_API_KEY environment variables first.")
    c = Client(base, token)
    proj = urllib.parse.quote(a.project, safe="")

    if a.list:
        print(f"== Types enabled in '{a.project}' ==")
        for e in c.elements(f"/api/v3/projects/{proj}/types"):
            print(f"  {e['id']}\t{e['name']}")
        print("== Priorities ==")
        for e in c.elements("/api/v3/priorities"):
            print(f"  {e['id']}\t{e['name']}")
        print("== Statuses ==")
        for e in c.elements("/api/v3/statuses"):
            print(f"  {e['id']}\t{e['name']}")
        print("== Available assignees ==")
        for e in c.elements(f"/api/v3/projects/{proj}/available_assignees"):
            print(f"  {e['id']}\t{e['name']}\t{e.get('login', '')}")
        return

    if not a.subject:
        die("--subject is required.")

    links = {}
    t = resolve(c.elements(f"/api/v3/projects/{proj}/types"), a.type, "Type")
    links["type"] = {"href": t["_links"]["self"]["href"]}
    if a.priority:
        e = resolve(c.elements("/api/v3/priorities"), a.priority, "Priority")
        links["priority"] = {"href": e["_links"]["self"]["href"]}
    if a.status:
        e = resolve(c.elements("/api/v3/statuses"), a.status, "Status")
        links["status"] = {"href": e["_links"]["self"]["href"]}
    if a.assignee:
        e = resolve(c.elements(f"/api/v3/projects/{proj}/available_assignees"),
                    a.assignee, "Assignee", ("name", "login", "email"))
        links["assignee"] = {"href": e["_links"]["self"]["href"]}
    if a.parent:
        links["parent"] = {"href": f"/api/v3/work_packages/{a.parent}"}

    body = {"subject": a.subject, "_links": links}
    desc = a.description
    if a.description_file:
        with open(a.description_file, encoding="utf-8") as f:
            desc = f.read()
    if desc:
        body["description"] = {"format": "markdown", "raw": desc}
    if a.start_date:
        body["startDate"] = a.start_date
    if a.due_date:
        body["dueDate"] = a.due_date
    if a.estimated_hours:
        body["estimatedTime"] = f"PT{a.estimated_hours}H"

    if a.dry_run:
        form = c.call("POST", f"/api/v3/projects/{proj}/work_packages/form", body)
        errors = form.get("_embedded", {}).get("validationErrors") or {}
        if errors:
            print("VALIDATION FAILED:")
            for k, v in errors.items():
                print(f"  {k}: {v.get('message', v)}")
            sys.exit(1)
        print("VALID - nothing created. Payload:")
        print(json.dumps(body, indent=2, ensure_ascii=False))
        return

    path = f"/api/v3/projects/{proj}/work_packages"
    if a.no_notify:
        path += "?notify=false"
    wp = c.call("POST", path, body)
    l = wp.get("_links", {})
    title = lambda k: (l.get(k) or {}).get("title") or ""
    print(f"Id       : {wp['id']}")
    print(f"Subject  : {wp.get('subject', '')}")
    print(f"Type     : {title('type')}")
    print(f"Status   : {title('status')}")
    print(f"Priority : {title('priority')}")
    print(f"Assignee : {title('assignee')}")
    print(f"Url      : {c.base}/work_packages/{wp['id']}")


if __name__ == "__main__":
    main()

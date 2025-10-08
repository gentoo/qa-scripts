#!/usr/bin/env python
# SPDX-License-Identifier: BSD-2-Clause
# SPDX-FileCopyrightText: 2025 Arthur Zamarin <arthurzam@gentoo.org>


import json
import os
import socket
import sys
import time
from argparse import ArgumentParser
from dataclasses import dataclass
from typing import Any, Generator, Iterable, Literal

import requests

GITHUB_API = os.environ.get("GITHUB_API_URL", "https://api.github.com")


@dataclass
class Workflow:
    repo: str
    state: Literal[
        "active", "disabled_inactivity", "disabled_manually", "n/a", "none", "unknown"
    ]


def headers(token: str) -> dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "workflow-audit-script",
    }


def handle_rate_limit(resp: requests.Response) -> bool:
    """
    If rate-limited, sleep until reset and return True (caller should retry).
    Otherwise return False.
    """
    if resp.status_code == 403:
        # GitHub returns 403 for rate limit with appropriate headers
        remaining = resp.headers.get("X-RateLimit-Remaining")
        reset_at = resp.headers.get("X-RateLimit-Reset")
        if remaining == "0" and reset_at:
            reset = int(reset_at)
            wait = max(0, reset - int(time.time()) + 1)
            print(f"[rate-limit] Sleeping {wait}s until reset...", file=sys.stderr)
            time.sleep(wait)
            return True
    return False


def gh_get(
    url: str, token: str, params: dict[str, Any] | None = None
) -> requests.Response:
    """
    GET with basic rate-limit handling/retry.
    """
    s = requests.Session()
    while True:
        r = s.get(url, headers=headers(token), params=params)
        if handle_rate_limit(r):
            continue
        return r


def paginate(
    url: str, token: str, params: dict[str, Any] | None = None
) -> Generator[Any, None, None]:
    """
    Generic pagination using Link headers.
    Yields the JSON items for endpoints that return an array (or wrap items in a keyed array).
    This helper expects the caller to manage extracting items.
    """
    s = requests.Session()
    page_url = url
    page_params = params or {}

    while page_url:
        r = s.get(page_url, headers=headers(token), params=page_params)
        if handle_rate_limit(r):
            continue
        if r.status_code == 404:
            raise SystemExit(f"Not found or no access: {page_url}")
        if r.status_code == 401:
            raise SystemExit("Unauthorized. Check GITHUB_TOKEN scopes.")
        r.raise_for_status()

        yield r.json()

        # Parse next from Link header
        next_url = None
        if "Link" in r.headers:
            for link in r.headers["Link"].split(","):
                parts = link.split(";")
                if len(parts) >= 2 and 'rel="next"' in parts[1]:
                    next_url = parts[0].strip()[1:-1]
                    break
        page_url = next_url
        page_params = None  # only on first request


def list_org_repos(org: str, token: str) -> Iterable[dict[str, Any]]:
    """
    Yields repo JSON objects for all repos in the org, respecting filters.
    """
    url = f"{GITHUB_API}/orgs/{org}/repos"
    params = {"per_page": 100, "type": "all", "sort": "full_name", "direction": "asc"}
    for resp in paginate(url, token, params=params):
        yield from resp


def list_repo_workflows(owner: str, repo: str, token: str) -> Iterable[dict[str, Any]]:
    """
    Yields workflow objects for a given repo.
    Each workflow has fields like: id, name, path, state (active/disabled_*), etc.
    """
    url = f"{GITHUB_API}/repos/{owner}/{repo}/actions/workflows"
    params = {"per_page": 200}
    for resp in paginate(url, token, params=params):
        # The list endpoint returns { total_count, workflows: [ ... ] }
        yield from resp.get("workflows", [])


def normalize(s: str | None) -> str:
    return (s or "").strip().lower()


def matches_workflow(wf: dict[str, Any], wf_file_lc: str) -> bool:
    """
    Match by file path/basename (case-insensitive).
    """
    path = normalize(wf.get("path"))
    base = os.path.basename(path)

    return path == wf_file_lc or normalize(base) == wf_file_lc


def audit_workflow(
    org: str,
    token: str,
    wf_file: str,
) -> Iterable[Workflow]:
    """
    Returns rows with: full_name, workflow_name, workflow_path, state.
    If workflow not found in a repo: state = "n/a"
    If no workflows at all: state = "none"
    """
    wf_file_lc = normalize(wf_file)

    for repo in list_org_repos(org, token):
        owner = repo["owner"]["login"]
        name = repo["name"]
        full = repo["full_name"]

        try:
            for wf in list_repo_workflows(owner, name, token):
                if matches_workflow(wf, wf_file_lc):
                    yield Workflow(repo=full, state=wf.get("state", "unknown"))
                    break
        except SystemExit:
            raise
        except Exception as e:
            # If a repo errors (e.g., permissions), note unknown and continue
            print(f"[error] {full}: {e}", file=sys.stderr)


def main():
    parser = ArgumentParser(
        description="Audit GitHub Actions workflow states in an org."
    )
    parser.add_argument("org", help="GitHub organization name")
    parser.add_argument(
        "--token-file",
        help="File containing GitHub token",
        metavar="FILE",
        required=True,
    )
    parser.add_argument("--irc", help="Channel to send IRC message to")
    parser.add_argument(
        "--pings", help="Usernames to ping in IRC message", nargs="*", metavar="USER"
    )
    args = parser.parse_args()

    with open(args.token_file) as f:
        token = f.read().strip()
        if not token:
            sys.exit(f"Token file {args.token_file} is empty.")

    try:
        rows = audit_workflow(
            org=args.org,
            token=token,
            wf_file=".github/workflows/mirror.yml",
        )
    except SystemExit:
        raise
    except Exception as e:
        sys.exit(f"Error: {e}")

    pings = ""
    if args.pings:
        pings = ": ".join(args.pings) + ": "

    message = ""
    if disabled := [w for w in rows if w.state == "disabled_inactivity"]:
        message = f"{pings}Found {len(disabled)} repos with the workflow DISABLED due to inactivity."
        for workflow in disabled:
            message += f"\n  - {workflow.repo} (https://github.com/{workflow.repo}/actions/workflows/mirror.yml)"

    if not args.irc:
        print(message or "No disabled workflows found.")
    elif message: # send over irker, if not empty
        irc_host = os.environ.get("IRKER_HOST", "localhost")
        irc_port = int(os.environ.get("IRKER_PORT", "6659"))
        try:
            to = f"ircs://irc.libera.chat:6697/{args.irc}"
            with socket.create_connection((irc_host, irc_port), timeout=10) as s:
                data = json.dumps({"to": to, "privmsg": message}).encode("utf8")
                s.sendall(data)
        except Exception as e:
            sys.exit(f"Error sending to irker at {irc_host}:{irc_port}: {e}")


if __name__ == "__main__":
    main()

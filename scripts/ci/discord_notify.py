#!/usr/bin/env python3
"""
Send a short English Discord webhook notification for Witch releases.

One compact embed: release title, a few changelog bullets, download link.
No contributor table, no checksums, no artifact manifest — the GitHub
Release has the details.

Stdlib only (urllib). No third-party deps.

Usage:
  python3 scripts/ci/discord_notify.py \
    --webhook-url "$DISCORD_WEBHOOK_URL" \
    --version 0.0.2-beta.429536e-20260926-b42 \
    --channel pre-release --branch beta \
    --repo Witch-Launcher/Witch_launcher \
    --sha <full-sha> --pusher Ynnyny \
    --status success --run-url https://... \
    --release-url https://github.com/.../releases/tag/pre-release

Edit CHANGES_LIMIT / SUBJECT_MAX / STATUS_TEXT below to change the format.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone

CHANGES_LIMIT = 8
SUBJECT_MAX = 110
STATUS_TEXT = {
    "success": "New build published",
    "cancelled": "Build cancelled — previous build still live",
}
FAILED_TEXT = "Build failed — no new build published"
PREFIX_RE = re.compile(r"^(\w+)(\([^)]*\))?!?:\s*")


def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode("utf-8", "replace").strip()
    except Exception:
        return ""


def collect_commits(before, sha, n=CHANGES_LIMIT):
    fmt = "%s%x1e"
    rng = None
    if before and re.fullmatch(r"[0-9a-f]{4,40}", before or "") and before != sha:
        try:
            subprocess.check_output(["git", "cat-file", "-e", before], stderr=subprocess.DEVNULL)
            rng = f"{before}..{sha}"
        except subprocess.CalledProcessError:
            rng = None
    raw = run(["git", "log", f"--pretty=format:{fmt}", rng] if rng else ["git", "log", f"--pretty=format:{fmt}", f"-{n}"])
    items = []
    for rec in raw.split("\x1e"):
        subject = re.sub(r"\s+", " ", rec.strip())
        if not subject:
            continue
        subject = PREFIX_RE.sub("", subject).strip() or subject
        if len(subject) > SUBJECT_MAX:
            subject = subject[: SUBJECT_MAX - 1].rstrip() + "…"
        items.append(subject)
    return items


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--webhook-url", default=os.environ.get("DISCORD_WEBHOOK_URL", ""))
    ap.add_argument("--version", default="0.0.2")
    ap.add_argument("--channel", default="pre-release")
    ap.add_argument("--branch", default="beta")
    ap.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", ""))
    ap.add_argument("--sha", default=os.environ.get("GITHUB_SHA", ""))
    ap.add_argument("--before", default=os.environ.get("GITHUB_EVENT_BEFORE", ""))
    ap.add_argument("--pusher", default="")
    ap.add_argument("--status", default="success")
    ap.add_argument("--run-url", default="")
    ap.add_argument("--release-url", default="")
    ap.add_argument("--notes-file", default="")  # accepted for compatibility
    ap.add_argument("--artifacts-dir", default="")  # accepted for compatibility
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not args.webhook_url:
        print("DISCORD_WEBHOOK_URL is empty — skipping Discord notification (not a failure).")
        return 0

    ok = args.status == "success"
    color = 0x2ECC71 if ok else (0xF1C40F if args.status == "cancelled" else 0xE74C3C)
    short_sha = (args.sha or "")[:7]
    title = str(args.version)[:256]

    lines = []
    if ok:
        lines.append(f"`{args.branch}` · `{short_sha}`")
        commits = collect_commits(args.before, args.sha or "HEAD")
        if commits:
            lines.append("")
            lines.extend(f"• {c}" for c in commits)
            lines.append("")
        if args.release_url:
            lines.append(f"**[Download build]({args.release_url})**")
    elif args.status == "cancelled":
        lines.append(STATUS_TEXT["cancelled"])
    else:
        lines.append(FAILED_TEXT)
        if args.run_url:
            lines.append(f"[Workflow log]({args.run_url})")
    description = "\n".join(lines)[:4000] or " "

    footer = (args.repo or "Witch Release Bot") + " · automated"

    payload = {
        "username": "Witch Release Bot",
        "allowed_mentions": {"parse": []},
        "embeds": [{
            "title": title,
            "description": description,
            "color": color,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "footer": {"text": footer[:2048]},
        }],
    }

    data = json.dumps(payload).encode("utf-8")
    if args.dry_run:
        print(json.dumps(payload, indent=2)[:4000])
        return 0

    req = urllib.request.Request(
        args.webhook_url,
        data=data,
        headers={"Content-Type": "application/json", "User-Agent": "Witch-Release-Bot/1.0"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            print(f"Discord webhook sent: HTTP {resp.status}")
            return 0
    except Exception as e:
        print(f"Discord webhook failed (non-blocking): {e}", file=sys.stderr)
        return 0


if __name__ == "__main__":
    sys.exit(main())

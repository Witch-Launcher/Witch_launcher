#!/usr/bin/env python3
"""
Send a verbose English Discord webhook notification for Witch releases.

- English only, no @mentions (allowed_mentions.parse = []).
- Verbose is allowed: top commits + contributors + artifacts + checksums.
- Respects Discord embed limits: description <= 4096, field value <= 1024,
  max 25 fields. Long content is truncated with a link to GitHub Release.

Stdlib only (urllib). No third-party deps.

Usage:
  python3 scripts/ci/discord_notify.py \
    --webhook-url "$DISCORD_WEBHOOK_URL" \
    --version 0.0.2-beta.429536e-20260926-b42 \
    --channel pre-release --branch beta \
    --repo Witch-Launcher/Witch_launcher \
    --sha <full-sha> --pusher Ynnyny \
    --status success --run-url https://... \
    --release-url https://github.com/.../releases/tag/pre-release \
    --notes-file RELEASE_NOTES.md --artifacts-dir ./downloaded
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone


def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode("utf-8", "replace").strip()
    except Exception:
        return ""


def sha256_short(path):
    h = hashlib.sha256()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(4 * 1024 * 1024), b""):
                h.update(chunk)
        return h.hexdigest()
    except OSError:
        return "unavailable"


def collect_artifacts(d):
    out = []
    if not d or not os.path.isdir(d):
        return out
    for root, _, files in os.walk(d):
        for fn in sorted(files):
            if not fn.endswith((".ipa", ".tipa", ".zip")):
                continue
            fp = os.path.join(root, fn)
            try:
                size = os.path.getsize(fp)
            except OSError:
                continue
            out.append({"file": fn, "mb": size / 1024 / 1024, "sha": sha256_short(fp)})
    return out


def collect_commits(before, sha, n=8):
    fmt = "%h%x1f%an%x1f%s%x1e"
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
        rec = rec.strip()
        if not rec:
            continue
        p = rec.split("\x1f")
        if len(p) >= 3:
            items.append({"short": p[0], "author": p[1], "subject": p[2][:150]})
    return items[:n]


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
    ap.add_argument("--notes-file", default="")
    ap.add_argument("--artifacts-dir", default="")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not args.webhook_url:
        print("DISCORD_WEBHOOK_URL is empty — skipping Discord notification (not a failure).")
        return 0

    commits = collect_commits(args.before, args.sha or "HEAD")
    arts = collect_artifacts(args.artifacts_dir)
    short_sha = (args.sha or "")[:7]
    ok = args.status == "success"
    color = 0x2ECC71 if ok else (0xF1C40F if args.status == "cancelled" else 0xE74C3C)
    state = "Build succeeded" if ok else ("Build cancelled" if args.status == "cancelled" else "Build failed")

    title = f"Witch v{args.version} — {args.channel} ({state})"

    desc_lines = [f"Branch `{args.branch}` @ `{short_sha}` — {len(commits)} recent commits shown."]
    for c in commits:
        desc_lines.append(f"• `{c['short']}` {c['subject']} — {c['author']}")
    if args.before and args.sha:
        desc_lines.append("")
        desc_lines.append(f"Full diff: https://github.com/{args.repo}/compare/{(args.before or '')[:7]}...{short_sha}")
    description = "\n".join(desc_lines)[:4000]

    fields = [
        {"name": "Version", "value": f"`{args.version}`"[:1024], "inline": True},
        {"name": "Branch", "value": f"`{args.branch}`"[:1024], "inline": True},
        {"name": "Commit", "value": f"[`{short_sha}`](https://github.com/{args.repo}/commit/{args.sha})"[:1024], "inline": True},
    ]
    if args.pusher:
        fields.append({"name": "Pushed by", "value": args.pusher[:1024], "inline": True})
    if commits:
        authors = {}
        for c in commits:
            authors[c["author"]] = authors.get(c["author"], 0) + 1
        top = ", ".join(f"{k} ({v})" for k, v in sorted(authors.items(), key=lambda x: -x[1])[:6])
        fields.append({"name": "Fixed by (top authors)", "value": top[:1024], "inline": False})
    if arts and ok:
        dl = "\n".join(f"`{a['file']}` — {a['mb']:.0f} MB" for a in arts[:6])[:1024]
        fields.append({"name": f"Artifacts ({len(arts)})", "value": dl or "See release page", "inline": False})
        sums = "\n".join(f"`{a['sha'][:12]}…` {a['file']}" for a in arts[:4])[:1024]
        fields.append({"name": "SHA256 (short)", "value": sums or "See checksums.txt", "inline": False})
    elif not ok:
        fields.append({"name": "Artifacts", "value": "No artifacts — build failed. Check the workflow log.", "inline": False})
    if args.release_url:
        fields.append({"name": "GitHub Release", "value": args.release_url[:1024], "inline": False})
    if args.run_url:
        fields.append({"name": "Build log", "value": args.run_url[:1024], "inline": False})
    if args.notes_file and os.path.isfile(args.notes_file):
        try:
            sz = os.path.getsize(args.notes_file)
            fields.append({"name": "Release notes", "value": f"Full verbose notes in GitHub Release body ({sz // 1024} KB). Discord shows a summary only."[:1024], "inline": False})
        except OSError:
            pass

    payload = {
        "username": "Witch Release Bot",
        "allowed_mentions": {"parse": []},  # never tag anyone
        "embeds": [{
            "title": title[:256],
            "description": description,
            "color": color,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "fields": fields[:25],
            "footer": {"text": f"{args.repo} • automated release, verify only • no mentions"},
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
        return 0  # never fail the release because Discord is down


if __name__ == "__main__":
    sys.exit(main())

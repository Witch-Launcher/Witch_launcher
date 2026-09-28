#!/usr/bin/env python3
"""
Generate verbose English release notes for Witch auto-release bot.

Reads commit range (before..sha, fallback: last N commits), groups by
conventional-commit prefix, lists authors (who fixed), file stats, artifacts
table with size + SHA256, install guide, and links.

No third-party deps. Safe to run on macOS + ubuntu-latest runners.

Usage:
  python3 scripts/ci/gen_notes.py \
    --before <sha-or-empty> --sha <sha> --branch beta \
    --repo Witch-Launcher/Witch_launcher --run-url https://... \
    --version 0.0.2-beta.429536e-20260926-b42 \
    --pusher Ynnyny --artifacts-dir ./downloaded \
    --out RELEASE_NOTES.md
"""
import argparse
import hashlib
import os
import re
import subprocess
import sys
from collections import Counter, OrderedDict
from datetime import datetime, timezone


def run(cmd, cwd="."):
    try:
        return subprocess.check_output(cmd, cwd=cwd, stderr=subprocess.DEVNULL).decode("utf-8", "replace").strip()
    except Exception:
        return ""


def get_commits(before, sha, fallback_n=15):
    """Return list of dicts: sha, short, author, email, date, subject, body."""
    rng = None
    if before and sha and before != sha and re.fullmatch(r"[0-9a-f]{4,40}", before or ""):
        # verify `before` exists locally (shallow clones / force-push may lack it)
        exists = run(["git", "cat-file", "-e", before]) == "" or True
        # cat-file -e returns empty on success; check via return code instead
        try:
            subprocess.check_output(["git", "cat-file", "-e", before], stderr=subprocess.DEVNULL)
            rng = f"{before}..{sha}"
        except subprocess.CalledProcessError:
            rng = None
    fmt = "%H%x1f%h%x1f%an%x1f%ae%x1f%ad%x1f%s%x1f%b%x1e"
    if rng:
        raw = run(["git", "log", f"--pretty=format:{fmt}", "--date=short", rng])
    else:
        raw = run(["git", "log", f"--pretty=format:{fmt}", "--date=short", f"-{fallback_n}"])
    commits = []
    for rec in raw.split("\x1e"):
        rec = rec.strip().strip("\n")
        if not rec:
            continue
        parts = rec.split("\x1f")
        if len(parts) < 7:
            continue
        full, short, author, email, date, subject, body = parts[:7]
        commits.append({
            "sha": full, "short": short, "author": author.strip() or "unknown",
            "email": email.strip(), "date": date.strip(),
            "subject": subject.strip(), "body": body.strip(),
        })
    return commits


def classify(subject):
    m = re.match(r"^(\w+)([\(\:!])?", subject.lower())
    prefix = m.group(1) if m else "other"
    known = {"feat": "Features", "fix": "Fixes", "build": "Build",
             "ci": "CI", "docs": "Docs", "perf": "Performance",
             "refactor": "Refactors", "test": "Tests", "chore": "Chores",
             "style": "Styles", "revert": "Reverts"}
    return known.get(prefix, "Other changes")


def linkify(text, repo):
    """Turn #123 and GH-123 into markdown links; keep URLs as-is."""
    def repl(m):
        n = m.group(1)
        return f"[#{n}](https://github.com/{repo}/issues/{n})"
    return re.sub(r"#(\d+)", repl, text)


def file_stats(before, sha):
    rng = f"{before}..{sha}" if before and before != sha else "HEAD~5..HEAD"
    out = run(["git", "diff", "--stat=80,80", rng])
    if not out:
        out = run(["git", "show", "--stat=80,80", "--oneline", "HEAD"])
    lines = [l for l in out.splitlines() if l.strip()]
    return "\n".join(lines[:25])


def artifact_rows(artifacts_dir):
    rows = []
    if not artifacts_dir or not os.path.isdir(artifacts_dir):
        return rows
    for root, _, files in os.walk(artifacts_dir):
        for fn in sorted(files):
            if not fn.endswith((".ipa", ".tipa", ".zip")):
                continue
            fp = os.path.join(root, fn)
            try:
                size = os.path.getsize(fp)
            except OSError:
                continue
            h = hashlib.sha256()
            try:
                with open(fp, "rb") as f:
                    for chunk in iter(lambda: f.read(4 * 1024 * 1024), b""):
                        h.update(chunk)
                digest = h.hexdigest()
            except OSError:
                digest = "unavailable"
            mb = size / 1024 / 1024
            kind = "TrollStore (.tipa)" if fn.endswith(".tipa") else (
                "Slimmed (no JRE)" if "slimmed" in fn.lower() else "Sideload (.ipa)")
            rows.append({"file": fn, "kind": kind, "mb": mb, "sha": digest, "bytes": size})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", default=os.environ.get("GITHUB_EVENT_BEFORE", ""))
    ap.add_argument("--sha", default=os.environ.get("GITHUB_SHA", "HEAD"))
    ap.add_argument("--branch", default=os.environ.get("GITHUB_REF_NAME", "beta"))
    ap.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", "Witch-Launcher/Witch_launcher"))
    ap.add_argument("--run-url", default="")
    ap.add_argument("--version", default="0.0.2")
    ap.add_argument("--pusher", default="")
    ap.add_argument("--runner", default="")
    ap.add_argument("--artifacts-dir", default="")
    ap.add_argument("--out", default="RELEASE_NOTES.md")
    ap.add_argument("--fallback-n", type=int, default=15)
    args = ap.parse_args()

    commits = get_commits(args.before, args.sha, args.fallback_n)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    authors = Counter(c["author"] for c in commits)
    grouped = OrderedDict()
    for c in commits:
        grouped.setdefault(classify(c["subject"]), []).append(c)

    stats = file_stats(args.before if re.fullmatch(r"[0-9a-f]{4,40}", args.before or "") else "", args.sha)
    arts = artifact_rows(args.artifacts_dir)

    channel = "Stable release" if args.branch in ("main", "master") else "Pre-release (beta)"
    short_sha = args.sha[:7] if len(args.sha) >= 7 else args.sha

    L = []
    L.append(f"## Witch v{args.version} — {channel}")
    L.append("")
    L.append(f"**Branch:** `{args.branch}` | **Commit:** `{short_sha}` | **Date:** {now}")
    if args.pusher:
        L.append(f"**Pushed by:** @{args.pusher}")
    if args.runner:
        L.append(f"**Runner:** {args.runner}")
    if args.run_url:
        L.append(f"**Workflow run:** {args.run_url}")
    L.append("")
    L.append("This is an automated build published by the Witch Release Bot. "
             "You only need to verify — no manual editing required.")
    L.append("")

    # --- Who fixed ---
    L.append(f"### Contributors ({len(commits)} commits in this push)")
    if authors:
        for name, cnt in authors.most_common():
            L.append(f"- @{name} — {cnt} commit{'s' if cnt != 1 else ''}")
    else:
        L.append("- No commit metadata available (shallow checkout or manual dispatch).")
    L.append("")

    # --- What was fixed ---
    L.append("### What changed")
    if not commits:
        L.append("No commit range detected. See the compare link below for full history.")
    for group, items in grouped.items():
        L.append(f"#### {group} ({len(items)})")
        for c in items:
            subj = linkify(c["subject"], args.repo)
            L.append(f"- `{c['short']}` {subj} — @{c['author']} ({c['date']})")
            if c["body"]:
                body = linkify(c["body"][:800], args.repo)
                # indent body as quote, cap lines
                blines = [l for l in body.splitlines() if l.strip()][:8]
                for bl in blines:
                    L.append(f"  > {bl.strip()}")
            L.append(f"  > https://github.com/{args.repo}/commit/{c['sha']}")
        L.append("")

    # --- Files ---
    if stats:
        L.append("<details><summary>Changed files (top 25 lines)</summary>")
        L.append("")
        L.append("```diff")
        L.append(stats[:3000])
        L.append("```")
        L.append("</details>")
        L.append("")

    # --- Artifacts (verbose) ---
    L.append("### Downloads")
    if arts:
        L.append("| File | Target | Size | SHA256 |")
        L.append("|---|---|---|---|")
        for a in arts:
            L.append(f"| `{a['file']}` | {a['kind']} | {a['mb']:.1f} MB | `{a['sha'][:16]}…` |")
        L.append("")
        L.append("<details><summary>Full SHA256 checksums</summary>")
        L.append("")
        L.append("```")
        for a in arts:
            L.append(f"{a['sha']}  {a['file']}")
        L.append("```")
        L.append("</details>")
        L.append("")
    else:
        L.append("Artifacts are attached below as `.ipa` / `.tipa` files. "
                 "If the table is empty, check the workflow artifacts.")
        L.append("")

    L.append("### How to install")
    L.append("- **Sideload (.ipa):** SideStore / AltStore / ESign / Feather with a free Apple ID. "
             "Uses the minimal sideload entitlements (no private keys).")
    L.append("- **TrollStore (.tipa):** install directly in TrollStore for JIT support "
             "(contains private entitlements).")
    L.append("- **Slimmed:** same app without bundled JREs (smaller download, downloads runtimes on first run).")
    L.append("")

    # --- Links ---
    L.append("### Links")
    if args.before and re.fullmatch(r"[0-9a-f]{40}", args.before or "") and re.fullmatch(r"[0-9a-f]{40}", args.sha or ""):
        L.append(f"- Full diff: https://github.com/{args.repo}/compare/{args.before[:7]}...{short_sha}")
    L.append(f"- Commit: https://github.com/{args.repo}/commit/{args.sha}")
    if args.run_url:
        L.append(f"- Build log: {args.run_url}")
    L.append("")
    L.append("---")
    L.append(f"_Published automatically from `{args.branch}` @ `{short_sha}`. Debug symbols (dSYM) retained 14 days._")

    with open(args.out, "w") as f:
        f.write("\n".join(L).rstrip() + "\n")
    print(f"Wrote {args.out} ({len(commits)} commits, {len(arts)} artifacts)")


if __name__ == "__main__":
    sys.exit(main())

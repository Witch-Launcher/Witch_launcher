#!/usr/bin/env python3
"""
Generate Witch release notes from scripts/ci/release_template.md.

The template drives everything: headings, bullet format, tables.
Placeholders: {{version}} {{channel}} {{short_sha}} {{date_utc}} {{owner}}
{{repo}} {{prev_tag}} {{tag}} and, inside a "## <section>" block, per-commit
{{message}} {{author}} {{short_sha}} {{pr_number}} (and per row {{user1}},
{{user2}} for contributors).

Commits are not listed individually: they are auto-classified by conventional
commit prefix into "What's new" (feat), "Fixes" (fix) and "Improvements"
(everything else). A section with no commits is removed, as is the Full
Changelog line on the first build.

Usage:
  python3 scripts/ci/gen_notes.py \
    --before <sha-or-empty> --sha <sha> --branch beta \
    --repo Witch-Launcher/Witch_launcher \
    --version 0.0.5-beta.429536e-20260926-b42 --base-version 0.0.5 \
    --out RELEASE_NOTES.md

  --template <path>  use another template (default scripts/ci/release_template.md)
"""
import argparse
import os
import re
import subprocess
import sys
from collections import Counter, OrderedDict
from datetime import datetime, timezone
from pathlib import Path

TEMPLATE_PATH = Path(__file__).resolve().parents[2] / "scripts" / "ci" / "release_template.md"

MAX_MESSAGE = 160
MAX_COMMITS_PER_SECTION = 30

PREFIXES = {
    "feat": "What's new",
    "fix": "Fixes",
}
DEFAULT_SECTION = "Improvements"
PREFIX_RE = re.compile(r"^(\w+)(\([^)]*\))?(!)?:\s*")
PR_RE = re.compile(r"\(#(\d+)\)\s*$")
TOKEN_RE = re.compile(r"\{\{\s*([a-z0-9_]+)\s*\}\}")
BULLET_RE = re.compile(r"^\s*[-*]\s")
SECTION_RE = re.compile(r"^(#{2,4})\s+(.+?)\s*$")


def run(cmd, cwd="."):
    try:
        return subprocess.check_output(cmd, cwd=cwd, stderr=subprocess.DEVNULL).decode("utf-8", "replace").strip()
    except Exception:
        return ""


def get_commits(before, sha, fallback_n=15):
    rng = None
    if before and sha and before != sha and re.fullmatch(r"[0-9a-f]{4,40}", before or ""):
        try:
            subprocess.check_output(["git", "cat-file", "-e", before], stderr=subprocess.DEVNULL)
            rng = f"{before}..{sha}"
        except subprocess.CalledProcessError:
            rng = None
    fmt = "%H%x1f%an%x1f%ad%x1f%s%x1e"
    raw = run(["git", "log", f"--pretty=format:{fmt}", "--date=short", rng] if rng else
              ["git", "log", f"--pretty=format:{fmt}", "--date=short", f"-{fallback_n}"])
    commits = []
    for rec in raw.split("\x1e"):
        parts = rec.strip().strip("\n").split("\x1f")
        if len(parts) < 4:
            continue
        full, author, date, subject = parts[:4]
        message = subject.strip()
        pr = ""
        m = PR_RE.search(message)
        if m:
            pr = m.group(1)
            message = message[: m.start()].strip()
        message = PREFIX_RE.sub("", message).strip() or message
        if len(message) > MAX_MESSAGE:
            message = message[: MAX_MESSAGE - 1].rstrip() + "…"
        commits.append({
            "sha": full,
            "short": full[:7],
            "author": author.strip() or "unknown",
            "date": date.strip(),
            "subject": subject.strip(),
            "message": re.sub(r"\s+", " ", message),
            "pr": pr,
        })
    return commits


def prefix_of(subject):
    m = re.match(r"^(\w+)", subject.lower())
    return m.group(1) if m else "other"


def classify(subject):
    return PREFIXES.get(prefix_of(subject), DEFAULT_SECTION)


def render_line(line, values):
    return TOKEN_RE.sub(lambda m: str(values.get(m.group(1), "")), line)


def bullet_for(item, variants):
    pr_variants = [v for v in variants if "pr_number" in v]
    sha_variants = [v for v in variants if "pr_number" not in v]
    variant = (pr_variants[0] if item["pr"] and pr_variants else
               (sha_variants[0] if sha_variants else variants[0]))
    return render_line(variant, {
        "message": item["message"],
        "author": item["author"],
        "short_sha": item["short"],
        "pr_number": item["pr"],
    })


def render(template, ctx, commits):
    lines = template.splitlines()
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        header = SECTION_RE.match(line)
        if header:
            section = header.group(2)
            j = i + 1
            variants = []
            while j < len(lines) and BULLET_RE.match(lines[j]) and "{{" in lines[j]:
                variants.append(lines[j])
                j += 1
            if variants:
                picked = [c for c in commits if classify(c["subject"]).lower() == section.lower()]
                picked = picked[:MAX_COMMITS_PER_SECTION]
                if not picked:
                    i = j + 1 if j < len(lines) and not lines[j].strip() else j
                    continue
                out.append(line)
                for c in picked:
                    out.append(bullet_for(c, variants))
                i = j
                continue
        out.append(line)
        i += 1

    text = "\n".join(out)

    contributors = [n for n, _ in Counter(c["author"] for c in commits if c["author"] != "unknown").most_common(20)]
    if not contributors:
        text = re.sub(r"(?m)^#{2,4}\s*Contributors\n.*\n?", "", text)
    else:
        text = text.replace("@{{user1}}, @{{user2}}", ", ".join(f"@{n}" for n in contributors))

    if not ctx.get("prev_tag"):
        text = re.sub(r"(?m)^\*\*Full Changelog\*\*:.*\n?", "", text)

    text = render_line(text, ctx)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip() + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--before", default=os.environ.get("GITHUB_EVENT_BEFORE", ""))
    ap.add_argument("--sha", default=os.environ.get("GITHUB_SHA", "HEAD"))
    ap.add_argument("--branch", default=os.environ.get("GITHUB_REF_NAME", "beta"))
    ap.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", "Witch-Launcher/Witch_launcher"))
    ap.add_argument("--version", default="0.0.2")
    ap.add_argument("--base-version", default="")
    ap.add_argument("--template", default=str(TEMPLATE_PATH))
    ap.add_argument("--out", default="RELEASE_NOTES.md")
    ap.add_argument("--fallback-n", type=int, default=15)
    args = ap.parse_args()

    commits = get_commits(args.before, args.sha, args.fallback_n)
    owner, _, repo_name = args.repo.partition("/")
    stable = args.branch in ("main", "master")
    short_sha = args.sha[:7] if len(args.sha) >= 7 else args.sha
    prev_tag = args.before[:7] if args.before and re.fullmatch(r"[0-9a-f]{7,40}", args.before) else ""
    version = args.base_version or args.version.split("-")[0]

    ctx = {
        "version": version,
        "channel": "Stable" if stable else "Beta",
        "short_sha": short_sha,
        "date_utc": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M"),
        "owner": owner,
        "repo": repo_name,
        "prev_tag": prev_tag,
        "tag": short_sha,
    }

    try:
        body = Path(args.template).read_text(encoding="utf-8")
    except OSError as e:
        print(f"Cannot read template {args.template}: {e}", file=sys.stderr)
        return 1

    notes = render(body, ctx, commits)
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(notes)
    print(f"Wrote {args.out} ({len(commits)} commits)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

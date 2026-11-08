#!/usr/bin/env python3
"""Inject build-time OAuth callback schemes into a built Info.plist.

Google's reversed-client-id scheme and Dropbox's ``db-<app-key>`` scheme are
derived from values that must match the current build. Keeping the tracked
Info.plist free of per-release identifiers avoids stale callbacks when the
credentials change.

If an argument is empty, the value is read from Natives/Config/WitchConfig.h
when that file exists.

Usage:
  python3 scripts/inject_oauth_schemes.py path/to/Witch.app/Info.plist CLIENT_ID [DROPBOX_APP_KEY]
"""

import os
import plistlib
import re
import sys


def config_value(name: str) -> str:
    pattern = re.compile(r"^#define\s+" + re.escape(name) + r'\s+@"([^"]*)"', re.MULTILINE)
    candidates = [
        os.path.join(os.getcwd(), "Natives", "Config", "WitchConfig.h"),
        os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "Natives", "Config", "WitchConfig.h")),
    ]
    for path in candidates:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                match = pattern.search(fh.read())
        except OSError:
            continue
        if match:
            return match.group(1)
    return ""


def google_scheme(client_id: str):
    if not client_id:
        return None
    if not client_id.endswith(".apps.googleusercontent.com"):
        print(f"warning: unexpected Google client id: {client_id}", file=sys.stderr)
        return None
    return "com.googleusercontent.apps." + client_id[: -len(".apps.googleusercontent.com")]


def dropbox_scheme(app_key: str):
    if not app_key:
        return None
    return "db-" + app_key


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(
            "usage: inject_oauth_schemes.py Info.plist CLIENT_ID [DROPBOX_APP_KEY]",
            file=sys.stderr,
        )
        return 2

    path = sys.argv[1]
    client_id = sys.argv[2].strip() or config_value("WITCH_GOOGLE_DRIVE_CLIENT_ID")
    app_key = (sys.argv[3].strip() if len(sys.argv) == 4 else "") or config_value("WITCH_DROPBOX_APP_KEY")

    wanted = []
    google = google_scheme(client_id)
    if google:
        wanted.append(("com.witch.zad626.google", google))
    dropbox = dropbox_scheme(app_key)
    if dropbox:
        wanted.append(("com.witch.zad626.dropbox", dropbox))

    if not wanted:
        return 0

    with open(path, "rb") as fh:
        plist = plistlib.load(fh)

    url_types = plist.setdefault("CFBundleURLTypes", [])
    existing = set()
    for entry in url_types:
        for scheme in entry.get("CFBundleURLSchemes", []):
            existing.add(scheme)

    changed = False
    for name, scheme in wanted:
        if scheme in existing:
            continue
        url_types.append({"CFBundleURLName": name, "CFBundleURLSchemes": [scheme]})
        existing.add(scheme)
        changed = True
        print(f"[oauth] injected {scheme} into {path}")

    if changed:
        with open(path, "wb") as fh:
            plistlib.dump(plist, fh, sort_keys=False)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

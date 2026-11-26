#!/usr/bin/env python3

import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "README.md"
DOCS = ROOT / "docs" / "readme"
GOOGLE = "https://translate.googleapis.com/translate_a/single"
LANG_TABLE_HEADER = "| Code | Language | Code | Language |"
LANG_TABLE_PLACEHOLDER = "ZXQLANGTABLEQXZ"
BATCH_SIZE = 3200

LANGUAGES = [
    ("af", "Afrikaans", "af"),
    ("ar", "العربية", "ar"),
    ("az", "azərbaycan", "az"),
    ("ba", "башҡорт теле", "ba"),
    ("bn", "বাংলা", "bn"),
    ("bn-IN", "বাংলা (ভারত)", "bn"),
    ("ca", "català", "ca"),
    ("cs", "čeština", "cs"),
    ("da", "dansk", "da"),
    ("de", "Deutsch", "de"),
    ("el", "Ελληνικά", "el"),
    ("en", "English", "en"),
    ("en-GB", "English (United Kingdom)", "en"),
    ("en-PT", "Pirate English", "en"),
    ("en-UD", "English (Upside Down)", "en"),
    ("es", "español", "es"),
    ("et", "eesti", "et"),
    ("fa", "فارسی", "fa"),
    ("fi", "suomi", "fi"),
    ("fil", "Filipino", "fil"),
    ("fr", "français", "fr"),
    ("he", "עברית", "he"),
    ("hi", "हिन्दी", "hi"),
    ("hu", "magyar", "hu"),
    ("id", "Indonesia", "id"),
    ("it", "italiano", "it"),
    ("ja", "日本語", "ja"),
    ("kk", "қазақ тілі", "kk"),
    ("ko", "한국어", "ko"),
    ("la", "Latin", "la"),
    ("lol", "LOLCAT", "en"),
    ("lt", "lietuvių", "lt"),
    ("ms", "Bahasa Melayu", "ms"),
    ("nl", "Nederlands", "nl"),
    ("no", "norsk", "no"),
    ("pl", "polski", "pl"),
    ("pr", "Pirate", "en"),
    ("pt", "português", "pt-PT"),
    ("pt-BR", "português (Brasil)", "pt"),
    ("ro", "română", "ro"),
    ("ru", "русский", "ru"),
    ("sk", "slovenčina", "sk"),
    ("sr", "српски", "sr"),
    ("sr-Latn", "srpski (latinica)", "hr"),
    ("sv", "svenska", "sv"),
    ("th", "ไทย", "th"),
    ("tr", "Türkçe", "tr"),
    ("tt", "татар", "tt"),
    ("uk", "українська", "uk"),
    ("vi", "Tiếng Việt", "vi"),
    ("zh-Hans", "简体中文", "zh-CN"),
    ("zh-Hant", "繁體中文", "zh-TW"),
]

PRIMARY_CODES = [code for code, _, _ in LANGUAGES]
PRIMARY = LANGUAGES

SUMMARY = {
    "af": "Tale",
    "ar": "اللغات",
    "az": "Dillər",
    "ba": "Телдәр",
    "bn": "ভাষা",
    "bn-IN": "ভাষা",
    "ca": "Idiomes",
    "cs": "Jazyky",
    "da": "Sprog",
    "de": "Sprachen",
    "el": "Γλώσσες",
    "en": "Languages",
    "en-GB": "Languages",
    "en-PT": "Languages",
    "en-UD": "Languages",
    "es": "Idiomas",
    "et": "Keeled",
    "fa": "زبان ها",
    "fi": "Kielet",
    "fil": "Mga wika",
    "fr": "Langues",
    "he": "שפות",
    "hi": "बोली",
    "hu": "Nyelvek",
    "id": "Bahasa",
    "it": "Lingue",
    "ja": "言語",
    "kk": "Тілдер",
    "ko": "언어",
    "la": "Linguae",
    "lol": "Languages",
    "lt": "Kalbos",
    "ms": "Bahasa",
    "nl": "Talen",
    "no": "Språk",
    "pl": "Języki",
    "pr": "Languages",
    "pt": "Idiomas",
    "pt-BR": "Idiomas",
    "ro": "Limbi",
    "ru": "Языки",
    "sk": "Jazyky",
    "sr": "Језици",
    "sr-Latn": "Jezici",
    "sv": "Språk",
    "th": "ภาษา",
    "tr": "Diller",
    "tt": "Телләр",
    "uk": "Мови",
    "vi": "Ngôn ngữ",
    "zh-Hans": "语言",
    "zh-Hant": "語言",
}

ANCHORS = {
    "About": "about",
    "Features": "features",
    "Screenshots": "screenshots",
    "Requirements": "requirements",
    "Installation": "installation",
    "Languages": "languages",
    "Notes and limitations": "notes-and-limitations",
    "Project lineage": "project-lineage",
    "Contributing": "contributing",
    "Credits": "credits",
    "License": "license",
}

BRANDS = [
    "Witch Launcher",
    "Minecraft: Java Edition",
    "Amethyst-iOS-25",
    "Amethyst-iOS",
    "PojavLauncherTeam",
    "UniversalJIT26.js",
    "LocalDevVPN",
    "CS_DEBUGGED",
    "URL Scheme",
    "manifest.json",
    "A11 Bionic",
    "FSR 1.0",
    "PNG/PDF",
    "GPL-3.0",
    "GPLv3",
    "Witch",
    "Minecraft",
    "Amethyst",
    "PojavLauncher",
    "Boardwalk",
    "Fabric",
    "Quilt",
    "Forge",
    "NeoForge",
    "OptiFine",
    "Modrinth",
    "CurseForge",
    "Sodium",
    "Iris",
    "StikDebug",
    "SideStore",
    "AltStore",
    "TrollStore",
    "Metal",
    "MoltenVK",
    "OpenGL",
    "Vulkan",
    "ANGLE",
    "MobileGlues",
    "Zink",
    "Mesa",
    "LTW",
    "TGLMT",
    "LWJGL",
    "JIT",
    "MADI",
    "iOS",
    "iPadOS",
    "iPhone",
    "iPad",
    "arm64",
    "F3",
    "Java",
    "JDK",
    "CMake",
    "Xcode",
    "macOS",
    "GitHub",
    "TikTok",
    "YouTube",
    "MCHeads",
    "Ely.by",
    "Mojang Studios",
    "Microsoft",
    "SDK",
    "VPN",
    "API",
    "AI",
]

BRAND_RE = re.compile(
    r"\b(?:" + "|".join(re.escape(x) for x in sorted(BRANDS, key=len, reverse=True)) + r")\b"
)

SPECIAL_ENGLISH = {"en-GB", "en-PT", "en-UD", "lol", "pr"}
LANG_META = {code: (name, target) for code, name, target in LANGUAGES}


def finish(text):
    text = re.sub(r"</details>\n{2,}</div>", "</details>\n\n</div>", text)
    return text.rstrip("\n") + "\n"


def language_link(code, from_docs):
    if code == "en":
        return "../../README.md" if from_docs else "README.md"
    return f"README.{code}.md" if from_docs else f"docs/readme/README.{code}.md"


def render_selector(code, from_docs):
    links = []
    for lang_code, name, _ in PRIMARY:
        links.append(f"[{name}]({language_link(lang_code, from_docs)})")
    rows = [" · ".join(links[i:i + 4]) for i in range(0, len(links), 4)]
    rows = [row + "<br>" for row in rows[:-1]] + rows[-1:]
    summary = SUMMARY[code]
    return "<details>\n<summary><strong>%s</strong></summary>\n\n%s\n\n</details>" % (
        summary,
        "\n".join(rows),
    )


def render_language_table(code, from_docs):
    lines = [
        LANG_TABLE_HEADER,
        "|---|---|---|---|",
    ]
    for i in range(0, len(PRIMARY), 2):
        cells = []
        for lang_code, name, _ in PRIMARY[i:i + 2]:
            cells.append(f"`{lang_code}`")
            cells.append(f"[{name}]({language_link(lang_code, from_docs)})")
        lines.append("| " + " | ".join(cells) + " |")
    return "\n".join(lines)


def ensure_anchors(text):
    out = []
    for line in text.splitlines():
        if line.startswith("## "):
            slug = ANCHORS.get(line[3:].strip())
            anchor = f'<a id="{slug}"></a>'
            if slug and (not out or out[-1].strip() != anchor):
                out.append(anchor)
        out.append(line)
    return finish("\n".join(out))


def strip_selector(text):
    out = []
    inside = False
    for line in text.splitlines():
        stripped = line.strip()
        if stripped == "<details>":
            inside = True
            continue
        if inside:
            if stripped == "</details>":
                inside = False
            continue
        out.append(line)
    return finish("\n".join(out))


def replace_language_table(text, replacement):
    lines = text.splitlines()
    out = []
    i = 0
    while i < len(lines):
        if lines[i].strip() == LANG_TABLE_HEADER:
            i += 1
            if i < len(lines) and re.match(r"^\|[\s:|-]+\|$", lines[i].strip()):
                i += 1
            while i < len(lines) and lines[i].startswith("|"):
                i += 1
            out.extend(replacement.splitlines())
            continue
        out.append(lines[i])
        i += 1
    return finish("\n".join(out))


def insert_selector(text, selector):
    lines = text.splitlines()
    index = None
    for i, line in enumerate(lines):
        if "(#features)" in line:
            index = i
            break
    if index is None:
        for i, line in enumerate(lines):
            if line.strip() == "</div>":
                index = i
                break
    if index is None:
        index = 0
    lines[index + 1:index + 1] = ["", *selector.splitlines(), ""]
    return finish("\n".join(lines))


def has_text(line):
    value = re.sub(r"\]\([^)\n]*\)", "]", line)
    value = re.sub(r"`[^`\n]*`", "", value)
    value = re.sub(r"<[^>]*>", "", value)
    value = re.sub(r"[#>*_~\-|\s\[\]]", "", value)
    return bool(value)


def request_translation(text, target):
    params = urllib.parse.urlencode(
        {
            "client": "at",
            "sl": "en",
            "tl": target,
            "dt": "t",
            "q": text,
        }
    )
    request = urllib.request.Request(
        GOOGLE + "?" + params,
        headers={"User-Agent": "Mozilla/5.0"},
    )
    last_error = None
    for attempt in range(5):
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                data = json.load(response)
            return "".join(part[0] for part in data[0] if part and part[0])
        except Exception as error:
            last_error = error
            time.sleep(1.5 * (attempt + 1))
    raise last_error


def normalize_markup(text):
    return text.replace("<б>", "<b>").replace("</б>", "</b>")


def fix_bold_spacing(text):
    return re.sub(r"<b>\s+([^<]+?)\s*</b>", r"<b>\1</b>", text)


class TokenStore:
    def __init__(self):
        self.items = []
        self.next_id = 0
        self.values = {}

    def add(self, value):
        token = f"ZXQ{self.next_id}QXZ"
        self.next_id += 1
        self.items.append((token, value))
        self.values[token] = value
        return token

    def repair(self, text):
        def replace(match):
            token = f"ZXQ{match.group(1)}QXZ"
            return token if token in self.values else match.group(0)

        return re.sub(r"ZXQ(\d+)(?:QXZ)?", replace, text)

    def restore(self, text):
        for token, value in self.items:
            text = text.replace(token, value)
        return fix_bold_spacing(text)


def protect(text, tokens):
    found = []

    def add(value):
        token = tokens.add(value)
        found.append(token)
        return token

    text = re.sub(r"`[^`\n]*`", lambda m: add(m.group(0)), text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"<(?!/?b>)[^>]+>", lambda m: add(m.group(0)), text)
    text = re.sub(
        r"\]\(([^)\n]+)\)",
        lambda m: "](" + add(m.group(1)) + ")",
        text,
    )
    text = re.sub(r"https?://[^\s<>()]+", lambda m: add(m.group(0)), text)
    text = BRAND_RE.sub(lambda m: add(m.group(0)), text)
    return text, found


def split_prefix(line):
    for pattern in (
        r"^(#{1,6}\s+)",
        r"^(\s*[-*+]\s+)",
        r"^(\s*\d+\.\s+)",
        r"^(>\s?)",
    ):
        match = re.match(pattern, line)
        if match:
            return match.group(1), line[len(match.group(1)):].lstrip()
    return "", line


def structure_ok(original, translated):
    if original.startswith("|"):
        if not translated.startswith("|"):
            return False
        if original.count("|") != translated.count("|"):
            return False
    return True


def normalize_table_row(line):
    if not line.startswith("|"):
        return line
    cells = line.strip().strip("|").split("|")
    return "| " + " | ".join(cell.strip() for cell in cells) + " |"


def batch_units(units):
    batches = []
    current = []
    size = 0
    for index, line in units:
        added = len(line) + 24
        if current and size + added > BATCH_SIZE:
            batches.append(current)
            current = []
            size = 0
        current.append((index, line))
        size += added
    if current:
        batches.append(current)
    return batches


def translate_document(text, target):
    lines = text.splitlines()
    units = []
    inside_code = False
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped == LANG_TABLE_PLACEHOLDER:
            i += 1
            continue
        if stripped.startswith("```"):
            inside_code = not inside_code
            i += 1
            continue
        if inside_code:
            i += 1
            continue
        if line.startswith("|"):
            block = []
            j = i
            while j < len(lines) and lines[j].startswith("|"):
                block.append((j, lines[j]))
                j += 1
            skip = any("<img" in row for _, row in block)
            skip = skip or any(re.match(r"^\|\s*`[^`]+`", row) for _, row in block)
            if not skip:
                for index, row in block:
                    if re.match(r"^\|[\s:|-]+\|$", row.strip()):
                        continue
                    if has_text(row):
                        units.append((index, row))
            i = j
            continue
        if line.startswith("[![") or line.startswith("!["):
            i += 1
            continue
        if stripped.startswith("<img") or stripped.startswith("<h1"):
            i += 1
            continue
        if not has_text(line):
            i += 1
            continue
        units.append((i, line))
        i += 1

    tokens = TokenStore()
    protected = {}
    token_lists = {}
    prefixes = {}
    bold_counts = {}
    for index, line in units:
        prefix, body = split_prefix(line)
        bold_counts[index] = body.count("**") // 2
        value, found = protect(body, tokens)
        prefixes[index] = prefix
        protected[index] = value
        token_lists[index] = found

    translated = {}
    for batch_number, batch in enumerate(batch_units([(i, protected[i]) for i, _ in units])):
        separator = f"ZXQBATCH{batch_number}QXZ"
        payload = f"\n{separator}\n".join(line for _, line in batch)
        try:
            output = request_translation(payload, target)
            parts = re.split(r"\s*" + re.escape(separator) + r"\s*", output)
            if len(parts) != len(batch):
                raise ValueError("batch boundary mismatch")
            for (index, _), part in zip(batch, parts):
                value = part.strip("\n")
                if "\n" in value:
                    value = " ".join(value.splitlines())
                original = lines[index]
                if not value.strip():
                    raise ValueError("empty translation")
                value = normalize_markup(tokens.repair(value))
                if any(token not in value for token in token_lists[index]):
                    raise ValueError("missing token")
                if value.count("<b>") != bold_counts[index] or value.count("</b>") != bold_counts[index]:
                    raise ValueError("bold mismatch")
                if not structure_ok(original, value):
                    raise ValueError("structure mismatch")
                translated[index] = prefixes[index] + normalize_table_row(value)
        except Exception:
            for index, value in batch:
                try:
                    result = request_translation(value, target).strip("\n")
                    if "\n" in result:
                        result = " ".join(result.splitlines())
                    if not result.strip():
                        raise ValueError("empty translation")
                    result = normalize_markup(tokens.repair(result))
                    if any(token not in result for token in token_lists[index]):
                        raise ValueError("missing token")
                    if result.count("<b>") != bold_counts[index] or result.count("</b>") != bold_counts[index]:
                        raise ValueError("bold mismatch")
                    if not structure_ok(lines[index], result):
                        raise ValueError("structure mismatch")
                    translated[index] = prefixes[index] + normalize_table_row(result)
                except Exception:
                    translated[index] = lines[index]
        time.sleep(0.12)

    for index in list(translated):
        translated[index] = tokens.restore(translated[index])
        if re.search(r"ZXQ\d+(?:QXZ)?", translated[index]):
            translated[index] = lines[index]

    out = lines[:]
    for index, value in translated.items():
        out[index] = value
    return finish("\n".join(out))


def rewrite_docs_paths(text):
    text = text.replace('src="Natives/', 'src="../../Natives/')
    text = text.replace('src="media/', 'src="../../media/')
    text = re.sub(r"\]\((credits|news|note)\.md\)", r"](../../\1.md)", text)
    text = text.replace("](LICENSE)", "](../../LICENSE)")
    text = text.replace("](docs/readme/)", "](./)")
    text = text.replace("](docs/)", "](../)")
    text = text.replace('src="../Natives/', 'src="../../Natives/')
    text = text.replace('src="../media/', 'src="../../media/')
    text = re.sub(r"\]\(\.\./(credits|news|note)\.md\)", r"](../../\1.md)", text)
    text = text.replace("](../LICENSE)", "](../../LICENSE)")
    text = text.replace("[`docs/`](../docs/)", "[`docs/readme/`](./)")
    text = text.replace("](../docs/)", "](./)")
    return text


def render_main():
    text = SOURCE.read_text(encoding="utf-8")
    text = ensure_anchors(text)
    text = strip_selector(text)
    text = replace_language_table(text, render_language_table("en", False))
    text = insert_selector(text, render_selector("en", False))
    SOURCE.write_text(finish(text), encoding="utf-8")
    return SOURCE.read_text(encoding="utf-8")


def render_docs(source_text, code):
    name, target = LANG_META[code]
    text = strip_selector(source_text)
    text = replace_language_table(text, LANG_TABLE_PLACEHOLDER)
    if code not in SPECIAL_ENGLISH:
        print(f"  translating {code} ({name}) -> {target}", flush=True)
        text = translate_document(text, target)
        text = re.sub(r"<b>(.+?)</b>", r"**\1**", text)
    text = text.replace(LANG_TABLE_PLACEHOLDER, render_language_table(code, True))
    text = insert_selector(text, render_selector(code, True))
    text = rewrite_docs_paths(text)
    output = DOCS / f"README.{code}.md"
    output.write_text(finish(text), encoding="utf-8")


def main():
    requested = sys.argv[1:]
    if requested:
        missing = [code for code in requested if code not in LANG_META]
        if missing:
            raise SystemExit("unknown locale(s): " + ", ".join(missing))
    source_text = render_main()
    codes = requested or [code for code, _, _ in PRIMARY if code != "en"]
    DOCS.mkdir(parents=True, exist_ok=True)
    for code in codes:
        if code == "en":
            continue
        render_docs(source_text, code)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Fill missing Localizable.strings keys for every shipped .lproj pack."""

import argparse
import collections
import json
import os
import random
import re
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "Natives" / "resources"
EN_PATH = RES / "en.lproj" / "Localizable.strings"
CACHE_PATH = Path(tempfile.gettempdir()) / "witch-localization-cache.json"

ENTRY_RE = re.compile(r'(?m)^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
TOKEN_RE = re.compile(
    r'\\(?:["\\nrt]|x[0-9A-Fa-f]{2}|u[0-9A-Fa-f]{4}|[0-7]{1,3})'
    r'|%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|L|z|j|t)?[diuoxXfFeEgGaAcsp@%]'
)
TOKEN_RESTORE_RE = re.compile(r'\[+\s*(\d{4,5})\s*\]+')
ZERO_WIDTH = dict.fromkeys(map(ord, "\u200b\u2060\ufeff"), None)

GLOSSARY = [
    "UniversalJIT26.js", "PojavLauncher", "CurseForge", "StikDebug",
    "MobileGlues", "Minecraft", "Amethyst", "Modrinth", "MoltenVK", "OpenGL",
    "AirPlay", "Microsoft", "Discord", "Vulkan", "LWJGL", "iPadOS", "Xbox", "Java",
    "Metal", "ANGLE", "Mesa", "Witch", "JIT", "JVM", "JDK", "JRE", "FPS",
    "CPU", "GPU", "RAM", "LTW", "iOS", "API", "URL", "SHA1", "SHA256", "F3",
]
GLOSSARY_RE = re.compile(
    r"\b(?:" + "|".join(re.escape(item) for item in sorted(GLOSSARY, key=len, reverse=True)) + r")\b"
)


class TranslationUnavailable(RuntimeError):
    pass


TARGETS = {
    "af": "af",
    "ar": "ar",
    "az": "az",
    "ba": "ba",
    "bn": "bn",
    "bn-IN": "bn",
    "ca": "ca",
    "cs": "cs",
    "da": "da",
    "de": "de",
    "el": "el",
    "es": "es",
    "et": "et",
    "fa": "fa",
    "fi": "fi",
    "fil": "fil",
    "fr": "fr",
    "he": "he",
    "hi": "hi",
    "hu": "hu",
    "id": "id",
    "it": "it",
    "ja": "ja",
    "kk": "kk",
    "ko": "ko",
    "la": "la",
    "lt": "lt",
    "ms": "ms",
    "nl": "nl",
    "no": "no",
    "pl": "pl",
    "pt": "pt-PT",
    "pt-BR": "pt",
    "ro": "ro",
    "ru": "ru",
    "sk": "sk",
    "sr": "sr",
    "sr-Latn": "sr",
    "sv": "sv",
    "th": "th",
    "tr": "tr",
    "tt": "tt",
    "uk": "uk",
    "vi": "vi",
    "zh-Hans": "zh-CN",
    "zh-Hant": "zh-TW",
}

COPY_PACKS = {"en-GB", "en-PT", "lol", "pr"}
SPECIAL_PACKS = COPY_PACKS | {"en", "en-UD"}

SR_TRANSLITERATION = {
    "Љ": "Lj", "Њ": "Nj", "Џ": "Dž", "Ђ": "Đ", "Ј": "J",
    "А": "A", "Б": "B", "В": "V", "Г": "G", "Д": "D", "Е": "E",
    "Ж": "Ž", "З": "Z", "И": "I", "К": "K", "Л": "L", "М": "M",
    "Н": "N", "О": "O", "П": "P", "Р": "R", "С": "S", "Т": "T",
    "Ћ": "Ć", "У": "U", "Ф": "F", "Х": "H", "Ц": "C", "Ч": "Č",
    "Ш": "Š", "Й": "J", "љ": "lj", "њ": "nj", "џ": "dž", "ђ": "đ",
    "ј": "j", "а": "a", "б": "b", "в": "v", "г": "g", "д": "d",
    "е": "e", "ж": "ž", "з": "z", "и": "i", "к": "k", "л": "l",
    "м": "m", "н": "n", "о": "o", "п": "p", "р": "r", "с": "s",
    "т": "t", "ћ": "ć", "у": "u", "ф": "f", "х": "h", "ц": "c",
    "ч": "č", "ш": "š", "й": "j",
}

UPSIDE_DOWN = str.maketrans({
    "a": "ɐ", "b": "q", "c": "ɔ", "d": "p", "e": "ǝ", "f": "ɟ",
    "g": "ƃ", "h": "ɥ", "i": "ᴉ", "j": "ɾ", "k": "ʞ", "l": "l",
    "m": "ɯ", "n": "u", "o": "o", "p": "d", "q": "b", "r": "ɹ",
    "s": "s", "t": "ʇ", "u": "n", "v": "ʌ", "w": "ʍ", "x": "x",
    "y": "ʎ", "z": "z",
    "A": "∀", "B": "𐐒", "C": "Ɔ", "D": "◖", "E": "Ǝ", "F": "Ⅎ",
    "G": "⅁", "H": "H", "I": "I", "J": "ſ", "K": "ʞ", "L": "˥",
    "M": "W", "N": "N", "O": "O", "P": "Ԁ", "Q": "Ό", "R": "ᴚ",
    "S": "S", "T": "⊥", "U": "∩", "V": "Λ", "W": "M", "X": "X",
    "Y": "⅄", "Z": "Z",
    "0": "0", "1": "Ɩ", "2": "ᄅ", "3": "Ɛ", "4": "ㄣ", "5": "ϛ",
    "6": "9", "7": "ㄥ", "8": "8", "9": "6",
    ".": "˙", ",": "'", "?": "¿", "!": "¡", '"': "„", "'": ",",
    "(": ")", ")": "(", "[": "]", "]": "[", "{": "}", "}": "{",
    "<": ">", ">": "<", "_": "‾", "&": "⅋", ";": "؛", ":": ":",
    "/": "/", "\\": "\\", "-": "-", "+": "+", "=": "=", "*": "*",
    "%": "%", "@": "@", "#": "#", "$": "$", "^": "^", "~": "~",
    "`": "`", "|": "|",
})


def parse_strings(path):
    raw = path.read_bytes()
    bom = raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    entries = [(m.group(1), m.group(2)) for m in ENTRY_RE.finditer(text)]
    return entries, text, bom


def write_strings(path, text, bom):
    path.write_bytes(text.encode("utf-8-sig" if bom else "utf-8"))


def tokenize(value):
    tokens = {}
    counter = [7000]

    def replace(match):
        counter[0] += 1
        key = str(counter[0])
        tokens[key] = match.group(0)
        return "[[%s]]" % key

    protected = TOKEN_RE.sub(replace, value)
    return GLOSSARY_RE.sub(replace, protected), tokens


def restore_tokens(text, tokens):
    missing = []

    def replace(match):
        key = match.group(1)
        raw = tokens.get(key)
        if raw is None:
            missing.append(key)
            return match.group(0)
        return raw

    return TOKEN_RESTORE_RE.sub(replace, text), missing


def token_counts(text):
    return collections.Counter(TOKEN_RESTORE_RE.findall(text))


def clean_translation(value):
    return value.translate(ZERO_WIDTH)


def escape_value(value):
    return (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def preserve_outer_spaces(source, translated):
    if not source:
        return source
    if not source.strip(" "):
        return source
    left = source[: len(source) - len(source.lstrip(" "))]
    right = source[len(source.rstrip(" ")) :]
    return left + translated.strip(" ") + right


def transliterate_sr(text):
    for source, target in sorted(SR_TRANSLITERATION.items(), key=lambda item: -len(item[0])):
        text = text.replace(source, target)
    return text


def upside_down(value):
    tokenized, tokens = tokenize(value)
    protected = []
    placeholders = {}

    def replace(match):
        char = chr(0xF0000 + len(protected))
        protected.append(char)
        placeholders[char] = tokens[match.group(1)]
        return char

    text = TOKEN_RESTORE_RE.sub(replace, tokenized)
    text = "".join(reversed(text)).translate(UPSIDE_DOWN)
    text = escape_value(text)
    for char, raw in placeholders.items():
        text = text.replace(char, raw)
    return text


def request_translation(text, target):
    url = (
        "https://translate.googleapis.com/translate_a/single"
        "?client=gtx&sl=en&dt=t&tl="
        + urllib.parse.quote(target)
        + "&q="
        + urllib.parse.quote(text)
    )
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            "Accept-Language": "en-US,en;q=0.9",
        },
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        data = json.load(response)
    return "".join(segment[0] for segment in data[0] if segment and segment[0])


def translate_batch(values, target):
    text = "\n".join(values)
    for attempt in range(8):
        try:
            output = request_translation(text, target)
            lines = output.split("\n")
            if len(lines) == len(values):
                return lines
            if output.endswith("\n") and len(lines) == len(values) + 1:
                lines = lines[:-1]
                if len(lines) == len(values):
                    return lines
            break
        except urllib.error.HTTPError as error:
            if error.code == 400:
                break
            if error.code in (429, 500, 502, 503, 504):
                time.sleep(min(90, (2 ** attempt) + random.random()))
                continue
            break
        except Exception:
            time.sleep(min(30, 1 + attempt * 2))

    if len(values) == 1:
        for attempt in range(8):
            try:
                return [request_translation(values[0], target)]
            except urllib.error.HTTPError as error:
                if error.code in (429, 500, 502, 503, 504):
                    time.sleep(min(90, (2 ** attempt) + random.random()))
                    continue
                return None
            except Exception:
                time.sleep(min(30, 1 + attempt * 2))
        return None

    middle = len(values) // 2
    left = translate_batch(values[:middle], target)
    if left is None:
        return None
    right = translate_batch(values[middle:], target)
    if right is None:
        return None
    return left + right


def translate_segmented(tokenized, tokens, target):
    newline_ids = [key for key, raw in tokens.items() if raw in ("\\n", "\\r")]
    if newline_ids:
        pattern = r"(\[\[(?:" + "|".join(re.escape(key) for key in newline_ids) + r")\]\])"
        parts = re.split(pattern, tokenized)
        output = []
        for part in parts:
            if not part:
                continue
            match = re.fullmatch(r"\[\[(\d{4,5})\]\]", part)
            if match and match.group(1) in newline_ids:
                output.append(part)
                continue
            translated = translate_batch([part], target)
            if translated is None:
                return None
            output.append(translated[0])
        result = "".join(output)
    else:
        parts = re.split(r"(?<=[.!?])\s+", tokenized)
        output = []
        for part in parts:
            translated = translate_batch([part], target)
            if translated is None:
                return None
            output.append(translated[0])
        result = " ".join(output)
    if token_counts(result) != token_counts(tokenized):
        return None
    return result


def make_batches(items, max_lines=250, max_chars=9000):
    batch = []
    chars = 0
    for item in items:
        tokenized = item[1]
        if batch and (len(batch) >= max_lines or chars + len(tokenized) + 1 > max_chars):
            yield batch
            batch = []
            chars = 0
        batch.append(item)
        chars += len(tokenized) + 1
    if batch:
        yield batch


def load_cache():
    if not CACHE_PATH.exists():
        return {}
    try:
        return json.loads(CACHE_PATH.read_text("utf-8"))
    except Exception:
        return {}


def save_cache(cache):
    CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
    temporary = CACHE_PATH.with_suffix(".tmp")
    temporary.write_text(json.dumps(cache, ensure_ascii=False), "utf-8")
    os.replace(temporary, CACHE_PATH)


def cache_key(target, tokenized):
    return target + "\x00" + tokenized


def translate_values(values, target, cache):
    pending = []
    for value in values:
        tokenized, tokens = tokenize(value)
        key = cache_key(target, tokenized)
        cached = cache.get(key)
        if cached is not None:
            if token_counts(cached) == token_counts(tokenized):
                continue
            del cache[key]
        pending.append((value, tokenized, tokens, key))

    if not pending:
        return 0

    translated = 0
    last_save = time.time()
    for index, batch in enumerate(make_batches(pending), 1):
        lines = translate_batch([item[1] for item in batch], target)
        if lines is None:
            if len(batch) > 1:
                raise TranslationUnavailable("translation request failed")
            continue
        for (value, tokenized, tokens, key), line in zip(batch, lines):
            line = clean_translation(line)
            if token_counts(line) != token_counts(tokenized):
                individual = translate_batch([tokenized], target)
                if individual:
                    line = clean_translation(individual[0])
                if token_counts(line) != token_counts(tokenized):
                    segmented = translate_segmented(tokenized, tokens, target)
                    if segmented is None:
                        continue
                    line = clean_translation(segmented)
                    if token_counts(line) != token_counts(tokenized):
                        continue
            cache[key] = line
            translated += 1
        if time.time() - last_save > 15:
            save_cache(cache)
            last_save = time.time()
        print("  batches=%d translated=%d pending=%d" % (index, translated, len(pending)), flush=True)
    save_cache(cache)
    return translated


def translated_value(value, target, cache, latin=False):
    tokenized, tokens = tokenize(value)
    line = cache.get(cache_key(target, tokenized))
    if line is None:
        return value
    line = clean_translation(line)
    if latin:
        line = transliterate_sr(line)
    line = escape_value(line)
    restored, missing = restore_tokens(line, tokens)
    if missing:
        return value
    restored = re.sub(r" *(\\n|\\r) *", r"\1", restored)
    return preserve_outer_spaces(value, restored)


def fill_language(code, english, limit=0, dry_run=False, cache=None):
    path = RES / (code + ".lproj") / "Localizable.strings"
    if not path.exists():
        print("skip %s: missing file" % code, flush=True)
        return 0
    entries, text, bom = parse_strings(path)
    existing = {key for key, _ in entries}
    missing = [(key, value) for key, value in english if key not in existing and key != "language.name"]
    if limit:
        missing = missing[:limit]
    if dry_run:
        print("%-10s missing=%d" % (code, len(missing)), flush=True)
        return 0
    if not missing:
        print("%-10s complete" % code, flush=True)
        return 0

    if code == "en":
        return 0
    if code in COPY_PACKS:
        generated = [(key, value) for key, value in missing]
    elif code == "en-UD":
        generated = [(key, upside_down(value)) for key, value in missing]
    else:
        target = TARGETS[code]
        unique_values = list(dict.fromkeys(value for _, value in missing))
        translate_values(unique_values, target, cache)
        latin = code == "sr-Latn"
        generated = [
            (key, translated_value(value, target, cache, latin=latin))
            for key, value in missing
        ]

    if not text.endswith("\n"):
        text += "\n"
    text += "\n/* Missing translations generated from en.lproj. */\n"
    for key, value in generated:
        text += '"%s" = "%s";\n' % (key, value)
    write_strings(path, text, bom)
    print("%-10s appended=%d" % (code, len(generated)), flush=True)
    return len(generated)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    english, _, _ = parse_strings(EN_PATH)
    english = list(dict.fromkeys(english))
    requested = {item.strip() for item in args.only.split(",") if item.strip()}
    codes = sorted(path.name[:-6] for path in RES.glob("*.lproj"))
    if requested:
        codes = [code for code in codes if code in requested]

    if args.dry_run:
        for code in codes:
            fill_language(code, english, limit=args.limit, dry_run=True)
        return 0

    cache = load_cache()
    total = 0
    try:
        for code in codes:
            total += fill_language(code, english, limit=args.limit, cache=cache)
            save_cache(cache)
    except KeyboardInterrupt:
        save_cache(cache)
        raise
    except TranslationUnavailable as error:
        save_cache(cache)
        print("stopped: %s; cache saved, rerun to continue" % error, flush=True)
        return 2
    print("done: appended=%d" % total, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

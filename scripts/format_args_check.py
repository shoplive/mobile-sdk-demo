#!/usr/bin/env python3
"""Format-argument checker for the demo apps' localized strings (iOS + Android).

A format string and its call site must agree, in every language. When they do not:
  · iOS `L(key, args…)` (DemoStrings.swift) returns the format untouched when no argument
    is passed — the viewer sees a literal "%d" — and `String(format:)` reads garbage when
    an argument is missing;
  · Android `getString(id, args…)` throws MissingFormatArgumentException when one is
    missing, and shows "%d" when none is passed.
Renumbering missions moved numbers out of the strings and into "%d" arguments
(SMV-1922 S22·S36), so this checks:

  1. key sets      — every language file has the same keys (Android: translatable ones)
  2. placeholders  — per key, the same number of placeholders, of the same kinds, in every
                     language
  3. call sites    — iOS `L("key", …)` and Android `stringResource / getString / string
                     (R.string.key, …)` pass exactly as many arguments as the key has
                     placeholders. Indirect iOS calls such as `L(titleKey)` are resolved
                     through the literal assigned to that name (`titleKey: "mission.x.title"`).

Not checked (printed as "limits" on every run): Android <plurals> and iOS .stringsdict
entries, keys computed at run time (`L(someVariable)` with no literal to resolve), and calls
with spread arguments. A placeholder string handed on as a bare `R.string.key` reference is
reported as a warning — where it is finally formatted cannot be seen statically.

Usage:  python3 scripts/format_args_check.py [-v]
Exit:   0 = consistent · 1 = mismatches found (warnings alone do not fail)
Standard library only.
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

from source_scan import mask, split_args

ROOT = Path(__file__).resolve().parent.parent

IOS_SOURCES = ROOT / "iOS"
IOS_STRINGS = {lang: ROOT / f"iOS/ShopliveOnboardingDemo/Resources/{lang}.lproj/Localizable.strings"
               for lang in ("en", "ko", "ja")}
ANDROID_SOURCES = ROOT / "Android"
ANDROID_STRINGS = {
    "en": ROOT / "Android/app/src/main/res/values/strings.xml",
    "ko": ROOT / "Android/app/src/main/res/values-ko/strings.xml",
    "ja": ROOT / "Android/app/src/main/res/values-ja/strings.xml",
}
BASE_LANG = "en"
SKIP_DIRS = {"build", ".build", ".gradle", "Pods", "DerivedData", ".idea", ".swiftpm"}

# Functions whose first argument is a string key / resource and the rest its format args.
IOS_FORMAT_FUNCS = {"L"}
ANDROID_FORMAT_FUNCS = {"stringResource", "getString", "string", "pluralStringResource", "getText"}

# printf-style (iOS: Foundation String(format:)) and java.util.Formatter (Android).
IOS_PLACEHOLDER = re.compile(
    r"%(?:(\d+)\$)?[-+ #0']*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|h|ll|l|q|L|z|t|j)?([@dDiuUxXoOfFeEgGcCsSpaA])")
ANDROID_PLACEHOLDER = re.compile(r"%(?:(\d+)\$)?[-#+ 0,(<]*\d*(?:\.\d+)?([a-zA-Z])")

KIND = {  # conversion → argument kind; two languages must ask for the same kinds
    **{c: "int" for c in "dDiuUxXoOc"},
    **{c: "float" for c in "fFeEgGaA"},
    "@": "object", "s": "text", "S": "text", "p": "pointer", "C": "int",
    "b": "bool", "B": "bool", "h": "hash", "H": "hash", "t": "time", "T": "time",
}


# ── Placeholders ─────────────────────────────────────────────────────────────

def placeholders(value: str, platform: str) -> tuple[int, tuple[str, ...]]:
    """(argument count, kinds in argument order) for one format string."""
    text = value.replace("%%", "")
    pattern = IOS_PLACEHOLDER if platform == "ios" else ANDROID_PLACEHOLDER
    by_position: dict[int, str] = {}
    sequential = 0
    for match in pattern.finditer(text):
        position, conversion = match.group(1), match.group(2)
        if platform == "android" and conversion == "n":       # %n = line separator, no argument
            continue
        if position:
            index = int(position)
        else:
            sequential += 1
            index = sequential
        by_position[index] = KIND.get(conversion, conversion)
    count = max(by_position, default=0)
    kinds = tuple(by_position.get(i, "?") for i in range(1, count + 1))
    return count, kinds


# ── Resource files ───────────────────────────────────────────────────────────

STRINGS_ENTRY = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.M)


def load_ios(path: Path) -> dict[str, str]:
    text = re.sub(r"/\*[\s\S]*?\*/", "", path.read_text(encoding="utf-8"))
    text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
    return {m.group(1): m.group(2) for m in STRINGS_ENTRY.finditer(text)}


def load_android(path: Path) -> tuple[dict[str, str], set[str]]:
    """(name → value, names marked translatable=false). formatted="false" strings count as no placeholders."""
    values: dict[str, str] = {}
    untranslatable: set[str] = set()
    for node in ET.parse(path).getroot():
        if node.tag != "string":
            continue
        name = node.get("name")
        if not name:
            continue
        value = "".join(node.itertext())
        values[name] = "" if node.get("formatted") == "false" else value
        if node.get("translatable") == "false":
            untranslatable.add(name)
    return values, untranslatable


# ── Source scanning ──────────────────────────────────────────────────────────

def source_files(directory: Path, suffixes: tuple[str, ...]) -> list[Path]:
    files = []
    for path in sorted(directory.rglob("*")):
        if path.suffix in suffixes and path.is_file() and \
                not any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            files.append(path)
    return files


def line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


class CallSite:
    def __init__(self, path: Path, line: int, key: str, args: int | None, how: str) -> None:
        self.path, self.line, self.key, self.args, self.how = path, line, key, args, how

    def where(self) -> str:
        return f"{self.path.relative_to(ROOT)}:{self.line}"


LITERAL = re.compile(r'^"([^"\\]*)"$')


def ios_call_sites(info: list[str]) -> list[CallSite]:
    sites: list[CallSite] = []
    indirect: dict[str, set[int]] = defaultdict(set)      # identifier → arg counts it is called with
    texts: list[tuple[Path, str, str]] = []
    for path in source_files(IOS_SOURCES, (".swift",)):
        raw = path.read_text(encoding="utf-8")
        no_comments, skeleton = mask(raw, "swift")
        texts.append((path, no_comments, skeleton))
        for match in re.finditer(r"(?<![\w.])(" + "|".join(IOS_FORMAT_FUNCS) + r")\s*\(", skeleton):
            spans = split_args(skeleton, match.end() - 1)
            if not spans:
                continue
            first = no_comments[spans[0][0]:spans[0][1]].strip()
            if first.startswith("_ ") or ":" in first:        # the function's own declaration
                continue
            extra = len(spans) - 1
            literal = LITERAL.match(first)
            if literal:
                sites.append(CallSite(path, line_of(raw, match.start()), literal.group(1), extra, "L(\"…\")"))
            elif re.fullmatch(r"[A-Za-z_]\w*", first):
                indirect[first].add(extra)
            else:
                info.append(f"{path.relative_to(ROOT)}:{line_of(raw, match.start())}: L({first}) — key is computed, not checked")
    # Resolve L(name) through `name: "key"` / `name = "key"` literals in the same sources.
    for name, counts in indirect.items():
        found = False
        pattern = re.compile(r"\b" + re.escape(name) + r'\s*[:=]\s*"([^"\\]+)"')
        for path, no_comments, _ in texts:
            for match in pattern.finditer(no_comments):
                found = True
                for count in counts:
                    sites.append(CallSite(path, line_of(no_comments, match.start()), match.group(1), count, f"L({name})"))
        if not found:
            info.append(f"L({name}) — no literal assigned to `{name}` found, not checked")
    return sites


def android_call_sites(info: list[str]) -> list[CallSite]:
    sites: list[CallSite] = []
    for path in source_files(ANDROID_SOURCES, (".kt", ".java")):
        raw = path.read_text(encoding="utf-8")
        no_comments, skeleton = mask(raw, "kotlin")
        for match in re.finditer(r"\bR\.string\.([A-Za-z0-9_]+)", skeleton):
            key = match.group(1)
            # Walk back over `id =` and whitespace to the opening parenthesis, then read the callee.
            j = match.start() - 1
            while j >= 0 and skeleton[j].isspace():
                j -= 1
            named = re.search(r"\bid\s*=\s*$", skeleton[max(0, j - 10):j + 1])
            if named:
                j = j - len(named.group(0))
                while j >= 0 and skeleton[j].isspace():
                    j -= 1
            callee = None
            if j >= 0 and skeleton[j] == "(":
                k = j - 1
                while k >= 0 and skeleton[k].isspace():
                    k -= 1
                callee_match = re.search(r"([A-Za-z_]\w*)$", skeleton[:k + 1])
                callee = callee_match.group(1) if callee_match else None
            line = line_of(raw, match.start())
            if callee not in ANDROID_FORMAT_FUNCS:
                sites.append(CallSite(path, line, key, None, "R.string reference"))
                continue
            spans = split_args(skeleton, j)
            if spans is None:
                info.append(f"{path.relative_to(ROOT)}:{line}: {callee}(R.string.{key}, …) — could not parse the call")
                continue
            rest = [no_comments[a:b].strip() for a, b in spans[1:]]
            if any(arg.startswith("*") for arg in rest):
                info.append(f"{path.relative_to(ROOT)}:{line}: {callee}(R.string.{key}, *…) — spread arguments, not checked")
                continue
            sites.append(CallSite(path, line, key, len(rest), f"{callee}(R.string.…)"))
    return sites


# ── Checks ───────────────────────────────────────────────────────────────────

def check_platform(name: str, tables: dict[str, dict[str, str]], skip_parity: set[str],
                   sites: list[CallSite], platform: str, problems: list[str], warnings: list[str]) -> tuple[int, int]:
    base = tables[BASE_LANG]
    # 1. key sets
    expected = set(base) - skip_parity
    for lang, table in tables.items():
        if lang == BASE_LANG:
            continue
        for key in sorted(expected - set(table)):
            problems.append(f"{name} [{lang}] missing key \"{key}\" (present in {BASE_LANG})")
        for key in sorted(set(table) - set(base)):
            problems.append(f"{name} [{lang}] extra key \"{key}\" (not in {BASE_LANG})")

    # 2. placeholders agree across languages
    shape: dict[str, tuple[int, tuple[str, ...]]] = {}
    for key in sorted(base):
        per_lang = {lang: placeholders(table[key], platform) for lang, table in tables.items() if key in table}
        counts = {lang: c for lang, (c, _) in per_lang.items()}
        kinds = {lang: k for lang, (_, k) in per_lang.items()}
        if len(set(counts.values())) > 1:
            problems.append(f"{name} \"{key}\": placeholder count differs — " +
                            ", ".join(f"{lang} {c}" for lang, c in counts.items()))
        elif len(set(kinds.values())) > 1:
            problems.append(f"{name} \"{key}\": placeholder kinds differ — " +
                            ", ".join(f"{lang} {'/'.join(k)}" for lang, k in kinds.items()))
        shape[key] = per_lang[BASE_LANG]

    # 3. call sites
    checked = 0
    for site in sites:
        if site.key not in base:
            problems.append(f"{site.where()}: {site.how} uses \"{site.key}\", which is not in the {name} {BASE_LANG} strings")
            continue
        count = shape[site.key][0]
        if site.args is None:
            if count:
                warnings.append(f"{site.where()}: R.string.{site.key} has {count} placeholder(s) and is passed on "
                                f"as a reference — check where it is formatted")
            continue
        checked += 1
        if site.args != count:
            problems.append(f"{site.where()}: {site.how} \"{site.key}\" passes {site.args} argument(s), "
                            f"the string has {count} placeholder(s)")
    return len(base), checked


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("-v", "--verbose", action="store_true", help="also list each call site that was not checked")
    options = parser.parse_args()

    problems: list[str] = []
    warnings: list[str] = []
    info: list[str] = []

    ios_tables = {lang: load_ios(path) for lang, path in IOS_STRINGS.items()}
    ios_keys, ios_checked = check_platform("iOS", ios_tables, set(), ios_call_sites(info), "ios", problems, warnings)

    android_tables: dict[str, dict[str, str]] = {}
    untranslatable: set[str] = set()
    for lang, path in ANDROID_STRINGS.items():
        values, skip = load_android(path)
        android_tables[lang] = values
        untranslatable |= skip
    android_keys, android_checked = check_platform("Android", android_tables, untranslatable,
                                                   android_call_sites(info), "android", problems, warnings)

    plurals = sum(path.read_text(encoding="utf-8").count("<plurals") for path in ANDROID_STRINGS.values())
    stringsdicts = len(list((ROOT / "iOS").rglob("*.stringsdict")))
    print(f"limits: not checked — Android <plurals> ({plurals} found), iOS .stringsdict ({stringsdicts} found), "
          f"{len(info)} call site(s) with a computed key or spread arguments" + ("" if options.verbose else " (-v lists them)"))
    for line in problems:
        print(line)
    for line in warnings:
        print(f"warning: {line}")
    if options.verbose:
        for line in info:
            print(f"note: {line}")
    status = "FAIL" if problems else "OK"
    print(f"format_args_check: {status} — iOS {ios_keys} keys × {len(ios_tables)} languages, {ios_checked} call sites; "
          f"Android {android_keys} keys × {len(android_tables)} languages, {android_checked} call sites; "
          f"{len(problems)} problem(s), {len(warnings)} warning(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())

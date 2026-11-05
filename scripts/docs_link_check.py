#!/usr/bin/env python3
"""Docs link checker — README.md, iOS/README.md, Android/README.md and docs/*.md.

Renumbering missions renames files and guide anchors at once, and a docs code snippet
can keep showing an API the code no longer has (SMV-1922 S23·S48). What is checked:

  1. relative links    — the target file/dir exists; a `#anchor` into a .md file (or the
                         same page) matches one of its headings (GitHub slug rules)
  2. guide anchors     — links to the v3 integration guide, and bare mentions such as
                         `#m3-pipstart`, use an id the guide has (GUIDE_ANCHORS, or the ids
                         found in every file given with --guide-html)
  3. mission pages     — docs/mission-NN-*.md links its own guide mission #mN, and its H1 is
                         "# Mission N — <title>" with the guide's (English) mission-map title
  4. snippet names     — in ```swift / ```kotlin blocks, every type, member and called name
                         occurs in the iOS / Android sources as code: comments and string text
                         are stripped from the sources first, so a word that survives only in a
                         log message or a comment does not count
  5. Type.member       — on a type declared in this repo, the member occurs in that type's
                         own declaration/extension files
  6. repo signatures   — a call to a function or initializer declared in this repo
                         (`RepoType.name(…)`, `RepoType(…)`, or an unqualified `name(…)`) must fit
                         one of its declarations: Swift by argument labels (defaults, variadics and
                         one trailing closure allowed), Kotlin by argument count and named
                         arguments; a function the snippet itself declares under a repo name must
                         have the repo's labels (Swift) / parameter names (Kotlin)

Limits (also printed on the first line of every run):
  · calls on a lowercase receiver (`player.play(…)`) are not signature-checked — the receiver's
    type is unknown, and most of them are SDK or platform API;
  · SDK and platform API is checked for presence only where the demo itself uses it
    (plus FRAMEWORK_NAMES / SDK_NAMES); a signature is never checked against the SDK;
  · overloads: a call passes if any declaration with that name (on that type) fits;
  · arguments or parameter lists containing "…" are abbreviations and are skipped;
  · Swift unqualified lowercase calls are skipped when the name is also a UIKit/Foundation
    method the snippet may mean (SWIFT_AMBIGUOUS_CALLS).

Usage:  python3 scripts/docs_link_check.py [-v] [--guide-html FILE ...] [file.md ...]
Exit:   0 = clean · 1 = problems found
Standard library only.
"""

from __future__ import annotations

import argparse
import html as htmllib
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import unquote, urlsplit

from source_scan import close_paren, mask, split_args

ROOT = Path(__file__).resolve().parent.parent

DEFAULT_DOCS = ["README.md", "iOS/README.md", "Android/README.md", "docs/*.md"]

# Content ids of the v3 integration guide (SDK 3.0.4), taken from
# shoplive-v3-integration-guide-{ko,en,ja}.html on 2026-11-04 — the three languages share
# the same ids. Page chrome (sidebar, search box, theme toggle…) is left out on purpose.
# Used unless --guide-html is given; refresh it from the page source when the guide changes.
GUIDE_ANCHORS = frozenset({
    "overview", "shoplive-overall", "what-to-show", "mission-map", "upgrade-304",
    "quickstart", "qs-keys", "install", "demo", "tip-flow",
    "screens", "screens-player", "screens-preview-pip", "screens-streamer",
    "m1",
    "m2", "m2-preview", "m2-pair",
    "m3", "m3-pipstart", "m3-buttons",
    "m4",
    "m5", "m5-judge", "m5-setuser", "m5-hash", "m5-queenie",
    "m6", "m6-events", "m6-closed", "m6-share",
    "m7", "m7-choose", "m7-native", "m7-view", "m7-preview", "m7-tap", "m7-web",
    "m8", "m8-kinds",
    "m9", "m9-1", "m9-events",
    "fields", "f-config", "f-attr", "f-user", "f-playerconfig", "f-button", "f-shareinfo",
    "f-playoptions",
    "types", "customer-config", "errors", "faq",
})

# The English guide's mission map ("Mission N · <title>" rows under #mission-map), 2026-11-04.
# Used unless --guide-html includes the English page.
GUIDE_MISSION_TITLES = {
    1: "Launch the Player Directly",
    2: "Nudge-Style Preview",
    3: "Keep Watching in PIP",
    4: "Launch via Deep Link",
    5: "Connect User Information",
    6: "Events · Products · Coupons",
    7: "Add Inline Previews to a List Screen",
    8: "UI Customization & Placement",
    9: "Broadcasting",
}

GUIDE_HOSTS = {"sdk.shoplive.cloud", "developer.shoplive.cloud"}
GUIDE_PATH_RE = re.compile(r"^(?:/mobile)?/?(?:shoplive-v3-integration-guide-(?:ko|en|ja)\.html)?$")

# Source sets per snippet language. Build output and dependency caches are skipped.
SOURCES = {
    "swift": ("iOS", (".swift",)),
    "kotlin": ("Android", (".kt", ".kts")),
}
SKIP_DIRS = {"build", ".build", ".gradle", "Pods", "DerivedData", ".idea", ".swiftpm"}
LANG_ALIASES = {"swift": "swift", "kotlin": "kotlin", "kt": "kotlin", "kts": "kotlin"}

# Framework / language names a snippet may use although this repo's sources do not.
# Keep it short: a name belongs here only if it is genuinely outside the repo (UIKit,
# Foundation, Android, Kotlin stdlib) — never an SDK or demo name, which must be grepable.
FRAMEWORK_NAMES = frozenset({
    # Swift / Foundation / UIKit
    "print", "self", "Self", "super", "nil", "true", "false", "init", "deinit", "some", "any",
    "String", "Int", "Bool", "Double", "CGFloat", "Void", "Any", "AnyObject", "URL", "Data",
    "Error", "Optional", "Array", "Dictionary", "Set", "NSObject", "Notification",
    "NotificationCenter", "DispatchQueue", "UIViewController", "UIView", "UIApplication",
    "UIImage", "UIColor", "UIFont", "UIWindow", "UIWindowScene", "UIScene", "WKWebView",
    "WKUserContentController", "WKScriptMessage", "WKScriptMessageHandler",
    # Kotlin / Android
    "it", "this", "null", "Unit", "Boolean", "Long", "Float", "List", "Map", "MutableList",
    "Activity", "Context", "Intent", "Bundle", "Uri", "View", "ViewGroup", "Log", "Toast",
    "WebView", "JavascriptInterface", "Handler", "Looper",
    # SwiftPM manifest (Package.swift snippets)
    "Package", "package", "product", "target", "dependencies",
})

# SDK names a snippet may spell out although the demo sources never do (they rely on type
# inference, e.g. `status: .show`). Each one was checked against the SDK 3.0.4 binaries on
# 2026-11-04 (iOS ShoplivePlayerSDK .swiftinterface). Add a name only after the same check.
SDK_NAMES = {
    "swift": frozenset({"ShopliveResultStatus", "ShopliveResultAlertType"}),
    "kotlin": frozenset(),
}

# Unqualified Swift calls that are also UIKit/Foundation methods a snippet calls on `self`
# (e.g. `present(vc, animated:)`), so a same-named repo function says nothing about them.
SWIFT_AMBIGUOUS_CALLS = frozenset({"present", "dismiss", "play", "stop", "reload", "send", "log"})

# `MyPlayerDelegate`, `myDelegate` … — a snippet's stand-in for the reader's own code.
PLACEHOLDER_RE = re.compile(r"^[Mm]y[A-Z]")

SWIFT_KEYWORDS = frozenset("""
    associatedtype class deinit enum extension fileprivate func import init inout internal let
    open operator private protocol public rethrows static struct subscript typealias var break
    case continue default defer do else fallthrough for guard if in repeat return switch where
    while as catch is super throw throws try async await weak unowned lazy final override
    mutating nonmutating convenience required optional dynamic indirect get set willSet didSet
    escaping autoclosure discardableResult objc main available unknown MainActor Sendable
""".split())
KOTLIN_KEYWORDS = frozenset("""
    as break class continue do else false for fun if in interface is null object package return
    super this throw true try typealias typeof val var when while by catch constructor delegate
    dynamic field file finally get import init param property receiver set setparam where
    actual abstract annotation companion const crossinline data enum expect external final
    infix inline inner internal lateinit noinline open operator out override private protected
    public reified sealed suspend tailrec vararg value it lazy also apply let run with
""".split())

LINK_RE = re.compile(r"(!?)\[((?:[^\[\]]|\[[^\]]*\])*)\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
REF_DEF_RE = re.compile(r"^\s{0,3}\[[^\]]+\]:\s*<?(\S+?)>?(?:\s|$)")
URL_RE = re.compile(r"https?://[^\s)<>\]\"'`]+")
BARE_ANCHOR_RE = re.compile(r"(?<![\w/.#-])#(m\d+(?:-[a-z0-9]+)*)\b")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")
HTML_ANCHOR_RE = re.compile(r"<a\s+(?:id|name)=\"([^\"]+)\"")
FENCE_RE = re.compile(r"^\s*(```|~~~)\s*([A-Za-z0-9_+-]*)")
INLINE_CODE_RE = re.compile(r"(`+)(.+?)\1")
MISSION_FILE_RE = re.compile(r"^mission-(\d\d)-.+\.md$")
ABBREVIATION = ("…",)

SCOPE = ("scope: links · #anchors · guide anchors · mission H1 ↔ guide titles · snippet names vs. code "
         "(comments/strings stripped) · Type.member · repo calls (Swift labels, Kotlin arg count/names) — "
         "limits: lowercase-receiver calls and SDK signatures not checked; any fitting overload passes; "
         "\"…\" abbreviations skipped; prose inline code not checked")


class Problems:
    def __init__(self) -> None:
        self.items: list[str] = []

    def add(self, path: Path, line: int, kind: str, message: str) -> None:
        self.items.append(f"{path.relative_to(ROOT)}:{line}: [{kind}] {message}")


# ── Guide ────────────────────────────────────────────────────────────────────

def guide_from_html(paths: list[Path]) -> tuple[frozenset[str], dict[int, str]]:
    """Anchor ids present in every page given, and the mission-map titles of the English page."""
    ids: set[str] | None = None
    titles: dict[int, str] = {}
    for path in paths:
        page = path.read_text(encoding="utf-8")
        found = set(re.findall(r'\bid="([A-Za-z0-9_-]+)"', page))
        ids = found if ids is None else ids & found
        lang = re.search(r'<html[^>]*\blang="([a-zA-Z-]+)"', page)
        if lang and lang.group(1).lower().startswith("en"):
            start, end = page.find('id="mission-map"'), page.find('id="upgrade-304"')
            section = page[start:end] if start != -1 else page
            for number, title in re.findall(r"Mission (\d+) · ([^<]+)<", section):
                titles.setdefault(int(number), htmllib.unescape(title).strip())
    return frozenset(ids or ()), titles


# ── Markdown parsing ──────────────────────────────────────────────────────────

class Doc:
    """One markdown file split into prose lines and fenced code blocks."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self.text = path.read_text(encoding="utf-8")
        self.prose: list[tuple[int, str]] = []          # (line number, text)
        self.blocks: list[tuple[int, str, str]] = []    # (first line, language, code)
        self._split()
        self._anchors: set[str] | None = None

    def _split(self) -> None:
        fence = None
        lang = ""
        start = 0
        buf: list[str] = []
        for number, line in enumerate(self.text.splitlines(), start=1):
            m = FENCE_RE.match(line)
            if fence is None:
                if m:
                    fence, lang, start, buf = m.group(1), m.group(2).lower(), number, []
                else:
                    self.prose.append((number, line))
            elif line.strip().startswith(fence):
                self.blocks.append((start, lang, "\n".join(buf)))
                fence = None
            else:
                buf.append(line)

    @property
    def anchors(self) -> set[str]:
        if self._anchors is None:
            seen: dict[str, int] = {}
            anchors: set[str] = set()
            for _, line in self.prose:
                m = HEADING_RE.match(line)
                if m:
                    slug = github_slug(m.group(2))
                    count = seen.get(slug, 0)
                    seen[slug] = count + 1
                    anchors.add(slug if count == 0 else f"{slug}-{count}")
                anchors.update(HTML_ANCHOR_RE.findall(line))
            self._anchors = anchors
        return self._anchors


def github_slug(heading: str) -> str:
    """GitHub's heading id: rendered text, lowercased, punctuation dropped, spaces → '-'."""
    text = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", heading)   # links → their text
    text = re.sub(r"<[^>]+>", "", text)                          # inline HTML
    text = text.replace("`", "")
    out = []
    for ch in text.lower():
        if "︀" <= ch <= "️":     # emoji variation selectors go with the emoji
            continue
        if ch.isalnum() or ch in "-_" or unicodedata.category(ch).startswith("M"):
            out.append(ch)
        elif ch == " ":
            out.append("-")
    return "".join(out)


def strip_inline_code(line: str) -> str:
    return INLINE_CODE_RE.sub(lambda m: " " * len(m.group(0)), line)


# ── 1–3. Links, anchors, mission pages ───────────────────────────────────────

def is_guide(url: str) -> tuple[bool, str]:
    parts = urlsplit(url)
    if parts.hostname not in GUIDE_HOSTS:
        return False, ""
    if not GUIDE_PATH_RE.match(parts.path):
        return False, ""
    return True, parts.fragment


def check_links(doc: Doc, docs: dict[Path, Doc], anchors: frozenset[str], problems: Problems) -> set[str]:
    """Checks every link in `doc`; returns the guide anchors it links to."""
    guide_anchors: set[str] = set()

    # Guide URLs anywhere, code blocks included (a comment can carry a stale anchor too).
    for number, line in enumerate(doc.text.splitlines(), start=1):
        for url in URL_RE.findall(line):
            guide, fragment = is_guide(url.rstrip(".,;:"))
            if not guide or not fragment:
                continue
            guide_anchors.add(fragment)
            if fragment not in anchors:
                problems.add(doc.path, number, "guide-anchor", f"{url} — the guide has no #{fragment}")

    for number, raw in doc.prose:
        line = strip_inline_code(raw)
        targets = [m.group(3) for m in LINK_RE.finditer(line)]
        ref = REF_DEF_RE.match(line)
        if ref:
            targets.append(ref.group(1))
        for target in targets:
            check_relative(doc, number, target, docs, problems)

        # Bare mentions such as "guide #m3-pipstart" — prose and inline code alike.
        for anchor in BARE_ANCHOR_RE.findall(raw):
            guide_anchors.add(anchor)
            if anchor not in anchors:
                problems.add(doc.path, number, "guide-anchor", f"#{anchor} — the guide has no such section")
    return guide_anchors


def check_relative(doc: Doc, line: int, target: str, docs: dict[Path, Doc], problems: Problems) -> None:
    if re.match(r"^[a-z][a-z0-9+.-]*:", target, re.I):    # http:, https:, mailto:, tel: …
        return
    path_part, _, fragment = target.partition("#")
    if not path_part:
        if fragment and unquote(fragment).lower() not in doc.anchors:
            problems.add(doc.path, line, "anchor", f"#{fragment} — no such heading in this file")
        return
    resolved = (doc.path.parent / unquote(path_part)).resolve()
    if not resolved.exists():
        shown = resolved.relative_to(ROOT) if resolved.is_relative_to(ROOT) else resolved
        problems.add(doc.path, line, "link", f"{target} — {shown} does not exist")
        return
    if fragment and resolved.suffix == ".md":
        target_doc = docs.get(resolved) or Doc(resolved)
        if unquote(fragment).lower() not in target_doc.anchors:
            problems.add(doc.path, line, "anchor", f"{target} — no heading #{fragment} in {resolved.name}")


def check_mission_page(doc: Doc, guide_anchors: set[str], titles: dict[int, str], problems: Problems) -> None:
    m = MISSION_FILE_RE.match(doc.path.name)
    if not m or doc.path.parent.name != "docs":
        return
    number = int(m.group(1))
    own = f"m{number}"
    if not any(a == own or a.startswith(own + "-") for a in guide_anchors):
        problems.add(doc.path, 1, "mission", f"links no guide #{own} — the file number and the guide mission disagree")
    title = titles.get(number)
    first = doc.text.splitlines()[0] if doc.text else ""
    expected = f"# Mission {number} — {title}"
    if title and first.strip() != expected:
        problems.add(doc.path, 1, "mission", f"H1 is \"{first.strip()}\" — the guide's mission map says \"{expected}\"")


# ── 4–6. Snippet symbols and signatures ──────────────────────────────────────

@dataclass
class Param:
    label: str | None          # Swift: external label (None = `_`); Kotlin: parameter name
    has_default: bool
    variadic: bool
    is_function: bool


@dataclass
class Decl:
    name: str                   # function name, or the type name for an initializer
    owner: str | None           # enclosing type (None at top level)
    params: list[Param]
    path: Path
    is_init: bool = False

    def shape(self, lang: str) -> str:
        if lang == "swift":
            return f"{self.name}(" + "".join(f"{p.label or '_'}:" for p in self.params) + ")"
        return f"{self.name}(" + ", ".join(p.label or "?" for p in self.params) + ")"


DEFAULT_EQ = re.compile(r"(?<![=!<>])=(?![=>])")


def parse_params(text: str, spans: list[tuple[int, int]], lang: str) -> list[Param] | None:
    params = []
    for a, b in spans:
        part = text[a:b].strip()
        if any(mark in part for mark in ABBREVIATION):
            return None
        colon = _top_level_index(part, ":")
        if colon == -1:
            return None
        head, rest = part[:colon], part[colon + 1:]
        default_at = _top_level_regex(rest, DEFAULT_EQ)
        type_text = rest if default_at == -1 else rest[:default_at]
        words = re.findall(r"[A-Za-z_]\w*", re.sub(r"@\w+(\([^)]*\))?", "", head))
        if lang == "swift":
            if not words:
                return None
            label = None if words[0] == "_" else words[0]
            if head.strip().startswith("_"):
                label = None
            variadic = type_text.strip().endswith("...")
        else:
            modifiers = {"val", "var", "private", "public", "internal", "protected", "override", "vararg",
                         "crossinline", "noinline", "open", "final"}
            names = [w for w in words if w not in modifiers]
            if not names:
                return None
            label = names[-1]
            variadic = "vararg" in words
        params.append(Param(label, default_at != -1, variadic, "->" in type_text))
    return params


def _top_level_index(text: str, char: str) -> int:
    depth = 0
    for i, c in enumerate(text):
        if c in "([{<":
            depth += 1
        elif c in ")]}>":
            depth -= 1
        elif c == char and depth == 0:
            return i
    return -1


def _top_level_regex(text: str, pattern: re.Pattern[str]) -> int:
    depth = 0
    for i, c in enumerate(text):
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif depth == 0 and pattern.match(text, i):
            return i
    return -1


TYPE_DECL = {
    "swift": re.compile(r"\b(?:class|struct|enum|protocol|actor|extension)\s+([A-Z]\w*)"),
    "kotlin": re.compile(r"\b(?:class|object|interface)\s+([A-Z]\w*)"),
}
FUNC_DECL = {
    "swift": re.compile(r"\bfunc\s+([A-Za-z_]\w*)\s*(?:<[^>()]*>)?\s*\(|\b(init)\s*[?!]?\s*(?:<[^>()]*>)?\s*\("),
    "kotlin": re.compile(r"\bfun\s+(?:<[^>]*>\s*)?(?:[\w.<>?]+\.)?([A-Za-z_]\w*)\s*\(|\bclass\s+([A-Z]\w*)\s*(?:<[^>]*>)?\s*(?:(?:private|internal|public|protected)\s+)?(?:constructor\s*)?\("),
}


def scan_declarations(text: str, skeleton: str, lang: str, path: Path) -> list[Decl]:
    """Functions and initializers in one source text, with their enclosing type."""
    # Enclosing types: a type declaration opens a scope at its next '{'.
    scopes: list[tuple[int, int, str]] = []          # (open index, close index, type name)
    for match in TYPE_DECL[lang].finditer(skeleton):
        brace = skeleton.find("{", match.end())
        if brace == -1:
            continue
        end = close_paren(skeleton, brace)
        scopes.append((brace, end or len(skeleton), match.group(1)))

    def owner_at(index: int) -> str | None:
        inner = [s for s in scopes if s[0] < index < s[1]]
        return min(inner, key=lambda s: s[1] - s[0])[2] if inner else None

    decls = []
    for match in FUNC_DECL[lang].finditer(skeleton):
        open_paren = match.end() - 1
        spans = split_args(skeleton, open_paren)
        if spans is None:
            continue
        params = parse_params(text, spans, lang)
        if params is None:
            continue
        if lang == "swift" and match.group(2) == "init":
            owner = owner_at(match.start())
            if owner:
                decls.append(Decl(owner, owner, params, path, is_init=True))
        elif lang == "kotlin" and match.group(2):
            decls.append(Decl(match.group(2), match.group(2), params, path, is_init=True))
        else:
            decls.append(Decl(match.group(1), owner_at(match.start()), params, path))
    return decls


class Corpus:
    """One platform's sources as code only: identifiers, repo types, and declarations."""

    def __init__(self, lang: str) -> None:
        directory, suffixes = SOURCES[lang]
        self.lang = lang
        self.words: set[str] = set()
        self.type_files: dict[str, set[Path]] = {}
        self.file_words: dict[Path, set[str]] = {}
        self.decls: dict[str, list[Decl]] = {}
        declared: dict[str, set[Path]] = {}
        extended: dict[str, set[Path]] = {}
        for path in sorted((ROOT / directory).rglob("*")):
            if path.suffix not in suffixes or not path.is_file():
                continue
            if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
                continue
            no_comments, skeleton = mask(path.read_text(encoding="utf-8", errors="replace"), lang)
            words = set(re.findall(r"[A-Za-z_]\w*", skeleton))
            self.file_words[path] = words
            self.words |= words
            for match in TYPE_DECL[lang].finditer(skeleton):
                kind = skeleton[match.start():match.start() + 9]
                (extended if kind.startswith("extension") else declared).setdefault(match.group(1), set()).add(path)
            for decl in scan_declarations(no_comments, skeleton, lang, path):
                self.decls.setdefault(decl.name, []).append(decl)
        for name, files in declared.items():
            self.type_files[name] = files | extended.get(name, set())   # extensions of repo types only

    def has_member(self, type_name: str, member: str) -> bool:
        return any(member in self.file_words[f] for f in self.type_files[type_name])


def swift_call_fits(labels: list[str | None], trailing: bool, params: list[Param]) -> bool:
    i, last_variadic = 0, None
    for label in labels:
        if label is None and last_variadic is not None:
            continue                                # more values for the variadic parameter
        while i < len(params) and params[i].label != label:
            if not (params[i].has_default or params[i].variadic):
                return False
            i += 1
        if i == len(params):
            return False
        last_variadic = i if params[i].variadic else None
        i += 1
    rest = params[i:]
    if trailing:
        closures = [k for k, p in enumerate(rest) if p.is_function]
        if not closures:
            return False
        rest = rest[:closures[-1]] + rest[closures[-1] + 1:]
    return all(p.has_default or p.variadic for p in rest)


def kotlin_call_fits(positional: int, named: list[str], trailing: bool, params: list[Param]) -> bool:
    filled: set[int] = set()
    i = 0
    for _ in range(positional):
        if i >= len(params):
            return False
        filled.add(i)
        if not params[i].variadic:
            i += 1
    names = [p.label for p in params]
    for name in named:
        if name not in names:
            return False
        filled.add(names.index(name))
    if trailing:
        if not params or len(params) - 1 in filled:
            return False
        filled.add(len(params) - 1)
    return all(k in filled or p.has_default or p.variadic for k, p in enumerate(params))


def declared_in_snippet(code: str, lang: str) -> set[str]:
    """Names the snippet itself introduces — illustrative customer code, not repo API."""
    if lang == "swift":
        patterns = [
            r"\b(?:let|var|func|class|struct|enum|protocol|typealias|case)\s+`?([A-Za-z_]\w*)",
            r"\b(?:if|guard|while)\s+(?:let|var)\s+([A-Za-z_]\w*)",
            r"\bfor\s+(?:case\s+)?(?:let\s+)?([A-Za-z_]\w*)\s+in\b",
            r"\{\s*(?:\[[^\]]*\]\s*)?\(?([A-Za-z_][\w,\s]*?)\)?\s+in\b",
            r"\bcase\s+\.\w+\s*\(\s*let\s+([A-Za-z_]\w*)",
            r"\blet\s+\(?([A-Za-z_]\w*)",
            r"[(,]\s*(?:_\s+)?([a-z_]\w*)\s*:\s*[A-Z\[(@]",   # parameter names
        ]
    else:
        patterns = [
            r"\b(?:val|var|fun|class|object|interface|typealias)\s+(?:[A-Z][\w.]*\.)?`?([A-Za-z_]\w*)",
            r"\bfor\s*\(\s*([A-Za-z_]\w*)\s+in\b",
            r"\{\s*([A-Za-z_][\w,\s]*?)\s*->",
            r"[(,]\s*(?:private\s+|val\s+|var\s+)*([a-z_]\w*)\s*:\s*[A-Z(@]",   # parameter names
            r"\bcatch\s*\(\s*([A-Za-z_]\w*)",
        ]
    names: set[str] = set()
    for pattern in patterns:
        for match in re.findall(pattern, code):
            names.update(n.strip() for n in match.split(",") if n.strip())
    return names


CALL_RE = re.compile(r"(?<![\w$])((?:[A-Z]\w*\.)*)([A-Za-z_]\w*)\s*\(")


def check_signatures(doc: Doc, start: int, code: str, lang: str, corpus: Corpus,
                     local: set[str], problems: Problems) -> int:
    no_comments, skeleton = mask(code, lang)
    checked = 0

    def report(index: int, message: str) -> None:
        problems.add(doc.path, start + 1 + code.count("\n", 0, index), f"signature/{lang}", message)

    # A function the snippet declares under a repo name must match a repo declaration.
    declared_spans: set[int] = set()
    for decl in scan_declarations(no_comments, skeleton, lang, doc.path):
        candidates = [d for d in corpus.decls.get(decl.name, []) if d.is_init == decl.is_init]
        decl_index = skeleton.find(decl.name + "(") if not decl.is_init else -1
        if not candidates or decl.is_init:
            continue
        checked += 1
        key = (lambda d: [p.label for p in d.params])
        if not any(key(c) == key(decl) for c in candidates):
            shapes = ", ".join(sorted({c.shape(lang) for c in candidates}))
            report(max(decl_index, 0), f"declares {decl.shape(lang)} — the repo has {shapes}")
    for match in FUNC_DECL[lang].finditer(skeleton):
        declared_spans.add(match.end() - 1)

    # Calls to repo functions and initializers.
    for match in CALL_RE.finditer(skeleton):
        open_paren = match.end() - 1
        if open_paren in declared_spans:
            continue
        before = skeleton[:match.start()].rstrip()
        if before.endswith(".") or re.search(r"\b(func|fun|init|class|object)\s*$", before):
            continue                                # receiver.method(…) / a declaration
        qualifier = [q for q in match.group(1).split(".") if q]
        name = match.group(2)
        if name in local and not qualifier:
            continue
        qualifier = [q for q in qualifier if q not in ("shared", "default", "Companion")]
        owner = qualifier[-1] if qualifier else None
        if name[0].isupper():
            candidates = [d for d in corpus.decls.get(name, []) if d.is_init]
            if not candidates and name in corpus.type_files:
                candidates = [Decl(name, name, [], doc.path, is_init=True)] if lang == "swift" else []
        elif owner:
            if owner not in corpus.type_files:
                continue
            candidates = [d for d in corpus.decls.get(name, []) if not d.is_init and d.owner == owner]
            if not candidates:
                continue                            # member check (5) reports unknown members
        else:
            if lang == "swift" and name in SWIFT_AMBIGUOUS_CALLS:
                continue
            candidates = [d for d in corpus.decls.get(name, []) if not d.is_init]
        if not candidates:
            continue
        spans = split_args(skeleton, open_paren)
        if spans is None:
            continue
        args = [no_comments[a:b].strip() for a, b in spans]
        if any(mark in arg for arg in args for mark in ABBREVIATION):
            continue
        end = close_paren(skeleton, open_paren) or open_paren
        trailing = skeleton[end:].lstrip().startswith("{")
        checked += 1
        shown = ".".join(qualifier + [name])
        if lang == "swift":
            labels = [m.group(1) if (m := re.match(r"^([A-Za-z_]\w*)\s*:(?!:)", arg)) else None for arg in args]
            if not any(swift_call_fits(labels, trailing, c.params) for c in candidates):
                call = f"{shown}(" + "".join(f"{l or '_'}:" for l in labels) + ")"
                shapes = ", ".join(sorted({c.shape(lang) for c in candidates}))
                report(match.start(), f"{call} fits no repo declaration — the repo has {shapes}")
        else:
            named = [m.group(1) for arg in args if (m := re.match(r"^([A-Za-z_]\w*)\s*=(?!=)", arg))]
            positional = len(args) - len(named)
            if not any(kotlin_call_fits(positional, named, trailing, c.params) for c in candidates):
                shapes = ", ".join(sorted({c.shape(lang) for c in candidates}))
                report(match.start(), f"{shown}(…) with {len(args)} argument(s){' + trailing lambda' if trailing else ''}"
                                      f"{(' named ' + ', '.join(named)) if named else ''} fits no repo declaration — "
                                      f"the repo has {shapes}")
    return checked


def check_snippets(doc: Doc, corpora: dict[str, Corpus], problems: Problems) -> tuple[int, int]:
    names_checked = signatures_checked = 0
    for start, lang_tag, code in doc.blocks:
        lang = LANG_ALIASES.get(lang_tag)
        if lang is None:
            continue
        corpus = corpora[lang]
        keywords = SWIFT_KEYWORDS if lang == "swift" else KOTLIN_KEYWORDS
        _, body = mask(code, lang)                   # names in comments or string text are not API
        local = declared_in_snippet(body, lang)
        reported: set[str] = set()

        def report(name: str, why: str, offset_text: str) -> None:
            if name in reported:
                return
            reported.add(name)
            line = start + 1 + code[: max(code.find(offset_text), 0)].count("\n")
            problems.add(doc.path, line, f"symbol/{lang}", why)

        # Types and constants, member names, called functions.
        names = set(re.findall(r"\b([A-Z][A-Za-z0-9_]{2,})\b", body))
        names |= set(re.findall(r"\.([A-Za-z_]\w+)", body))
        names |= set(re.findall(r"\b([a-z_]\w+)\s*(?=\()", body))
        for name in sorted(names):
            if (name in local or name in keywords or name in FRAMEWORK_NAMES or name in SDK_NAMES[lang]
                    or PLACEHOLDER_RE.match(name)):
                continue
            names_checked += 1
            if name not in corpus.words:
                report(name, f"`{name}` does not occur as code in the {SOURCES[lang][0]}/ sources", name)

        # Type.member (also Type.shared.member) on a type this repo declares.
        for type_name, member in re.findall(r"\b([A-Z]\w*)(?:\.(?:shared|default|Companion))?\.([A-Za-z_]\w*)", body):
            if type_name not in corpus.type_files or type_name in local:
                continue
            if not corpus.has_member(type_name, member):
                files = ", ".join(sorted(f.name for f in corpus.type_files[type_name]))
                report(f"{type_name}.{member}", f"`{type_name}.{member}` — no `{member}` in {files}", member)

        signatures_checked += check_signatures(doc, start, code, lang, corpus, local, problems)
    return names_checked, signatures_checked


# ── Driver ───────────────────────────────────────────────────────────────────

def collect(args: list[str]) -> list[Path]:
    patterns = args or DEFAULT_DOCS
    paths: list[Path] = []
    for pattern in patterns:
        matches = sorted(ROOT.glob(pattern)) if any(c in pattern for c in "*?[") else [ROOT / pattern]
        for path in matches:
            path = path.resolve()
            if path.is_file() and path not in paths:
                paths.append(path)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("files", nargs="*", help="markdown files relative to the repo root (default: README + docs)")
    parser.add_argument("--guide-html", nargs="+", type=Path, metavar="FILE",
                        help="integration guide pages; anchors must exist in all of them, mission titles "
                             "come from the English one (default: the constants in this file)")
    parser.add_argument("-v", "--verbose", action="store_true", help="list every file checked")
    options = parser.parse_args()

    anchors, titles, source = GUIDE_ANCHORS, GUIDE_MISSION_TITLES, "built-in list"
    if options.guide_html:
        html_anchors, html_titles = guide_from_html(options.guide_html)
        anchors, source = html_anchors, f"{len(options.guide_html)} HTML page(s)"
        if html_titles:
            titles = html_titles
        else:
            print("docs_link_check: no English page among --guide-html — mission titles from the built-in list")
    print(f"{SCOPE} · guide ids: {len(anchors)} from {source}")

    paths = collect(options.files)
    if not paths:
        print("docs_link_check: no markdown files found", file=sys.stderr)
        return 1
    docs = {p: Doc(p) for p in paths}
    corpora = {lang: Corpus(lang) for lang in SOURCES}
    problems = Problems()

    names = signatures = 0
    for path, doc in docs.items():
        guide_anchors = check_links(doc, docs, anchors, problems)
        check_mission_page(doc, guide_anchors, titles, problems)
        n, s = check_snippets(doc, corpora, problems)
        names += n
        signatures += s
        if options.verbose:
            print(f"checked {path.relative_to(ROOT)}")

    for item in problems.items:
        print(item)
    status = "FAIL" if problems.items else "OK"
    print(f"docs_link_check: {status} — {len(paths)} files, {names} snippet names, {signatures} repo signatures, "
          f"{len(problems.items)} problem(s)")
    return 1 if problems.items else 0


if __name__ == "__main__":
    sys.exit(main())

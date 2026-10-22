#!/usr/bin/env python3
"""Fails the build when the copy-paste layer depends on the demo harness.

Everything under integration/ is meant to be copied into a customer app as-is.
That claim rots the moment somebody adds one convenient log line, so it is
checked mechanically instead of in review.

The Gradle module already stops hard dependencies from compiling (R, BuildConfig,
demo classes). This catches what compiles fine and still hurts a customer: a
logger they do not use, a DI framework they did not choose, Compose in an
XML project, comments they cannot read.

Comments are stripped before matching: describing the harness in prose is fine
and useful ("in the demo this ends up in the event log"). Only code counts.

Usage:  python3 scripts/integration_boundary_scanner.py [source_root]
Exit:   0 clean, 1 violations found.
"""

import re
import sys
from pathlib import Path

DEFAULT_ROOT = "integration/src/main/java"

# Hard-coded on purpose. Deriving the list from the demo's symbols produces false
# positives on ordinary words and silently stops covering new leaks.
FORBIDDEN = [
    # ── This app's harness ──────────────────────────────────────────────────
    (r"\bcloud\.shoplive\.onboarding\.(?!integration)",
     "imports the demo app; :integration must only reference the SDK"),
    (r"\bDemoLog\b", "use shopliveLog(...) instead of the demo's logger"),
    (r"\bDemoContainer\b", "take what you need as a parameter, not from a locator"),
    (r"\bDemoOptions(Store)?\b", "demo screen state; take a configuration parameter"),
    (r"\bDemoConfigurationFactory\b", "demo-only assembly; see ShoplivePlayerPresets"),
    (r"\bDemoLabels\b", "return an enum and let the host app localize it"),
    (r"\bMissionProgress\b", "report a ShopliveMilestone instead"),
    (r"\bProductRouter\b", "call the onNavigation callback instead"),
    (r"\bCredentialStore\b", "take keys as parameters"),
    (r"\bLocaleSetting\b", "the host app owns localization"),
    (r"\bDemoApplication\b", "a customer's Application class is a different one"),

    # ── Android-specific leaks ──────────────────────────────────────────────
    (r"\bR\.(string|drawable|layout|id|color|dimen|raw|plurals)\b",
     "the customer app has no such resource id; pass a value or an Int in"),
    (r"\bBuildConfig\b", "generated per module; inject the value as a parameter"),
    (r"\bandroid\.util\.Log\b|(?<![\w.])Log\.[dwiev]\(",
     "use shopliveLog(...); the customer has their own logger"),
    (r"\bTimber\b", "third-party logger; use shopliveLog(...)"),
    (r"@AndroidEntryPoint\b|@HiltAndroidApp\b|@Inject\b|\bby\s+inject\(",
     "do not force a DI framework; use constructor parameters with defaults"),
    (r"@Composable\b|\bandroidx\.compose\b",
     "the customer app may not use Compose; keep this layer View/plain Kotlin"),
    (r"\b\w+Binding\b", "ViewBinding ties this to a harness layout"),
    (r"\bdagger\b|\borg\.koin\b|\bjavax\.inject\b", "do not force a DI framework"),
]

# Korean is the giveaway for this project; the rule is "comments in English".
NON_ENGLISH = (r"[가-힣぀-ヿ一-鿿]",
               "write comments in English; customers read these files")

BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
LINE_COMMENT = re.compile(r"//[^\n]*")


def strip_comments(text: str) -> str:
    """Blanks comments but keeps line numbering intact."""
    def blank(match):
        return re.sub(r"[^\n]", " ", match.group(0))

    return LINE_COMMENT.sub(blank, BLOCK_COMMENT.sub(blank, text))


def scan(root: Path):
    violations = []
    files = sorted(root.rglob("*.kt")) + sorted(root.rglob("*.java"))

    for path in files:
        raw = path.read_text(encoding="utf-8")
        code = strip_comments(raw)

        for line_no, line in enumerate(code.splitlines(), start=1):
            for pattern, hint in FORBIDDEN:
                found = re.search(pattern, line)
                if found:
                    violations.append((path, line_no, found.group(0).strip(), hint))

        # Non-English is checked against the raw text: comments are the point.
        for line_no, line in enumerate(raw.splitlines(), start=1):
            found = re.search(NON_ENGLISH[0], line)
            if found:
                violations.append((path, line_no, found.group(0), NON_ENGLISH[1]))

    return files, violations


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_ROOT)
    if not root.is_dir():
        print(f"[boundary] FAIL — source root not found: {root}")
        return 1

    files, violations = scan(root)

    if not violations:
        print(f"[boundary] PASS — 0 harness dependencies in {len(files)} files. "
              f"{root} is copy-ready.")
        return 0

    print(f"[boundary] FAIL — {len(violations)} violation(s) in {root}:\n")
    for path, line_no, symbol, hint in violations:
        print(f"  {path}:{line_no}: {symbol}\n      -> {hint}")
    print("\nEverything in this directory is copied into customer apps. It may only")
    print("reference the Shoplive SDK and the standard framework. If you need")
    print("something from the demo, take it as a parameter or a callback.")
    return 1


if __name__ == "__main__":
    sys.exit(main())

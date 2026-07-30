#!/usr/bin/env python3
"""Boundary scanner for ShopliveIntegration/ — keeps the "copy it and it just works" promise in CI.

Files inside ShopliveIntegration/ may reference only the SDK
(ShopliveCore / ShoplivePlayerSDK / ShopliveStreamerSDK), the standard frameworks, and other symbols
inside Integration/ itself.
Referencing the demo harness (EventLog, DemoTheme, L(), ...) breaks compilation the moment someone
copies the file out.

Without this scanner the same problem is guaranteed to come back — dropping in one log line is simply
too easy.

Usage:  python3 scripts/integration_boundary_scanner.py [target-directory]
Exit:   0 = pass · 1 = violations found
"""

import re
import sys
from pathlib import Path

# Symbols that belong to the demo harness — their presence in Integration/ is a violation.
FORBIDDEN = [
    "EventLog",
    "DemoCredentials",
    "DemoConfigStore",
    "DemoConfigBuilder",
    "DemoAuthApplier",
    "DemoBootstrap",
    "MissionProgress",
    "MissionCatalog",
    "DemoTheme",
    "DemoTipView",
    "DemoNavBar",
    "DemoFab",
    "DemoButton",
    "DemoToast",
    "DevSheetViewController",
    "PlayerHostViewController",
    "MissionListViewController",
    "StartViewController",
    "ProductDetailViewController",
    "FeedDemoViewController",
]

# The localization helper L("...") depends on the harness's DemoStrings.
LOCALIZE = re.compile(r'(?<![A-Za-z0-9_])L\s*\(\s*"')


def strip_comments(source: str) -> str:
    """Comments are not violations — mentioning the harness in prose is fine."""
    out, in_block = [], False
    for line in source.split("\n"):
        stripped = line.strip()
        if in_block:
            if "*/" in stripped:
                in_block = False
            continue
        if stripped.startswith("/*"):
            if "*/" not in stripped:
                in_block = True
            continue
        if stripped.startswith("//"):
            continue
        out.append(re.sub(r"//.*$", "", line))
    return "\n".join(out)


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "ShopliveIntegration")
    files = sorted(root.rglob("*.swift"))

    print(f"[boundary] scanning ShopliveIntegration/ — {root} · {len(files)} .swift file(s)")
    if not files:
        print("[boundary] FAIL — no target files found (check the path).")
        return 1

    violations = []
    for path in files:
        code = strip_comments(path.read_text(encoding="utf-8"))
        for lineno, line in enumerate(code.split("\n"), start=1):
            for symbol in FORBIDDEN:
                if re.search(rf"(?<![A-Za-z0-9_]){re.escape(symbol)}(?![A-Za-z0-9_])", line):
                    violations.append((path, lineno, symbol, line.strip()))
            if LOCALIZE.search(line):
                violations.append((path, lineno, 'L("…") localization helper', line.strip()))

    if violations:
        print(f"[boundary] FAIL — found {len(violations)} harness dependency/-ies:")
        for path, lineno, symbol, snippet in violations:
            print(f"  {path}:{lineno}: '{symbol}'  |  {snippet[:90]}")
        print()
        print("  Integration/ is the layer integrators copy verbatim.")
        print("  If you need logging use shopliveLog(_:_:); if you need a value, take a parameter.")
        print("  Move demo-only logic into Screens/, Support/, or App/.")
        return 1

    print("[boundary] PASS — 0 harness dependencies. Integration/ is copy-ready.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

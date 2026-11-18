#!/usr/bin/env bash
# logic_check.sh — compiles the Foundation-only logic with swiftc on the Mac and runs the checks.
# (SMV-1922 S37 · M6 — the iOS project has no XCTest target.)
#
# Usage:  iOS/scripts/logic_check.sh        (from anywhere)
# Exit:   0 = every check passed · 1 = a check failed · 2 = compile error
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/logic_check.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

SOURCES=(
  "$IOS_DIR/ShopliveOnboardingDemo/Support/MissionID.swift"
  "$IOS_DIR/ShopliveIntegration/WebBridgeInput.swift"
  "$IOS_DIR/scripts/logic_check/main.swift"
)

echo "[logic_check] swiftc $(swiftc --version 2>&1 | head -1)"
for s in "${SOURCES[@]}"; do echo "[logic_check]   $s"; done

if ! xcrun --sdk macosx swiftc -O -o "$BUILD_DIR/logic_check" "${SOURCES[@]}"; then
  echo "[logic_check] COMPILE FAILED"
  exit 2
fi
"$BUILD_DIR/logic_check"

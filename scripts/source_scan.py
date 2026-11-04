"""Shared source scanning for scripts/docs_link_check.py and scripts/format_args_check.py.

Swift and Kotlin only, and only what those two checks need: blank out comments and string
text (keeping string interpolation, which is code), and split a call's top-level arguments.
Standard library only.
"""

from __future__ import annotations


def mask(src: str, lang: str) -> tuple[str, str]:
    """Returns (comments blanked, comments and string text blanked) — both the length of `src`.

    `lang` is "swift" or "kotlin". Interpolation (`\\(…)` / `${…}`) is kept in both results, so a
    call written inside an interpolation is still seen. Line breaks are kept, so line numbers hold.
    """
    n = len(src)
    no_comments = list(src)
    skeleton = list(src)

    def blank(arr: list[str], a: int, b: int) -> None:
        for k in range(a, min(b, n)):
            if arr[k] != "\n":
                arr[k] = " "

    def block_comment_end(i: int) -> int:          # both languages nest block comments
        depth, j = 0, i
        while j < n:
            if src.startswith("/*", j):
                depth += 1
                j += 2
            elif src.startswith("*/", j):
                depth -= 1
                j += 2
                if depth == 0:
                    return j
            else:
                j += 1
        return n

    def code(i: int, stop: str | None) -> int:
        depth = 0
        while i < n:
            c = src[i]
            if stop and depth == 0 and c == stop:
                return i
            if src.startswith("//", i):
                j = src.find("\n", i)
                j = n if j == -1 else j
                blank(no_comments, i, j)
                blank(skeleton, i, j)
                i = j
                continue
            if src.startswith("/*", i):
                j = block_comment_end(i)
                blank(no_comments, i, j)
                blank(skeleton, i, j)
                i = j
                continue
            if c == '"':
                i = string(i)
                continue
            if c == "'" and lang == "kotlin":
                j = i + 1
                j += 2 if j < n and src[j] == "\\" else 1
                while j < n and src[j] not in "'\n":
                    j += 1
                blank(skeleton, i + 1, j)
                i = j + 1
                continue
            if stop:
                if c in "([{":
                    depth += 1
                elif c in ")]}":
                    depth -= 1
            i += 1
        return i

    def string(i: int) -> int:
        triple = src.startswith('"""', i)
        quote = '"""' if triple else '"'
        j = i + len(quote)
        segment = j
        while j < n:
            if src.startswith(quote, j):
                blank(skeleton, segment, j)
                return j + len(quote)
            c = src[j]
            if c == "\n" and not triple:
                blank(skeleton, segment, j)
                return j
            if lang == "swift" and c == "\\" and src.startswith("(", j + 1):
                blank(skeleton, segment, j)
                j = code(j + 2, ")") + 1
                segment = j
                continue
            if lang == "kotlin" and c == "$" and src.startswith("{", j + 1):
                blank(skeleton, segment, j)
                j = code(j + 2, "}") + 1
                segment = j
                continue
            if c == "\\" and not (lang == "kotlin" and triple):
                j += 2
                continue
            j += 1
        blank(skeleton, segment, j)
        return j

    code(0, None)
    return "".join(no_comments), "".join(skeleton)


def split_args(skeleton: str, open_paren: int) -> list[tuple[int, int]] | None:
    """Top-level argument spans of the call or declaration whose '(' is at `open_paren`.

    Works on a `mask()` skeleton, so commas and brackets inside strings or comments are already
    gone. A trailing comma does not add an empty argument. None if the parentheses do not close.
    """
    depth, start, spans = 0, open_paren + 1, []
    i = open_paren + 1
    while i < len(skeleton):
        c = skeleton[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                if c != ")":
                    return None
                if skeleton[start:i].strip():
                    spans.append((start, i))
                return spans
            depth -= 1
        elif c == "," and depth == 0:
            spans.append((start, i))
            start = i + 1
        i += 1
    return None


def close_paren(skeleton: str, open_paren: int) -> int | None:
    """Index just past the ')' matching the '(' at `open_paren`."""
    depth = 0
    for i in range(open_paren, len(skeleton)):
        c = skeleton[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return i + 1
    return None

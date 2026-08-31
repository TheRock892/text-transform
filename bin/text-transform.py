#!/usr/bin/env python3
"""Transform text read from stdin and write the result to stdout.

Usage: text-transform.py <upcase|downcase|capitalize>

Kept separate from the bash orchestrator so case conversion is a single,
testable, Unicode-correct function. Python 3 ships on every Omarchy system,
and its str case folding handles accents, umlauts, and non-Latin alphabets
that tr/awk would mangle.
"""

import re
import sys

MODES = ("upcase", "downcase", "capitalize")

WORD_RUN = re.compile(r"\S+")


def transform(text, mode):
    """Return `text` converted to `mode`. Never fails on empty input."""
    if mode == "upcase":
        return text.upper()
    if mode == "downcase":
        return text.lower()
    if mode == "capitalize":
        # Every whitespace-delimited token gets its first grapheme uppercased
        # and the rest lowercased, preserving inner punctuation and spaces:
        # "hello WORLD" -> "Hello World", "don't" stays "Don't".
        return WORD_RUN.sub(lambda m: m.group(0)[0].upper() + m.group(0)[1:].lower(), text)
    raise ValueError("unknown mode: %r (expected one of %s)" % (mode, ", ".join(MODES)))


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in MODES:
        print("usage: text-transform.py <%s>" % "|".join(MODES), file=sys.stderr)
        return 2
    print(transform(sys.stdin.read(), sys.argv[1]), end="")


if __name__ == "__main__":
    sys.exit(main())
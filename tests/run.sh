#!/usr/bin/env bash
# Test suite for the text-transform plugin. Run from the plugin root:
#   ./tests/run.sh
# Exits non-zero on the first failing assertion.

set -uo pipefail

PLUGIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
TRANSFORM="$PLUGIN_DIR/bin/text-transform.py"
CLI="$PLUGIN_DIR/bin/text-transform"
failures=0

note() { printf '%s\n' "$*"; }

check() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    note "ok   - $label"
  else
    note "FAIL - $label"
    note "       expected: $(printf '%q' "$expected")"
    note "       actual:   $(printf '%q' "$actual")"
    failures=$((failures + 1))
  fi
}

transform() {
  local mode="$1"
  local input="$2"
  printf '%s' "$input" | python3 "$TRANSFORM" "$mode"
}

note "== transform: upcase =="
check "upcase mixed ascii"        "HELLO WORLD"   "$(transform upcase "Hello World")"
check "upcase unicode accents"    "ÀÈÌÒÙ ÁÉ"      "$(transform upcase "àèìòù áé")"
check "upcase keeps punctuation"  "TEST!"         "$(transform upcase "test!")"

note "== transform: downcase =="
check "downcase mixed ascii"      "hello world"   "$(transform downcase "Hello World")"
check "downcase unicode"          "münchen"       "$(transform downcase "MÜNCHEN")"
check "downcase keeps newlines"   "two\nlines"    "$(transform downcase "Two\nLiNeS")"

note "== transform: capitalize =="
check "capitalize sentence"       "Hello World"        "$(transform capitalize "hello WORLD")"
check "capitalize single word"    "Test"               "$(transform capitalize "tEsT")"
check "capitalize apostrophe"     "Don't"              "$(transform capitalize "don't")"
check "capitalize preserves gap"  "A\nb  C"            "$(transform capitalize "a\nb  c")"
check "capitalize italic accented" "Accento Àscrito"    "$(transform capitalize "accento àscrito")"

note "== transform: errors =="
check "unknown mode exits non-zero" "2" "$(printf 'x' | python3 "$TRANSFORM" bogus >/dev/null 2>&1; echo $?)"
check "empty input stays empty"      ""  "$(transform upcase "")"

note "== transform: bounded input =="
oversized_len="$(head -c 200000 /dev/zero | tr '\0' 'a' | python3 "$TRANSFORM" upcase | wc -c)"
check "output capped at MAX_CHARS" "65536" "$oversized_len"

note "== CLI =="
[[ -x "$CLI" ]] && check "bin/text-transform is executable" "1" "1" \
  || { note "FAIL - bin/text-transform is executable"; failures=$((failures + 1)); }
[[ -f "$PLUGIN_DIR/bin/text-transform.py" ]] || { note "FAIL - transform script missing"; failures=$((failures + 1)); }
"$CLI" --help >/dev/null 2>&1 && check "cli --help exits 0" "0" "0" \
  || { note "FAIL - cli --help exits 0"; failures=$((failures + 1)); }

note "== manifest =="
if command -v omarchy-plugin-validate >/dev/null 2>&1 || command -v omarchy >/dev/null 2>&1; then
  if omarchy plugin validate "$PLUGIN_DIR" >/dev/null 2>&1; then
    check "omarchy plugin validate" "valid" "valid"
  else
    check "omarchy plugin validate" "valid" "invalid"
  fi
else
  note "skip - omarchy CLI not available; validate manually with: omarchy plugin validate ."
fi

note ""
if (( failures > 0 )); then
  note "$failures test(s) failed"
  exit 1
fi
note "All tests passed"
exit 0
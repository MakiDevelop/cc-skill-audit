#!/usr/bin/env bash
# Simple test runner for cc-skill-audit
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLI="$SCRIPT_DIR/../bin/cc-skill-audit"
FIXTURES="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

assert_exit_code() {
  local name="$1"
  local dir="$2"
  local expected="$3"

  "$CLI" "$dir" --fast 2>/dev/null
  actual=$?

  if [ "$actual" -eq "$expected" ]; then
    echo "  PASS  $name (expected=$expected, got=$actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (expected=$expected, got=$actual)"
    FAIL=$((FAIL + 1))
  fi
}

assert_output_contains() {
  local name="$1"
  local dir="$2"
  local pattern="$3"

  output=$("$CLI" "$dir" 2>/dev/null)
  if echo "$output" | grep -q "$pattern"; then
    echo "  PASS  $name (contains '$pattern')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $name (missing '$pattern')"
    FAIL=$((FAIL + 1))
  fi
}

echo "cc-skill-audit test suite"
echo "========================="
echo ""

echo "--- Fast mode (exit codes) ---"
assert_exit_code "clean-skill → GREEN (0)"      "$FIXTURES/clean-skill"      0
assert_exit_code "suspicious-skill → YELLOW (1)" "$FIXTURES/suspicious-skill" 1
assert_exit_code "malicious-skill → RED (2)"     "$FIXTURES/malicious-skill"  2

echo ""
echo "--- Full report content ---"
assert_output_contains "malicious: detects hardcoded keys"   "$FIXTURES/malicious-skill" "Hardcoded keys: yes"
assert_output_contains "malicious: detects sensitive reads"  "$FIXTURES/malicious-skill" ".ssh"
assert_output_contains "malicious: recommends do-not-install" "$FIXTURES/malicious-skill" "do-not-install"
assert_output_contains "suspicious: detects opt-in"          "$FIXTURES/suspicious-skill" "Opt-in: yes"
assert_output_contains "suspicious: recommends caution"      "$FIXTURES/suspicious-skill" "install-with-caution"
assert_output_contains "clean: recommends install"           "$FIXTURES/clean-skill"      "Risk Level: GREEN"

echo ""
echo "--- JSON mode ---"
JSON_OUT=$("$CLI" "$FIXTURES/malicious-skill" --json 2>/dev/null)
if echo "$JSON_OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['risk']=='RED'" 2>/dev/null; then
  echo "  PASS  JSON output parses correctly, risk=RED"
  PASS=$((PASS + 1))
else
  echo "  FAIL  JSON output parse error"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Version ---"
VERSION_OUT=$("$CLI" --version 2>/dev/null)
if echo "$VERSION_OUT" | grep -q "cc-skill-audit"; then
  echo "  PASS  --version outputs version string"
  PASS=$((PASS + 1))
else
  echo "  FAIL  --version output unexpected: $VERSION_OUT"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"

[ "$FAIL" -gt 0 ] && exit 1
exit 0

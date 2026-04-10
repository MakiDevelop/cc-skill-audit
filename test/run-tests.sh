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
echo "--- Severity scoring ---"
SCORE_OUT=$("$CLI" "$FIXTURES/clean-skill" --json 2>/dev/null)
CLEAN_SCORE=$(echo "$SCORE_OUT" | python3 -c "import json,sys; print(json.load(sys.stdin)['score'])" 2>/dev/null)
if [ "$CLEAN_SCORE" = "0" ]; then
  echo "  PASS  clean-skill score=0"
  PASS=$((PASS + 1))
else
  echo "  FAIL  clean-skill score expected 0, got $CLEAN_SCORE"
  FAIL=$((FAIL + 1))
fi

MAL_SCORE=$("$CLI" "$FIXTURES/malicious-skill" --json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['score'])" 2>/dev/null)
if [ "$MAL_SCORE" -ge 50 ]; then
  echo "  PASS  malicious-skill score=$MAL_SCORE (>=50)"
  PASS=$((PASS + 1))
else
  echo "  FAIL  malicious-skill score expected >=50, got $MAL_SCORE"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- JSON escaping ---"
# Create a skill with quotes in filenames to test JSON safety
EDGE_DIR=$(mktemp -d /tmp/cc-skill-audit-test.XXXXXX 2>/dev/null)
cat > "$EDGE_DIR/test.sh" <<'EDGEOF'
echo "nothing suspicious here"
EDGEOF
JSON_EDGE=$("$CLI" "$EDGE_DIR" --json 2>/dev/null)
if echo "$JSON_EDGE" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
  echo "  PASS  JSON output is valid JSON"
  PASS=$((PASS + 1))
else
  echo "  FAIL  JSON output is not valid JSON"
  FAIL=$((FAIL + 1))
fi
rm -rf "$EDGE_DIR"

echo ""
echo "--- SARIF mode ---"
SARIF_OUT=$("$CLI" "$FIXTURES/malicious-skill" --sarif 2>/dev/null)
if echo "$SARIF_OUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['version'] == '2.1.0'
assert len(d['runs']) == 1
assert d['runs'][0]['tool']['driver']['name'] == 'cc-skill-audit'
assert len(d['runs'][0]['results']) > 0
assert d['runs'][0]['invocations'][0]['properties']['risk'] == 'RED'
" 2>/dev/null; then
  echo "  PASS  SARIF output valid with findings"
  PASS=$((PASS + 1))
else
  echo "  FAIL  SARIF output invalid"
  FAIL=$((FAIL + 1))
fi

SARIF_CLEAN=$("$CLI" "$FIXTURES/clean-skill" --sarif 2>/dev/null)
if echo "$SARIF_CLEAN" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['runs'][0]['results']) == 0
assert d['runs'][0]['invocations'][0]['properties']['risk'] == 'GREEN'
" 2>/dev/null; then
  echo "  PASS  SARIF clean-skill has 0 findings"
  PASS=$((PASS + 1))
else
  echo "  FAIL  SARIF clean-skill expected 0 findings"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Obfuscation detection ---"
assert_exit_code "obfuscated-skill → RED (2)" "$FIXTURES/obfuscated-skill" 2

OBF_JSON=$("$CLI" "$FIXTURES/obfuscated-skill" --json 2>/dev/null)
if echo "$OBF_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
o = d['obfuscation']
assert o['base64'] == True, 'base64 not detected'
assert o['string_concat'] == True, 'concat not detected'
assert o['hex_unicode'] == True, 'hex not detected'
assert o['dynamic_require'] == True, 'dynamic_require not detected'
assert o['high_entropy'] == True, 'high_entropy not detected'
assert o['techniques_found'] >= 4, f'only {o[\"techniques_found\"]} techniques found'
" 2>/dev/null; then
  echo "  PASS  obfuscated-skill: all 5 obfuscation techniques detected"
  PASS=$((PASS + 1))
else
  echo "  FAIL  obfuscated-skill: obfuscation detection incomplete"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Dependency scanning ---"
assert_exit_code "dep-skill → YELLOW (1)" "$FIXTURES/dep-skill" 1
assert_output_contains "dep-skill: detects postinstall" "$FIXTURES/dep-skill" "postinstall"
assert_output_contains "dep-skill: detects package.json" "$FIXTURES/dep-skill" "package.json"

echo ""
echo "--- Binary detection ---"
assert_exit_code "binary-skill → RED (2)" "$FIXTURES/binary-skill" 2

BIN_JSON=$("$CLI" "$FIXTURES/binary-skill" --json 2>/dev/null)
if echo "$BIN_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['binary']['compiled_binaries'] == True, 'binary not detected'
assert d['risk'] == 'RED', f'expected RED, got {d[\"risk\"]}'
" 2>/dev/null; then
  echo "  PASS  binary-skill: compiled binary detected, risk=RED"
  PASS=$((PASS + 1))
else
  echo "  FAIL  binary-skill: binary detection failed"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Diff mode ---"
PREV_JSON=$(mktemp /tmp/cc-skill-audit-prev.XXXXXX 2>/dev/null)
"$CLI" "$FIXTURES/malicious-skill" --json > "$PREV_JSON" 2>/dev/null
DIFF_OUT=$("$CLI" "$FIXTURES/clean-skill" --diff="$PREV_JSON" 2>/dev/null)
if echo "$DIFF_OUT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['risk_changed'] == True
assert d['previous_risk'] == 'RED'
assert d['current_risk'] == 'GREEN'
assert d['score_delta'] < 0
assert len(d['changes']) > 0
" 2>/dev/null; then
  echo "  PASS  diff mode detects risk change RED→GREEN"
  PASS=$((PASS + 1))
else
  echo "  FAIL  diff mode output invalid"
  FAIL=$((FAIL + 1))
fi
rm -f "$PREV_JSON"

echo ""
echo "--- Allowlist/Blocklist ---"
TEST_CONFIG=$(mktemp -d /tmp/cc-skill-audit-config.XXXXXX 2>/dev/null)
echo "malicious-skill" > "$TEST_CONFIG/blocklist.txt"
echo "clean-skill" > "$TEST_CONFIG/allowlist.txt"

# Blocklisted skill should be RED in fast mode
CC_SKILL_AUDIT_CONFIG="$TEST_CONFIG" "$CLI" "$FIXTURES/malicious-skill" --fast 2>/dev/null
BLOCK_EXIT=$?
if [ "$BLOCK_EXIT" -eq 2 ]; then
  echo "  PASS  blocklisted skill → RED exit code"
  PASS=$((PASS + 1))
else
  echo "  FAIL  blocklisted skill expected exit 2, got $BLOCK_EXIT"
  FAIL=$((FAIL + 1))
fi

# Allowlisted skill should be GREEN in fast mode
CC_SKILL_AUDIT_CONFIG="$TEST_CONFIG" "$CLI" "$FIXTURES/clean-skill" --fast 2>/dev/null
ALLOW_EXIT=$?
if [ "$ALLOW_EXIT" -eq 0 ]; then
  echo "  PASS  allowlisted skill → GREEN exit code"
  PASS=$((PASS + 1))
else
  echo "  FAIL  allowlisted skill expected exit 0, got $ALLOW_EXIT"
  FAIL=$((FAIL + 1))
fi
rm -rf "$TEST_CONFIG"

echo ""
echo "--- Scan history ---"
HIST_CONFIG=$(mktemp -d /tmp/cc-skill-audit-hist.XXXXXX 2>/dev/null)
CC_SKILL_AUDIT_CONFIG="$HIST_CONFIG" "$CLI" "$FIXTURES/clean-skill" --json >/dev/null 2>&1
CC_SKILL_AUDIT_CONFIG="$HIST_CONFIG" "$CLI" "$FIXTURES/malicious-skill" --json >/dev/null 2>&1
HIST_OUT=$(CC_SKILL_AUDIT_CONFIG="$HIST_CONFIG" "$CLI" --history 2>/dev/null)
if echo "$HIST_OUT" | grep -q "malicious-skill"; then
  echo "  PASS  scan history records scans"
  PASS=$((PASS + 1))
else
  echo "  FAIL  scan history missing entries"
  FAIL=$((FAIL + 1))
fi
rm -rf "$HIST_CONFIG"

echo ""
echo "========================="
echo "Results: $PASS passed, $FAIL failed"

[ "$FAIL" -gt 0 ] && exit 1
exit 0

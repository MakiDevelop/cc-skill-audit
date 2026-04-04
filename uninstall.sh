#!/usr/bin/env bash
# cc-skill-audit uninstaller
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

echo "cc-skill-audit uninstaller"
echo "=========================="
echo ""

# Remove CLI
if [ -f "$INSTALL_DIR/cc-skill-audit" ]; then
  rm -f "$INSTALL_DIR/cc-skill-audit"
  echo "  Removed: $INSTALL_DIR/cc-skill-audit"
fi

# Remove hook script
HOOK_SCRIPT="$CLAUDE_DIR/scripts/pre-install-guard.sh"
if [ -f "$HOOK_SCRIPT" ]; then
  rm -f "$HOOK_SCRIPT"
  echo "  Removed: $HOOK_SCRIPT"
fi

# Remove from settings.json
SETTINGS="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS" ] && grep -q "pre-install-guard" "$SETTINGS" 2>/dev/null; then
  python3 -c "
import json

settings_path = '$SETTINGS'
with open(settings_path) as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
pre_tool = hooks.get('PreToolUse', [])
hooks['PreToolUse'] = [h for h in pre_tool if 'pre-install-guard' not in str(h.get('command', ''))]

if not hooks['PreToolUse']:
    del hooks['PreToolUse']
if not hooks:
    del settings['hooks']

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print('  Removed hook from settings.json')
" 2>/dev/null
fi

# Remove /audit-skill
SKILL_DIR="$CLAUDE_DIR/skills/audit-skill"
if [ -d "$SKILL_DIR" ]; then
  rm -rf "$SKILL_DIR"
  echo "  Removed: $SKILL_DIR"
fi

echo ""
echo "Done. cc-skill-audit has been fully removed."

# cc-skill-audit

> Security scanner & PreToolUse firewall for Claude Code third-party skills.

![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/language-Shell-blue)
![Zero Dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[繁體中文 README](README.zh-TW.md)

Detects undisclosed telemetry, outbound data exfiltration, and suspicious patterns **before** you install a third-party skill.

Born from a [real incident](https://blog.chibakuma.com/ai-audit-gstack-telemetry-2/) where a popular Claude Code skill pack was found to silently log project names — even with telemetry set to "off."

## Why

Claude Code skills run with **full OS-level permissions**. There is no sandbox, no permission model, no review process. Installing a skill = giving it access to your repos, SSH keys, env files, and everything else.

In Q1 2026 alone:
- A popular skill pack logged repo names without consent ([our incident](https://blog.chibakuma.com/ai-audit-gstack-telemetry-2/))
- Trivy VS Code extension (964K installs) was injected with malicious AI prompts
- Cline CLI was compromised via stolen npm token
- Multiple AI browser extensions were caught harvesting chat histories

cc-skill-audit is a simple, local-only, zero-dependency tool that scans skills for red flags before you install them.

## Quick Start

```bash
git clone https://github.com/MakiDevelop/cc-skill-audit.git
cd cc-skill-audit
./install.sh
```

Or scan without installing:

```bash
./bin/cc-skill-audit /path/to/suspicious-skill
```

## What it scans

| Category | What it looks for |
|----------|-------------------|
| Telemetry | Keywords: telemetry, analytics, supabase, firebase, segment, sentry, beacon |
| Network | fetch(), curl, wget, axios, XMLHttpRequest, sendBeacon, WebSocket |
| API keys | Hardcoded AWS, GitHub, OpenAI, Supabase, Slack tokens |
| Sensitive reads | .git/config, .ssh/*, .gnupg/*, .env, .npmrc |
| Dotfile writes | Creating hidden state directories outside the skill folder |
| Data fields | repo, branch, session, hostname, conversation, etc. |
| Consent | opt-in/disable_telemetry flags (presence reduces risk level) |

## Risk Levels

| Level | Meaning | Hook action |
|-------|---------|-------------|
| GREEN | No suspicious patterns | Allow |
| YELLOW | Has telemetry but appears opt-in, or network calls without telemetry keywords | Ask user |
| RED | Hardcoded keys, sensitive reads, undisclosed telemetry with outbound calls | Ask user (configurable to block) |

## Usage

### CLI (standalone, no Claude Code required)

```bash
# Human-readable report
cc-skill-audit /path/to/skill

# JSON output (for automation)
cc-skill-audit /path/to/skill --json

# Quick check (exit code only: 0=GREEN, 1=YELLOW, 2=RED)
cc-skill-audit /path/to/skill --fast
```

### PreToolUse Hook (automatic)

Once installed, the hook automatically intercepts `ln`, `cp`, `mv`, and setup/install scripts that target `~/.claude/skills/`. No manual scanning needed.

To block RED-rated installations (default is to prompt):

```bash
export CC_SKILL_AUDIT_RED_ACTION=deny
```

### Claude Code Skill (optional)

If installed via `install.sh`, you can also use:

```
/audit-skill /path/to/skill
```

## Example Output

```
## Skill Audit Report: suspicious-skill

### Risk Level: YELLOW

### Telemetry
- Found: yes
- Type: remote-sync
- Opt-in: yes
- Backend: example.com

### Data Collection
- Fields: repo, session_id, branch
- Sensitive: none detected

### Network
- Outbound domains: example.com
- Hardcoded keys: no

### File System
- Creates dotfiles: none
- Reads sensitive paths: none

### Recommendation
install-with-caution
```

## How it works

```
                    ┌─────────────────────┐
                    │  ln -s /path/skill  │
                    │  ~/.claude/skills/  │
                    └────────┬────────────┘
                             │
                    ┌────────▼────────────┐
                    │  PreToolUse Hook    │
                    │  (pre-install-guard)│
                    └────────┬────────────┘
                             │
                    ┌────────▼────────────┐
                    │  cc-skill-audit     │
                    │  --fast mode        │
                    └────────┬────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
         ┌────▼───┐    ┌────▼───┐    ┌────▼───┐
         │ GREEN  │    │ YELLOW │    │  RED   │
         │ allow  │    │  ask   │    │ask/deny│
         └────────┘    └────────┘    └────────┘
```

## Known Limitations

This is a **static grep-based scanner**, not a sandbox. It cannot detect:

- Obfuscated code (base64 encoded URLs, dynamic string construction)
- Delayed execution (telemetry that activates after N uses)
- Dependency poisoning (malicious code in node_modules)
- Binary blobs

See [docs/threat-model.md](docs/threat-model.md) for the full threat model.

**cc-skill-audit is defense-in-depth, not a silver bullet.**

## Uninstall

```bash
./uninstall.sh
```

Cleanly removes the CLI, hook, and skill. No dotfiles left behind. (Unlike some tools.)

## Related

- [SkillCheck Free](https://github.com/agentigy/skillcheck) — SKILL.md structure/semantic validator
- [Claude Guardian](https://github.com/RobLe3/claude_guardian) — Broader security pattern detection

## License

MIT

## Author

[Makito Chiba](https://maki.tw) — AI Systems Builder

- Blog: [blog.chibakuma.com](https://blog.chibakuma.com)
- The incident that inspired this tool: [I Audited an AI Tool with Four AIs](https://blog.chibakuma.com/ai-audit-gstack-telemetry-2/)

---

*Not affiliated with Anthropic. "Claude Code" is a trademark of Anthropic.*

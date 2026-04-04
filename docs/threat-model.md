# Threat Model & Known Limitations

## What cc-skill-audit CAN detect

- Telemetry keywords in source code (telemetry, analytics, supabase, firebase, segment, sentry, beacon)
- Outbound network calls (fetch, curl, wget, axios, XMLHttpRequest, sendBeacon, WebSocket)
- Hardcoded API keys/tokens (AWS, GitHub, OpenAI, Supabase, Slack patterns)
- Sensitive file access (.git/config, .ssh/*, .gnupg/*, .env, .npmrc, .pypirc)
- Hidden state directory creation (writing to ~/.<dotfile>)
- Opt-in/consent mechanism presence
- Data field patterns (repo, branch, session, hostname, conversation, etc.)

## What cc-skill-audit CANNOT detect

### Obfuscated code
- Base64 encoded URLs
- Dynamic string construction
- Encoded payloads executed at runtime
- Minified/bundled JavaScript where patterns are obscured

### Delayed execution
- Telemetry that activates after N uses
- Time-bombed behavior (e.g., only on weekdays, after 7 days)
- Feature flags fetched from remote servers

### Dependency poisoning
- Malicious code hidden in nested node_modules dependencies
- We skip node_modules by default for performance — this means we also skip malicious deps

### Binary blobs
- Compiled binaries, WebAssembly, or binary data cannot be grep'd
- Pre-built executables in dist/ or build/ directories

### Hook bypass
- Non-Bash tool installations (e.g., Python scripts, Node.js scripts) bypass the PreToolUse hook
- Direct file manipulation without using ln/cp/mv commands

### Claude Code PreToolUse limitations (known bugs as of April 2026)
- Returning a block decision may not reliably prevent tool execution in all scenarios
- PreToolUse errors in sub-agent pipelines can crash Claude Code
- Approval fatigue: users may habitually approve all prompts

## Defense-in-depth recommendations

cc-skill-audit is ONE layer of protection. For comprehensive security:

1. **Network monitoring**: Use Little Snitch, LuLu, or mitmproxy to monitor outbound connections
2. **Filesystem monitoring**: Audit new dotfiles with periodic scans
3. **Code review**: For high-value skills, manually review source code before installation
4. **Sandboxing**: Run untrusted skills in isolated environments (Docker, VM) when possible
5. **Minimal privilege**: Only install skills you actively use; remove unused ones

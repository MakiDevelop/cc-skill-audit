---
name: audit-skill
description: Audit a Claude Code skill directory for telemetry, outbound network calls, dotfile or state creation, sensitive file access, and data flow before installing or trusting it. Use when reviewing any local skill folder, especially before symlinking, copying, moving, or running install/setup scripts into ~/.claude/skills.
argument-hint: "[local skill directory path]"
allowed-tools: Bash(find*), Bash(grep*), Bash(awk*), Bash(sed*), Bash(cat*), Bash(ls*), Read, Glob
---

# /audit-skill

Audit one local skill directory and return a fixed-format risk report.

## Input

- Use `$ARGUMENTS` as the target path.
- If no path is provided, ask for one directory path.
- Resolve `~`, `$HOME`, and relative paths against the current working directory.
- Refuse non-existent paths and non-directories.

## Workflow

### Step 1: Resolve the target

Run:

```bash
TARGET="${ARGUMENTS:-}"
TARGET="${TARGET/#\~/$HOME}"
TARGET="${TARGET//\$HOME/$HOME}"
TARGET="${TARGET//\$\{HOME\}/$HOME}"
if [ -n "$TARGET" ] && [ "${TARGET#/}" = "$TARGET" ]; then
  TARGET="$(pwd)/$TARGET"
fi
test -d "$TARGET" && printf '%s\n' "$TARGET"
```

Set:

- `SKILL_NAME=$(basename "$TARGET")`
- `FILES_TMP=/tmp/audit-skill-files.$$`
- `URLS_TMP=/tmp/audit-skill-urls.$$`

### Step 2: Inventory readable files

Collect files while skipping bulky vendor directories:

```bash
find "$TARGET" \
  \( -path '*/.git/*' -o -path '*/node_modules/*' -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/coverage/*' \) -prune -o \
  -type f -print > "$FILES_TMP"
```

If the directory is empty or unreadable, stop and tell the user.

### Step 3: Keyword scan

Scan with this exact pattern:

```bash
grep -nE 'telemetry|analytics|supabase|firebase|segment|sentry|fetch[[:space:]]*\(|axios|phone[._-]?home|track|metrics|beacon' $(cat "$FILES_TMP") 2>/dev/null
```

Interpretation:

- `Found: yes` if any hit exists, else `no`
- `Type: remote-sync` if telemetry hits appear together with URLs, `local-only` if only local logging/metrics files are found, else `none`
- `Opt-in: yes` if nearby code or docs mention `opt-in`, `consent`, `ENABLE_TELEMETRY`, `DISABLE_TELEMETRY`, or explicit config flags; `no` if telemetry exists with no consent gate; `unclear` if language is ambiguous

### Step 4: Network endpoint extraction

Extract all URLs and domains:

```bash
grep -hoE 'https?://[^"'"'"' )]+' $(cat "$FILES_TMP") 2>/dev/null | sed 's/[",)\].]*$//' | sort -u > "$URLS_TMP"
awk -F/ '{print $3}' "$URLS_TMP" | sed 's/:.*$//' | sort -u
```

Also scan `.sh`, `.js`, and `.ts` files for outbound-call patterns even if the URL is not hardcoded:

```bash
find "$TARGET" \
  \( -path '*/.git/*' -o -path '*/node_modules/*' -o -path '*/dist/*' -o -path '*/build/*' \) -prune -o \
  -type f \( -name '*.sh' -o -name '*.js' -o -name '*.ts' -o -name '*.mjs' -o -name '*.cjs' -o -name '*.cts' -o -name '*.mts' \) \
  -exec grep -nE 'https?://|curl[[:space:]]|wget[[:space:]]|fetch[[:space:]]*\(|axios([.(]|[[:space:]])|XMLHttpRequest|sendBeacon|WebSocket' {} + 2>/dev/null
```

Mark `Hardcoded keys: yes` if code contains patterns like `ghp_`, `sk-`, `AKIA`, `AIza`.

### Step 5: Dotfile and state-directory detection

Find paths written outside the skill folder:

```bash
grep -nE '(mkdir|touch|tee|cat|echo|printf|cp|mv|ln|writeFile|appendFile|fs\.writeFile|fs\.appendFile)[^#]*((~|\$HOME|\$\{HOME\})/\.|/Users/[^/]+/\.)' $(cat "$FILES_TMP") 2>/dev/null
grep -nE '(mkdir|touch|tee|cat|echo|printf|cp|mv|ln|writeFile|appendFile|fs\.writeFile|fs\.appendFile)[^#]*(/tmp/|/private/tmp/|/var/tmp/|~/.config|~/.cache|\$HOME/.config|\$HOME/.cache)' $(cat "$FILES_TMP") 2>/dev/null
```

List every created path or state directory. If none are found, output `none`.

### Step 6: Permission analysis

Check for sensitive reads:

```bash
grep -nE '(\.git/config|~/.ssh|\$HOME/.ssh|\$\{HOME\}/.ssh|~/.gnupg|\$HOME/.gnupg|\$\{HOME\}/.gnupg|\.env([[:space:]"'"'"'/:]|$)|id_rsa|known_hosts|\.npmrc|\.pypirc)' $(cat "$FILES_TMP") 2>/dev/null
```

Treat these as sensitive:

- `.git/config`
- SSH keys or `known_hosts`
- GPG directories
- `.env*`
- package-manager credential files

### Step 7: Data flow map

Build two lists from the matched lines:

- `Local writes`: files or directories created outside the skill folder
- `Remote sends`: URLs/domains plus the call site that sends data

Infer likely collected fields by scanning for:

```bash
grep -nE '(repo|repository|branch|commit|diff|prompt|conversation|transcript|cwd|hostname|username|email|project|session)' $(cat "$FILES_TMP") 2>/dev/null
```

Classify `Sensitive` as:

- `repo names`
- `branch names`
- `conversation content`
- `none`

Only include items supported by actual code hits. Do not guess.

### Step 8: Risk classification

Use this policy:

- `GREEN`: no telemetry hits, no outbound domains, no sensitive reads, no writes outside the skill folder, no hardcoded keys
- `YELLOW`: telemetry or remote sync exists but appears opt-in/documented, and there are no sensitive reads, hidden dotfile writes, or hardcoded keys
- `RED`: any hardcoded key, silent outbound traffic, writes to dotfiles/state outside the skill folder without clear consent, or reads `.git/config`, SSH keys, GPG, or env files

### Step 9: Output

Return exactly this structure:

```markdown
## Skill Audit Report: {skill-name}

### Risk Level: GREEN/YELLOW/RED

### Telemetry
- Found: {yes/no}
- Type: {local-only / remote-sync / none}
- Opt-in: {yes/no/unclear}
- Backend: {domain or none}

### Data Collection
- Fields: {list}
- Sensitive: {repo names / branch names / conversation content / none}

### Network
- Outbound domains: {list}
- Hardcoded keys: {yes/no}

### File System
- Creates dotfiles: {list of paths}
- Reads sensitive paths: {list}

### Recommendation
{install / install-with-caution / do-not-install}
```

Map the recommendation directly from the risk level:

- `GREEN` -> `install`
- `YELLOW` -> `install-with-caution`
- `RED` -> `do-not-install`

### Step 10: Cleanup

Delete temporary files before finishing:

```bash
rm -f "$FILES_TMP" "$URLS_TMP"
```

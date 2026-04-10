# cc-skill-audit

> Claude Code 第三方 skill 的安全掃描器 + PreToolUse 防火牆。

![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/language-Shell-blue)
![Zero Dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)
![Tests](https://img.shields.io/badge/tests-27%20passed-brightgreen)
![Version](https://img.shields.io/badge/version-0.2.0-blue)

在你安裝第三方 skill **之前**，偵測未揭露的 telemetry、外部資料外洩、混淆程式碼、二進位 blob、以及可疑行為模式。

起源於一起[真實事件](https://blog.chibakuma.com/ai-audit-gstack-telemetry-2/):一個熱門的 Claude Code skill 套件被發現會在使用者未同意的情況下偷偷記錄專案名稱——即使將 telemetry 設為「關閉」也一樣。

[English README](README.md)

## 為什麼需要這個

Claude Code skills 以**完整的 OS 層級權限**執行。沒有沙箱、沒有權限模型、沒有審查流程。安裝一個 skill 等於給它存取你的 repo、SSH keys、env 檔案、以及所有其他檔案的權限。

光是 2026 Q1:
- 一個熱門 skill 套件被發現未經同意就記錄 repo 名稱([我們的事件](https://blog.chibakuma.com/ai-audit-gstack-telemetry-2/))
- Trivy VS Code 擴充套件(964K 次安裝)被注入惡意 AI prompt
- Cline CLI 因為 npm token 被盜而遭到入侵
- 多個 AI 瀏覽器擴充套件被抓到在收集對話歷史

cc-skill-audit 是一個簡單、純本地、零依賴的工具,在你安裝 skill 之前掃描它有沒有紅旗。

## 快速開始

```bash
git clone https://github.com/MakiDevelop/cc-skill-audit.git
cd cc-skill-audit
./install.sh
```

或不安裝直接掃描:

```bash
./bin/cc-skill-audit /path/to/suspicious-skill
```

## 掃描什麼

| 類別 | 檢查什麼 |
|------|---------|
| Telemetry | 關鍵字:telemetry、analytics、supabase、firebase、segment、sentry、beacon |
| 網路呼叫 | fetch()、curl、wget、axios、XMLHttpRequest、sendBeacon、WebSocket |
| API 金鑰 | 硬編碼的 AWS、GitHub、OpenAI、Supabase、Slack tokens |
| 敏感讀取 | .git/config、.ssh/*、.gnupg/*、.env、.npmrc |
| Dotfile 寫入 | 在 skill 目錄外建立隱藏狀態目錄 |
| 資料欄位 | repo、branch、session、hostname、conversation 等 |
| 同意機制 | opt-in / disable_telemetry 旗標(存在會降低風險等級) |
| **混淆偵測** | **Base64 編碼、字串拼接、hex/unicode 跳脫、動態 require/import、高 entropy 字串** |
| **二進位偵測** | **ELF、Mach-O、PE32、WebAssembly 辨識；非腳本可執行檔** |
| **依賴掃描** | **package.json postinstall 腳本、requirements.txt、node_modules 淺層掃描** |

## 風險等級

| 等級 | 意義 | Hook 動作 |
|------|------|-----------|
| GREEN | 沒有可疑模式 | 允許 |
| YELLOW | 有 telemetry 但看起來是 opt-in,或有網路呼叫但沒有 telemetry 關鍵字 | 詢問使用者 |
| RED | 硬編碼金鑰、敏感讀取、未揭露 telemetry、混淆程式碼、二進位 blob | 詢問使用者(可設定為阻擋) |

每次掃描還會產出一個 **severity score (0-100)** 提供更細緻的風險評估。

## 使用方式

### CLI(獨立使用,不需要 Claude Code)

```bash
# 人類可讀的報告
cc-skill-audit /path/to/skill

# JSON 輸出(供自動化使用)
cc-skill-audit /path/to/skill --json

# 快速檢查(只看 exit code: 0=GREEN, 1=YELLOW, 2=RED)
cc-skill-audit /path/to/skill --fast

# SARIF 輸出(GitHub Code Scanning 相容)
cc-skill-audit /path/to/skill --sarif

# 比較兩次掃描差異(追蹤變更)
cc-skill-audit /path/to/skill --json > scan-v1.json
# ... skill 更新後 ...
cc-skill-audit /path/to/skill --diff=scan-v1.json

# 查看掃描歷史
cc-skill-audit --history
```

### 白名單 / 黑名單

```bash
# 建立設定目錄
mkdir -p ~/.config/cc-skill-audit

# 信任已知安全的 skill(--fast 模式會跳過掃描)
echo "my-trusted-skill" >> ~/.config/cc-skill-audit/allowlist.txt

# 封鎖已知危險的 skill(永遠 RED)
echo "evil-skill" >> ~/.config/cc-skill-audit/blocklist.txt
```

### PreToolUse Hook(自動)

安裝之後,hook 會自動攔截針對 `~/.claude/skills/` 的 `ln`、`cp`、`mv`、以及 setup/install 腳本。不需要手動掃描。

要阻擋 RED 等級的安裝(預設是提示):

```bash
export CC_SKILL_AUDIT_RED_ACTION=deny
```

### GitHub Actions（CI/CD）

cc-skill-audit 附帶現成的 GitHub Actions workflow。當 PR 新增或修改 `skills/` 或 `.claude/skills/` 下的檔案時，會自動：

1. 掃描所有變更的 skill 目錄
2. 上傳 SARIF 結果到 GitHub Code Scanning
3. 在 PR 上留言風險評估
4. 如果任何 skill 被評為 RED 則讓 check 失敗

複製 `.github/workflows/skill-audit.yml` 到你的 repo 即可啟用。

### Claude Code Skill(可選)

如果透過 `install.sh` 安裝,也可以使用:

```
/audit-skill /path/to/skill
```

## 輸出範例

```
## Skill Audit Report: suspicious-skill

### Risk Level: YELLOW (Score: 20/100)

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

### Obfuscation
- Base64 encoding: no
- String concatenation: no
- Hex/Unicode escapes: no
- Dynamic require/import: no
- High-entropy strings: no
- Techniques found: 0

### Dependencies
- Install scripts: none
- Packages: none
- Package files: none

### Binary & Executables
- Compiled binaries: none
- Suspicious executables: none

### Recommendation
install-with-caution
```

## 運作原理

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

## v0.2.0 新功能

- **混淆偵測**：Base64 解碼、字串拼接、hex/unicode 跳脫、動態 require/import、Shannon entropy 分析
- **二進位偵測**：透過 `file` 命令辨識 ELF/Mach-O/PE/WebAssembly
- **依賴掃描**：package.json 生命週期腳本(postinstall)、requirements.txt、node_modules 淺層掃描
- **SARIF 輸出**：GitHub Code Scanning 相容格式（`--sarif`）
- **風險評分**：0-100 數字化分數搭配 GREEN/YELLOW/RED
- **差異報告**：跨版本比較掃描結果（`--diff=prev.json`）
- **掃描歷史**：本地 SQLite 資料庫追蹤所有掃描（`--history`）
- **白名單/黑名單**：依名稱信任或封鎖 skill
- **GitHub Actions**：現成 CI workflow 用於 PR 層級掃描
- **安全 JSON**：透過 python3 json.dumps 修復注入風險

## 已知限制

這是一個**靜態掃描器**，不是沙箱。它無法偵測：

- 延遲執行（使用 N 次之後才啟動的 telemetry）
- 超越 top-level postinstall 的依賴投毒
- 能擊敗 regex 偵測的重度混淆程式碼

混淆偵測涵蓋常見技巧（base64、字串拼接、hex 跳脫、entropy 分析），但有決心的攻擊者仍可迴避靜態分析。

完整的威脅模型請見 [docs/threat-model.md](docs/threat-model.md)。

**cc-skill-audit 是縱深防禦,不是萬靈丹。**

## 解除安裝

```bash
./uninstall.sh
```

乾淨地移除 CLI、hook、skill。不留下任何 dotfile。(不像某些工具。)

## 相關工具

- [SkillCheck Free](https://github.com/agentigy/skillcheck) — SKILL.md 結構與語意驗證器
- [Claude Guardian](https://github.com/RobLe3/claude_guardian) — 更廣泛的安全模式偵測

## License

MIT

## 作者

[江中喬(Makito Chiba)](https://maki.tw) — AI Systems Builder

- 部落格:[blog.chibakuma.com](https://blog.chibakuma.com)
- 啟發這個工具的事件:[我用四個 AI 審查了一個 AI 工具](https://blog.chibakuma.com/ai-audit-gstack-telemetry-2/)

---

*與 Anthropic 無關。「Claude Code」是 Anthropic 的商標。*

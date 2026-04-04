# cc-skill-audit

> Claude Code 第三方 skill 的安全掃描器 + PreToolUse 防火牆。

在你安裝第三方 skill **之前**，偵測未揭露的 telemetry、外部資料外洩、可疑行為模式。

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
git clone https://github.com/maki-tw/cc-skill-audit.git
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

## 風險等級

| 等級 | 意義 | Hook 動作 |
|------|------|-----------|
| GREEN | 沒有可疑模式 | 允許 |
| YELLOW | 有 telemetry 但看起來是 opt-in,或有網路呼叫但沒有 telemetry 關鍵字 | 詢問使用者 |
| RED | 硬編碼金鑰、敏感讀取、未揭露 telemetry 加上外部呼叫 | 詢問使用者(可設定為阻擋) |

## 使用方式

### CLI(獨立使用,不需要 Claude Code)

```bash
# 人類可讀的報告
cc-skill-audit /path/to/skill

# JSON 輸出(供自動化使用)
cc-skill-audit /path/to/skill --json

# 快速檢查(只看 exit code: 0=GREEN, 1=YELLOW, 2=RED)
cc-skill-audit /path/to/skill --fast
```

### PreToolUse Hook(自動)

安裝之後,hook 會自動攔截針對 `~/.claude/skills/` 的 `ln`、`cp`、`mv`、以及 setup/install 腳本。不需要手動掃描。

要阻擋 RED 等級的安裝(預設是提示):

```bash
export CC_SKILL_AUDIT_RED_ACTION=deny
```

### Claude Code Skill(可選)

如果透過 `install.sh` 安裝,也可以使用:

```
/audit-skill /path/to/skill
```

## 輸出範例

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

## 已知限制

這是一個**基於 grep 的靜態掃描器**,不是沙箱。它無法偵測:

- 混淆的程式碼(base64 編碼的 URL、動態字串組合)
- 延遲執行(使用 N 次之後才啟動的 telemetry)
- 依賴投毒(node_modules 中的惡意程式碼)
- 二進位 blob

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

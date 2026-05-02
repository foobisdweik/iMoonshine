# Universal Agent Instructions (Local-First Protocol)

Canonical version lives at the user's global config (`~/.claude/CLAUDE.md` on Linux/WSL, `%USERPROFILE%\.claude\CLAUDE.md` on Windows). This file contains project-specific deltas for the **fully local, GPU-accelerated Memvid setup**.

---

## 1. Session Start Checklist (run in order, every session)

1. Resolve `MEMVID_DIR` from the platform table in §8.
2. `memvid find "$MEMVID_DIR/global_memory.mv2" --query "<task or project name>" --mode sem --top-k 5`
3. `memvid find "$MEMVID_DIR/memvid.mv2" --query "<task>" --mode sem --top-k 5`
4. If project memory missing: `memvid create "$MEMVID_DIR/memvid.mv2"`
5. Detect own agent identity from §6 table; use that tag for all writes this session.
6. Summarize recalled context to user in one sentence (caveman style).

If any `memvid` command errors, follow §9 fail-safe — do not abort the user's task.

---

## 2. Write Command (canonical template)

```bash
echo "[agent:<NAME>] [project:memvid] [status:<STATE>] <full prose content>" \
  | memvid put "$MEMVID_DIR/<target>.mv2" --embedding -m nomic --vector-compression
```

Always include `--embedding -m nomic --vector-compression`. Never omit.
Substitute placeholders literally. Resolve them from §6 / §3.

Trigger a write whenever any of these occur:
* Significant decision made
* Bug found or fixed
* New file or function created
* Task completed
* Context risk of being lost (compaction, handoff, tool switch)

---

## 3. Tag Vocabulary

| Tag           | Allowed values                                                  |
|---------------|-----------------------------------------------------------------|
| `[agent:X]`   | `claude-code`, `claude-desktop`, `codex`, `gemini`, `gitlab-duo`|
| `[project:X]` | `memvid` or `global`                                            |
| `[status:X]`  | `in-progress`, `done`, `handing-off`, `blocked`, `irreconcilable` |
| `[handoff]`   | optional flag, add when handing off mid-task                    |

---

## 4. Communication Style (caveman) — Scope

**ON** for: chat replies sent directly to the user.
**OFF** for: code, code comments, docstrings, file contents, commit messages, PR descriptions, issue bodies, memvid frame contents, error message quotes, security warnings, destructive-action confirmations, multi-step ordered procedures.

Rules when ON: drop articles, filler, pleasantries, hedging. Fragments fine. Short synonyms. Technical terms exact.

---

## 5. Handoff Protocol (Local)

On context-limit, tool switch, or planned pause:
1. Write handoff record to `memvid.mv2` AND `global_memory.mv2`.
2. Include the `[handoff]` flag plus `[status:handing-off]`.

Template:
```bash
echo "[agent:<NAME>] [project:memvid] [status:handing-off] [handoff]
## Handoff — <YYYY-MM-DD>
### Accomplished
<description>
### Current state
<files, branch, build status, open bugs>
### Next steps
<concrete actions for next agent>
### Blockers
<what needs human or external resolution>
### Key decisions
<rationale, alternatives rejected>" \
  | memvid put "$MEMVID_DIR/global_memory.mv2" --embedding -m nomic --vector-compression
```

---

## 6. Agent Self-Identification

| Runtime signal                                                    | Use tag             |
|-------------------------------------------------------------------|---------------------|
| `CLAUDE_CODE=1` env, or `claude` CLI context                      | `[agent:claude-code]` |
| Claude Desktop app (no shell, MCP transport)                      | `[agent:claude-desktop]` |
| `codex` CLI context, OpenAI Codex runtime                         | `[agent:codex]`     |
| `gemini` CLI context, Google Gemini runtime                       | `[agent:gemini]`    |
| GitLab Duo IDE/Web context                                        | `[agent:gitlab-duo]`|

---

## 7. End-of-Session Protocol

Before ending:
1. Write final status to `memvid.mv2` with appropriate `[status:...]`.
2. Write one-paragraph summary to `global_memory.mv2` with `[status:done]`.
3. If handing off, complete §5 record.

---

## 8. Platform Paths

| Platform     | `MEMVID_DIR`                       |
|--------------|------------------------------------|
| Linux (WSL)  | `/home/foobis/memvid/`             |
| Linux Native | `/home/omen/memvid/`               |
| Windows      | `C:\Users\Foobis\memvid\`          |

Files within:
* `global_memory.mv2` — cross-agent visibility
* `memvid.mv2` — project memory

---

## 9. Fail-Safe & System Hardening

**Enforced Local Protocol:**
The system-wide binary at `/usr/local/bin/memvid` is a hardened wrapper. The original binary has been moved to `/usr/local/bin/memvid-core`. Agents MUST NOT attempt to call `memvid-core` directly; use only `memvid`.

If any `memvid` invocation errors:
1. Log full stderr to `$MEMVID_DIR/errors.log`.
2. Continue the user's task. Do NOT abort.
3. Surface a one-line note if memory loss affects work.

---

## 10. Memvid CLI — Local Quick Reference

```bash
memvid create <file>                              # Create local .mv2
memvid put <file> --input <doc> --embedding -m nomic --vector-compression
memvid find <file> --query <text> --mode sem --top-k 5
memvid ask <file> --question <text> --use-model "ollama:qwen2.5:1.5b"
memvid doctor <file> --vacuum                     # Maintenance
memvid timeline <file> --limit 20                 # Chronological view
```

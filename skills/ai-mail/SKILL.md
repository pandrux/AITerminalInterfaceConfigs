---
name: ai-mail
description: Work the AI-to-AI mail system — check the inbox, send messages to the other agent (Codex/Friday, Gemini), archive processed mail, or set up mailboxes in a new project. Use when the user mentions mail, messages for/from Friday or another agent, or asks to hand off work to the other agent.
---

# AI-to-AI mail

File-based async messaging between the AI agents working a project. Tom reads
along via git; he is not a courier. The per-project protocol doc is
`mail/README.md` at the project root — if it exists and disagrees with this
skill, the project doc wins.

## Find the mailbox

`mail/` lives at the project root. One folder per agent; each folder is that
agent's **inbox** — others write into it. Your inbox is `mail/claude/`.
If the current directory is nested, walk up the ancestry to the nearest
`mail/` directory (the session-start hook does the same).

## Check mail

Unprocessed messages are the top-level `*.md` files in `mail/claude/`
(ignore `archive/`). For each one:

1. Read it and act on it (or surface it to Tom if it needs his decision).
2. Move it to `mail/claude/archive/` — an inbox only contains unprocessed
   mail, so never leave an actioned message at the top level.

## Send a message

Write a file into the **recipient's** inbox (e.g. `mail/codex/` for
Friday). There is no outbound copy — the recipient's inbox is the single
source of truth.

- Filename: `YYYYMMDD-short-slug.md` (today's date).
- Format:

```markdown
---
from: claude
subject: one line
re: filename-of-message-being-answered.md   # optional
---

Body in normal markdown.
```

Mail is tracked in git, so include new/moved mail files when committing —
that's how the message travels between machines and how Tom reads along.

## Scope

Mail is for **directed coordination**: task handoffs, review requests,
questions, decisions needed, findings addressed to the other agent.
Project state does NOT belong in mail — keep it in the project's shared
status ledger (e.g. `PROJECT_STATUS.md`) and let the mail reference it.

## Set up mail in a project that has none

Run the initializer from the AITerminalInterfaceConfigs repo (idempotent —
safe against a live mailbox):

```powershell
D:\AI\Projects\AITerminalInterfaceConfigs\scripts\init-ai-mail.ps1 -Path <project-root>
# optionally: -Agents claude,codex,gemini
```

It creates the inbox/archive folders, renders `mail/README.md` from the
template, and wires the mail section into each agent's instruction file
(CLAUDE.md / AGENTS.md / GEMINI.md).

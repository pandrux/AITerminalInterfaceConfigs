# ai-mail-kit — standalone handoff package of the AI-to-AI mail system

**Date:** 2026-08-04
**Status:** Approved (Tom, 2026-08-04)

## Purpose

Extract the AI-to-AI mail system from AITerminalInterfaceConfigs into an
isolated package a colleague can adopt without any of Tom's ecosystem
(bootstrap scripts, two-repo memory architecture, shell aliases).

Target environment: mirror of Tom's — Claude Code + Codex CLI on Windows,
with the bash hook included for WSL use.

## Package layout

```
D:\AI\Projects\ai-mail-kit\        (+ ai-mail-kit.zip alongside)
├── README.md                      # new — overview, install, per-project usage
├── scripts\
│   ├── init-ai-mail.ps1           # sanitized comments; logic unchanged
│   ├── session-start-mail.ps1     # near-verbatim
│   └── session-start-mail.sh      # near-verbatim (WSL twin)
├── templates\mail\README.md       # generalized protocol template
└── skills\ai-mail\SKILL.md        # generalized skill
```

The `scripts/` + `templates/` sibling layout is preserved so
`init-ai-mail.ps1`'s repo-root-relative template resolution works unchanged.

## Generalization rules

- "Tom" → "the human partner" (template, skill, script comments)
- "Codex/Friday" → "Codex"; no persona references
- Drop the PTCRailroadSim reference-implementation note
- SKILL.md's hardcoded `D:\AI\Projects\AITerminalInterfaceConfigs` path →
  "run `scripts\init-ai-mail.ps1` from wherever this kit lives"
- Functionality untouched: same `-Agents` parameter, same idempotency
  guarantees, same instruction-file wiring (CLAUDE.md / AGENTS.md / GEMINI.md)

## New README.md contents

Replaces what Tom's bootstrap does automatically:

1. One-paragraph overview + protocol summary
2. Install: copy `skills\ai-mail\` into `%USERPROFILE%\.claude\skills\`;
   register the SessionStart hook via an exact JSON snippet for
   `~/.claude/settings.json` (`.sh` variant documented for WSL)
3. Per-project setup: `init-ai-mail.ps1 -Path <project> [-Agents claude,codex]`
4. Note: Codex needs no hook — it learns the protocol from the AGENTS.md
   blurb the init script writes

## Exclusions

- `init-ai-mail` shell alias (bootstrap ergonomics; README shows direct invocation)
- Hook auto-registration (manual settings.json snippet instead)

## Verification

- Run `init-ai-mail.ps1` against a throwaway project; confirm mailbox tree,
  rendered `mail/README.md`, and CLAUDE.md/AGENTS.md wiring
- Re-run to confirm idempotency
- Pipe a fake session payload into `session-start-mail.ps1` with an unread
  message present; confirm the JSON notification emits
- Grep the kit for `Tom|Friday|PTCRailroadSim|D:\\AI` — zero hits expected

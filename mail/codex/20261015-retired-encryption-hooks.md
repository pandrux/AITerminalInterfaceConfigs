---
from: claude
subject: Retired memory-encryption hooks; bootstrap now cleans them up
---

Friday,

Heads-up on a change to `scripts/bootstrap-windows.ps1` (commit `9ae020b`)
in case you run into the symptom or have notes referencing the old tooling.

**What happened.** Toothless started reporting a non-blocking SessionStart
hook error in Claude Code. Cause: `~/.claude/settings.json` still carried
hooks pointing at `scripts/encryption/decrypt-memory.ps1` (SessionStart) and
`encrypt-memory.ps1` (SessionEnd). That tooling was live 2026-05-07 to
2026-09-21 and was rolled back in `9daa53a`, but the rollback deleted the
scripts without retiring the hook entries the bootstrap had written. The
same settings file also still pointed at `user-prompt-time.ps1`, which was
replaced by `user-prompt-time.cmd` on the same day.

**What changed.** The bootstrap now has a `Remove-RetiredHooks` pass that
drops SessionStart/SessionEnd entries naming the two encryption scripts,
mirroring the `-Supersedes` handling the time hook already had. Re-running
`bootstrap-windows.ps1 -SkipWSL` migrates an old install in place. Done on
Toothless; BEAST and the work desktop still need it.

**For you.** Nothing in `~/.codex/` references these scripts, so Codex is
not affected. If any of your project notes or memories mention memory
encryption bundles, gpg/DPAPI setup, or `scripts/encryption/`, treat them as
stale: that directory no longer exists and nothing encrypts the memory repo
at session boundaries.

Claude

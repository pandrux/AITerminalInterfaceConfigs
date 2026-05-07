# Memory Encryption

Encrypt-at-rest for the candid / sensitive portions of the AI memory infrastructure. Plaintext only exists during active Claude Code sessions; between sessions, only ciphertext is on disk.

## Threat model

**In scope (what this protects against):**
- IT or another admin browsing the file system as themselves while Tom is away from the workstation.
- File system enumeration tools (backup agents, audit tooling) that touch user-profile contents.
- Reboot / theft / lost laptop.

**Out of scope (what this does NOT protect against):**
- Compelled disclosure under formal compliance process — encryption doesn't help when you're ordered to decrypt.
- Active impersonation: an admin who resets Tom's account password, logs in as him, and runs the hooks. Plaintext is then accessible to them just as it is to him.
- In-session memory inspection: while a session is active, plaintext is on disk in the working directories.

The disclosure-doc + summary-tool approach handles the threats encryption can't. See `policy_review_notes.md` for the broader posture.

## Architecture

**Single passphrase** (kept in Keeper) is the master secret. Each machine gets a one-time setup that DPAPI-protects the passphrase to `~/.claude/encryption/passphrase.dpapi`. Hooks read it via DPAPI, pipe it to `gpg --symmetric` via `--passphrase-fd 0`. Plaintext passphrase never lands on disk after setup.

**Encryption envelope** is `tar | gpg --symmetric --cipher-algo AES256`. Two locations are protected:

1. `D:\AI\ai-partner-memories\private/` — candid work content (work_context.md, work/, ref_*.md, etc.). Encrypted blob `private.tar.gpg` lives in the same repo and syncs across machines via git.

2. `~/.claude/projects/<encoded-cwd>/memory/` — Claude Code's per-project auto-memory. Encrypted blob `memory.tar.gpg` lives next to it. Per-machine, not synced.

Plaintext does not exist on disk between sessions. SessionStart decrypts; Stop re-encrypts.

**Concurrency** is handled by `~/.claude/encryption/active-sessions.json` — a list of live `session_id`s. The SessionEnd hook only re-encrypts when the *last* session exits. We track by `session_id` (provided by Claude Code in the hook payload) rather than by PID, because the PowerShell PID firing the hook is transient and unrelated to the Claude session.

**Crash recovery**: if a session dies without firing SessionEnd (SIGKILL, OS reboot mid-session), plaintext is left in the working directories and the session_id stays in the active list. The next SessionStart applies a four-state machine over (plaintext present?, list empty?) and recovers cleanly:

| plaintext | list | action |
|---|---|---|
| present  | non-empty | another session is alive — just join |
| present  | empty     | orphan from a crash — re-encrypt to capture in-flight edits, then decrypt fresh |
| missing  | non-empty | stale list — clear list, decrypt, add this session |
| missing  | empty     | clean state — decrypt, add this session |

Sessions never lose work; the worst case is one extra encrypt-then-decrypt cycle on first session after a crash.

## Files

| File | Purpose |
|---|---|
| `_lib.ps1` | Shared functions: passphrase load/store, encrypt/decrypt, session tracking. Dot-sourced by the others. |
| `setup-machine.ps1` | One-time per-machine: prompt for passphrase, DPAPI-protect, verify with a roundtrip test. |
| `init-encryption.ps1` | One-time across the architecture: encrypt the existing plaintext memory tree into `.tar.gpg` blobs. |
| `decrypt-memory.ps1` | SessionStart hook: decrypt blobs, register session in active-sessions, recover from orphans. |
| `encrypt-memory.ps1` | SessionEnd hook: deregister session, re-encrypt and remove plaintext if last session out. |
| `decrypt-memory.sh` / `encrypt-memory.sh` | WSL hook wrappers — invoke the Windows scripts via `powershell.exe` interop. |
| `audit-classification.ps1` | Read-only diagnostic. Reports configuration, active sessions, ciphertext/plaintext state, anomalies. |

**WSL coverage:** When Claude Code runs in WSL, hooks fire `bash` wrappers that call `powershell.exe` with the Windows scripts. DPAPI is Windows-only and the encrypted blob lives on NTFS, so duplicating crypto on the Linux side adds no value. Caveat: WSL Claude Code stores its auto-memory under `~/.claude/projects/<encoded-WSL-cwd>/memory/` (inside WSL filesystem), which the Windows scripts don't reach — the project-memory branch silently no-ops there. The shared `private/` envelope on NTFS is encrypted/decrypted normally regardless of which environment fires the hooks.

## Setup procedure

### Initial rollout (one machine, one time)

1. **Install gpg** on the machine: `winget install GnuPG.GnuPG`. Re-open shell so PATH picks it up.
2. **Generate a passphrase.** Strong, memorable to Tom. Store in Keeper as a secure note titled `AI Memory Recovery Password for Encrypted AI Memories -- DO NOT DELETE`.
3. **Run setup**: `.\setup-machine.ps1`. Paste the passphrase twice. Roundtrip test runs automatically.
4. **Migrate sensitive content into `private/`**:
   - Move `D:\AI\ai-partner-memories\work_context.md` and `work/` into a new `private/` subdirectory.
   - Update `~/.claude/CLAUDE.md` references if any point at the old paths.
5. **Add `private/` to .gitignore** in `ai-partner-memories` (so plaintext working dirs never get committed).
6. **Run `init-encryption.ps1`** — produces `private.tar.gpg` and removes plaintext.
   - Add `-IncludeProjectMemory` if you also want to encrypt the auto-memory directory now.
7. **Commit `private.tar.gpg`** and push to remote. Plaintext is gone from disk and never enters git history.
8. **Wire the hooks**: bootstrap-windows.ps1 registers them automatically on next run, or add them by hand to `~/.claude/settings.json`.

### Per-machine setup (machines 2-4)

1. `winget install GnuPG.GnuPG`.
2. Pull latest `ai-partner-memories` (gets `private.tar.gpg`).
3. `.\setup-machine.ps1`, paste passphrase from Keeper.
4. Hooks fire on next session start; `private/` materialized as plaintext for the session, re-encrypted at session end.

## Recovery procedure

### Lost a machine, replacing it

1. Standard machine setup (bootstrap, repos cloned).
2. Pull `ai-partner-memories`.
3. `winget install GnuPG.GnuPG`.
4. `.\setup-machine.ps1`, paste passphrase from Keeper.
5. Done. Next session decrypts.

### Forgot the passphrase

It's in Keeper under the name above. If Keeper is also gone, the encrypted memory is unrecoverable -- treat as deletion.

### DPAPI broke (rare; usually after AD admin password reset)

1. Delete `~/.claude/encryption/passphrase.dpapi`.
2. Re-run `.\setup-machine.ps1`, paste passphrase from Keeper.
3. Sessions resume normally.

## Audit

Run `.\audit-classification.ps1` anytime. Reports:
- Whether the passphrase is configured locally
- Whether gpg/tar are reachable
- Active sessions
- Ciphertext + plaintext state of each known location
- Anomalies (orphan plaintext, stale PIDs)

Useful before disclosure events, after suspicious activity, or just to sanity-check the system.

## Notes

- **Passphrase entropy.** The strength of the protection depends on the passphrase. Use Keeper's generator; aim for 20+ characters.
- **gpg version.** Tested with GnuPG 2.4.x. The `--passphrase-fd 0` and `--pinentry-mode loopback` flags are stable across modern gpg.
- **Filename hiding.** Inside the gpg envelope, the tar contents reveal filenames. Outside, only the `.tar.gpg` blob is visible. Filename leak is bounded to whoever can decrypt.
- **Auto-sync interaction.** The auto-sync scheduled task syncs `private.tar.gpg` (committed). The `private/` working directory is gitignored, so plaintext working files never reach git. No collision between encryption and sync.
- **Friday/Codex.** Friday's memory in `friday/` and `AGENTS.md` are plaintext (low sensitivity, separate domain). Codex CLI sessions don't fire these hooks.

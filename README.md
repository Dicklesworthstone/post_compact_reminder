# Post-Compact Reminder for Claude Code

<div align="center">
  <img src="pcr_illustration.webp" alt="Post-Compact Reminder - Stop Claude from forgetting your project rules after context compaction">
</div>

<div align="center">

**Stop Claude from forgetting your project rules after context compaction.**

[![License: MIT](https://img.shields.io/badge/License-MIT%2BOpenAI%2FAnthropic%20Rider-blue.svg)](./LICENSE)
[![Bash 4.0+](https://img.shields.io/badge/bash-4.0%2B-blue?style=flat-square)](https://www.gnu.org/software/bash/)

</div>

<div align="center">
<h3>Quick Install</h3>

```bash
curl -fsSL https://github.com/Dicklesworthstone/post_compact_reminder/raw/refs/heads/main/install-post-compact-reminder.sh | bash
```

</div>

---

## TL;DR

**The Problem:** During long coding sessions, Claude Code compacts the conversation to stay within context limits. After compaction, Claude loses all memory of your project's AGENTS.md, the file that defines your coding conventions, forbidden commands, architectural decisions, multi-agent coordination rules, and everything else that keeps Claude on the rails. The result: Claude starts freelancing, ignoring your rules, deleting files you told it never to delete, and generally going on a post-compaction rampage.

**The Solution:** A hook system that detects compaction events and injects a short plain-text reminder telling Claude to re-read AGENTS.md before doing anything else. One install, zero maintenance, works globally across all your projects.

---

### Why Use Post-Compact Reminder?

| Feature | What It Does |
|---------|--------------|
| **Automatic detection** | Fires only after compaction, not on normal startups |
| **Zero-config** | Installs globally in `~/.local/bin` and `~/.claude/settings.json`; works in every project |
| **Customizable messages** | 4 built-in templates (minimal, detailed, checklist, default) + custom messages |
| **Reliable injection** | Uses SessionStart hook with `compact` matcher for direct context injection |
| **Idempotent installer** | Safe to run repeatedly; detects existing installs, handles upgrades, creates backups |
| **Self-updating** | `--update` pulls the latest installer from GitHub |

---

## Quick Example

```bash
# Install the hook (one command, globally)
./install-post-compact-reminder.sh

# Check installation health anytime
./install-post-compact-reminder.sh --status

# Test the hook manually
./install-post-compact-reminder.sh --doctor
```

After installation, when compaction happens:
1. Claude Code triggers the `SessionStart` hook with `source: "compact"`
2. The `matcher: "compact"` filter ensures the hook only fires after compaction
3. Claude receives the reminder directly in its context
4. Claude re-reads AGENTS.md before proceeding

---

## Design Philosophy

**1. Simplicity.**
A single `SessionStart` hook with `matcher: "compact"` detects compaction and injects the reminder directly. No marker files, no multi-hook coordination -- just one hook that fires at the right time.

**2. Atomic file operations.**
Every modification to `settings.json` is written to a temp file first, then moved into place with `shutil.move()`. If the process crashes mid-write, your settings file stays intact. Backups are created automatically before every modification.

**3. One installer, complete functionality.**
The entire project is a single installer script that generates the hook script and configures settings.json. No frameworks, no build steps, no node_modules.

**4. Fail loudly, succeed quietly.**
The installer validates dependencies, tests the hook after installation, and reports clear errors if anything goes wrong. When everything works, you get a concise summary and a reminder to restart Claude Code.

---

## Installation

### Quick Install

```bash
curl -fsSL https://github.com/Dicklesworthstone/post_compact_reminder/raw/refs/heads/main/install-post-compact-reminder.sh | bash
```

### Download and Run Locally

```bash
curl -fsSL https://github.com/Dicklesworthstone/post_compact_reminder/raw/refs/heads/main/install-post-compact-reminder.sh \
  -o install-post-compact-reminder.sh
chmod +x install-post-compact-reminder.sh
./install-post-compact-reminder.sh
```

### Preview Before Installing

```bash
./install-post-compact-reminder.sh --dry-run
```

### Requirements

| Dependency | Purpose | Auto-installed? |
|------------|---------|-----------------|
| `bash` 4.0+ | Script interpreter | Included on all modern systems |
| `jq` | JSON manipulation | Yes (apt, brew, dnf, yum, pacman) |
| `python3` | Atomic JSON manipulation for `settings.json` | Yes (apt, brew, dnf, yum, pacman) |
| `curl` | Self-update functionality (`--update`) | Usually pre-installed |

The installer detects your package manager and offers to auto-install missing dependencies.

---

## Quick Start

1. **Run the installer:**
   ```bash
   ./install-post-compact-reminder.sh
   ```

2. **Restart Claude Code** (required for hooks to load)

3. **That's it.** Next time context compacts, Claude will automatically see:
   ```
   🚨 IMPORTANT: Context was just compacted. STOP. You MUST:
   1. Read AGENTS.md NOW
   2. Confirm by briefly stating what key rules/conventions you found

   Do not proceed with any task until you have read the file and confirmed what you learned.
   ```

4. **Optionally customize** the reminder message:
   ```bash
   # Interactive template picker
   ./install-post-compact-reminder.sh --interactive

   # Or apply a preset directly
   ./install-post-compact-reminder.sh --template detailed

   # Or set a custom message non-interactively
   ./install-post-compact-reminder.sh --message "🚨 MANDATORY: Context compacted. Read AGENTS.md NOW."
   ./install-post-compact-reminder.sh --message-file ./my-reminder.txt
   ```

---

## Command Reference

### Installation

```bash
./install-post-compact-reminder.sh              # Install (idempotent)
./install-post-compact-reminder.sh --force       # Reinstall even if up to date
./install-post-compact-reminder.sh --dry-run     # Preview changes, modify nothing
./install-post-compact-reminder.sh --yes         # Skip confirmation prompts
./install-post-compact-reminder.sh --skip-deps   # Do not auto-install missing dependencies
./install-post-compact-reminder.sh --uninstall   # Remove hooks and settings entries
./install-post-compact-reminder.sh --repair      # Repair installation and sync settings
```

### Customization

```bash
./install-post-compact-reminder.sh --interactive         # Interactive template picker
./install-post-compact-reminder.sh --template minimal    # Apply preset: mandatory short message
./install-post-compact-reminder.sh --template detailed   # Apply preset: step-by-step instructions
./install-post-compact-reminder.sh --template checklist  # Apply preset: markdown checklist
./install-post-compact-reminder.sh --template default    # Apply preset: standard message
./install-post-compact-reminder.sh --message "..."       # Custom message (single-line)
./install-post-compact-reminder.sh --message-file ./msg.txt  # Custom message from file
./install-post-compact-reminder.sh --update-reminder-message # Update message interactively
./install-post-compact-reminder.sh --update-reminder-message "🚨 MANDATORY: Read AGENTS.md NOW."
./install-post-compact-reminder.sh --update-reminder-message-file ./msg.txt
./install-post-compact-reminder.sh --show-template       # Show currently installed message
```

### Diagnostics

```bash
./install-post-compact-reminder.sh --status     # Full health check (scripts, settings, deps, hook test)
./install-post-compact-reminder.sh --status --json  # JSON status output for automation
./install-post-compact-reminder.sh --doctor     # Run hook self-tests
./install-post-compact-reminder.sh --diff       # Compare installed vs. available version
./install-post-compact-reminder.sh --verbose    # Enable debug output during any operation
./install-post-compact-reminder.sh --log out.log  # Log all operations to file
```

### Maintenance

```bash
./install-post-compact-reminder.sh --update     # Self-update installer from GitHub
./install-post-compact-reminder.sh --restore    # Restore settings.json from automatic backup
./install-post-compact-reminder.sh --changelog  # Show version history
./install-post-compact-reminder.sh --completions bash >> ~/.bashrc   # Shell completions
./install-post-compact-reminder.sh --completions zsh >> ~/.zshrc     # Zsh completions
```

### Output Control

```bash
./install-post-compact-reminder.sh --quiet      # Suppress non-essential output
./install-post-compact-reminder.sh --no-color   # Disable ANSI color codes
./install-post-compact-reminder.sh --no-unicode # ASCII-only output
```

Environment overrides:
- `NO_COLOR=1` disables ANSI colors automatically
- `NO_UNICODE=1` forces ASCII-only output

Automatic output detection:
- If stdout is not a TTY or `TERM=dumb`, the installer auto-disables colors and Unicode for clean logs.

### Aliases

- `--remove` is the same as `--uninstall`
- `--sync` is the same as `--repair`
- `--check` is the same as `--status`
- `--self-test` is the same as `--doctor`
- `--plain` is the same as `--no-unicode`
- `--update-message` / `--update-message-file` are aliases for `--update-reminder-message` / `--update-reminder-message-file`

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HOOK_DIR` | Where to install the hook script | `~/.local/bin` |
| `SETTINGS_DIR` | Where to find/create `settings.json` | `~/.claude` |

```bash
# Example: custom install locations
HOOK_DIR=/opt/hooks SETTINGS_DIR=/etc/claude \
  ./install-post-compact-reminder.sh
```

---

## Configuration

The installer creates one hook script and one settings entry:

### Hook Script: `~/.local/bin/claude-post-compact-reminder`

```bash
#!/usr/bin/env bash
# Version: 1.2.4
# SessionStart hook: Inject reminder after context compaction

set -e

# Read JSON input from stdin (Claude Code passes session info)
INPUT=$(cat)

# Verify this is a compact event (belt-and-suspenders with the matcher)
SOURCE=$(echo "$INPUT" | jq -r '.source // empty' 2>/dev/null || true)
if [[ "$SOURCE" != "compact" ]]; then
    exit 0
fi

MESSAGE="🚨 IMPORTANT: Context was just compacted. STOP. You MUST:
1. Read AGENTS.md NOW
2. Confirm by briefly stating what key rules/conventions you found

Do not proceed with any task until you have read the file and confirmed what you learned."

echo ""
printf '%s\n' "$MESSAGE"
echo ""

exit 0
```

### Settings Entry: `~/.claude/settings.json`

The installer adds (or merges) this into your existing settings:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.local/bin/claude-post-compact-reminder"
          }
        ]
      }
    ]
  }
}
```

---

## Architecture

```
Long coding session...
        │
        ▼
┌─────────────────────────────────────┐
│  Context window fills up            │
│  Claude Code triggers compaction    │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  Compaction completes               │
│  SessionStart hook fires            │
│  with source: "compact"             │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  matcher: "compact" matches         │
│  Hook script runs                   │
│  Outputs reminder to stdout         │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  Claude sees the reminder in its    │
│  context and re-reads AGENTS.md     │
└─────────────────────────────────────┘
```

---

## Message Templates

The installer includes four built-in templates. All templates use mandatory, directive language **with confirmation requirements** to ensure Claude actually reads AGENTS.md and confirms what it learned, rather than treating it as a polite suggestion to ignore.

### `minimal`
```
🚨 MANDATORY: Context compacted. Read AGENTS.md NOW. Confirm by stating what you learned.
```

### `detailed`
```
🚨 MANDATORY: Context was just compacted. STOP. BEFORE doing anything else, you MUST:
1. Read AGENTS.md completely
2. Check the current task list
3. Review recent git commits (git log --oneline -5)
4. Verify any uncommitted changes (git status)

After completing these steps, confirm by briefly stating what key rules you found in AGENTS.md.
DO NOT proceed with any other work until you have confirmed.
```

### `checklist`
```
🚨 MANDATORY: Context compacted. STOP. Complete ALL items before continuing:
- [ ] Read AGENTS.md completely
- [ ] Check task list (/tasks)
- [ ] Review recent commits
- [ ] Run test suite
- [ ] Check git status

After completing, confirm by stating: "I have completed the checklist. Key AGENTS.md rules: [list them]"
DO NOT proceed until you have confirmed.
```

### `default`
```
🚨 IMPORTANT: Context was just compacted. STOP. You MUST:
1. Read AGENTS.md NOW
2. Confirm by briefly stating what key rules/conventions you found

Do not proceed with any task until you have read the file and confirmed what you learned.
```

### Custom Messages

Use `--interactive` to enter any message you want, or edit the hook script directly:

```bash
nano ~/.local/bin/claude-post-compact-reminder
```

Modify the `MESSAGE=` text in the hook script. Changes take effect immediately (no restart needed).

---

## Troubleshooting

### Hook doesn't fire after compaction

```bash
# Check installation health
./install-post-compact-reminder.sh --status

# Run the self-tests
./install-post-compact-reminder.sh --doctor

# Verify the hook script exists and is executable
ls -la ~/.local/bin/claude-post-compact-reminder

# Verify settings.json has the hook entry
cat ~/.claude/settings.json | jq '.hooks.SessionStart'
```

If `--doctor` shows all tests passing but the hook still doesn't fire, restart Claude Code. Hooks are loaded at startup.

### `jq` or `python3` not found

The installer auto-detects your package manager and offers to install missing dependencies:

```bash
# Ubuntu/Debian
sudo apt install jq python3

# macOS
brew install jq python

# Fedora/RHEL
sudo dnf install jq python3

# Arch
sudo pacman -S jq python
```

Or re-run the installer, which auto-installs missing dependencies.

### Settings.json is corrupted

The installer creates a `.bak` backup before every modification:

```bash
# Restore from backup
./install-post-compact-reminder.sh --restore

# Or manually
cp ~/.claude/settings.json.bak ~/.claude/settings.json
```

### Another instance is running

The installer uses a PID lock file to prevent concurrent runs. If a previous run crashed:

```bash
rm /tmp/.post-compact-reminder-*.lock
```

---

## Limitations

- **Global only.** The hooks install to `~/.claude/settings.json`, which applies to all projects. There's no per-project override mechanism built in (though you could use `SETTINGS_DIR` to point at a project-local settings file).
- **No Windows support.** This is a Bash script. It works on Linux, macOS, and WSL.

---

## FAQ

### Why plain-text output?

Claude Code injects the hook's stdout directly into the conversation. A short plain-text reminder is enough for Claude to act on it and keeps the hook minimal and easy to customize.

### Does this work with Claude Code in VS Code / JetBrains?

Yes. The `settings.json` hook configuration works across all Claude Code interfaces: CLI, VS Code extension, and JetBrains plugin. They all share the same `~/.claude/settings.json`.

### Can I add more files to the reminder (not just AGENTS.md)?

Yes. Edit the hook script or use `--interactive`, `--message`, or `--message-file` to enter a custom message:

```
🚨 MANDATORY: Context compacted. STOP. You MUST:
1. Read AGENTS.md completely
2. Read docs/ARCHITECTURE.md
3. Check .env.example for required environment variables

Confirm by stating what key rules you found. Do not proceed until confirmed.
```

### How do I update the hook when a new version comes out?

```bash
# Update the installer itself
./install-post-compact-reminder.sh --update

# Then re-run to update the hook script
./install-post-compact-reminder.sh --force
```

### Can I use this without an AGENTS.md?

Yes, but it's less useful. The default message tells Claude to re-read AGENTS.md. If you don't have one, use `--interactive` or `--template` to set a custom message appropriate for your workflow.

### What happens if I run the installer twice?

Nothing bad. The installer is idempotent: it detects existing installations, compares versions, and skips if already up to date. Use `--force` to reinstall anyway.

---

## Related

- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks): Official reference for all hook types
- [compact-canon](https://github.com/tonydzi/compact-canon): Complementary community project attacking the same amnesia from the other side. This hook restores your *standing rules* after compaction; compact-canon is a measured paste-block format that preserves the *session-specific* layer (rejected alternatives, exact paths/IDs, mid-flight state) through a manual `/compact`. Their measurements: bare `/compact` used the stock template 354/354 times, while an inline structured block survived 7/7 headers and 15/15 seeded facts. The two mechanisms compose.
- [ClaudeCode-RulesAfterCompact-Windows-AutoHook](https://github.com/miradorventus/ClaudeCode-RulesAfterCompact-Windows-AutoHook): Community-built Windows counterpart (independent implementation, credited to this project as the origin of the approach). The `matcher: "compact"` mechanism carries over to Windows unchanged; only this repo's POSIX installer doesn't.

### Note for Windows users hand-rolling this hook

PowerShell re-encodes hook stdout in the console's codepage on the way out, while Claude Code decodes it as UTF-8 — silently corrupting non-ASCII characters (this repo's templates open with `🚨`, which becomes a literal `?` under cp1252/cp850). The trap: `[Console]::OutputEncoding.WebName` can *report* `utf-8` while output is still being mangled, because reading the property doesn't rebuild the cached stdout writer. The fix is to **assign** it in the hook script:

```powershell
[Console]::OutputEncoding = [Text.UTF8Encoding]::new(0)
```

(Credit: the miradorventus repo above, which documented this per-machine-dependent failure mode with byte-level evidence.)

---

## About Contributions

Please don't take this the wrong way, but I do not accept outside contributions for any of my projects. I simply don't have the mental bandwidth to review anything, and it's my name on the thing, so I'm responsible for any problems it causes; thus, the risk-reward is highly asymmetric from my perspective. I'd also have to worry about other "stakeholders," which seems unwise for tools I mostly make for myself for free. Feel free to submit issues, and even PRs if you want to illustrate a proposed fix, but know I won't merge them directly. Instead, I'll have Claude or Codex review submissions via `gh` and independently decide whether and how to address them. Bug reports in particular are welcome. Sorry if this offends, but I want to avoid wasted time and hurt feelings. I understand this isn't in sync with the prevailing open-source ethos that seeks community contributions, but it's the only way I can move at this velocity and keep my sanity.

---

## License

MIT License (with OpenAI/Anthropic Rider). See [LICENSE](LICENSE).

---

*Created: January 2026*

# Post-Compact Reminder for Claude Code

<div align="center">
  <img src="pcr_illustration.webp" alt="Post-Compact Reminder - Stop Claude from forgetting your project rules after context compaction">
</div>

<div align="center">

**Stop Claude from forgetting your project rules after context compaction.**

[![CI](https://github.com/Dicklesworthstone/post_compact_reminder/actions/workflows/ci.yml/badge.svg)](https://github.com/Dicklesworthstone/post_compact_reminder/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT%2BOpenAI%2FAnthropic%20Rider-blue.svg)](./LICENSE)
[![Bash 4.0+](https://img.shields.io/badge/bash-4.0%2B-blue?style=flat-square)](https://www.gnu.org/software/bash/)

</div>

<div align="center">
<h3>Quick Install (Recommended)</h3>

```bash
curl -fsSL https://github.com/Dicklesworthstone/post_compact_reminder/raw/refs/heads/main/install-post-compact-reminder-workaround.sh | bash
```

</div>

---

## TL;DR

**The Problem:** During long coding sessions, Claude Code compacts the conversation to stay within context limits. After compaction, Claude loses all memory of your project's AGENTS.md, the file that defines your coding conventions, forbidden commands, architectural decisions, multi-agent coordination rules, and everything else that keeps Claude on the rails. The result: Claude starts freelancing, ignoring your rules, deleting files you told it never to delete, and generally going on a post-compaction rampage.

**The Solution:** A hook system that detects compaction events and injects a short plain-text reminder telling Claude to re-read AGENTS.md before doing anything else. One install, zero maintenance, works globally across all your projects.

---

## Why "Workaround" Version?

There are two versions of this tool:

| Version | File | Mechanism | Status |
|---------|------|-----------|--------|
| **Workaround** (recommended) | `install-post-compact-reminder-workaround.sh` | PreCompact + UserPromptSubmit hooks with marker file | **Works reliably** |
| Ideal | `install-post-compact-reminder.sh` | SessionStart hook with `compact` matcher | Waiting for bug fix |

**The workaround version is the default because of a bug in Claude Code** ([#15174](https://github.com/anthropics/claude-code/issues/15174), [#13650](https://github.com/anthropics/claude-code/issues/13650)): The `SessionStart` hook with `matcher: "compact"` doesn't actually inject its stdout into Claude's context. The hook fires, but Claude never sees the reminder message.

The workaround uses a different mechanism that reliably works:

1. **PreCompact hook** writes a marker file when compaction is about to happen
2. **UserPromptSubmit hook** checks for the marker on your next message
3. If the marker exists, it injects the reminder and deletes the marker

This ensures the reminder appears on your **first message after compaction**, which is when Claude needs it most.

Once the bug is fixed, you can switch to the ideal SessionStart version, but for now, **use the workaround**.

---

### Why Use Post-Compact Reminder?

| Feature | What It Does |
|---------|--------------|
| **Automatic detection** | Fires only after compaction, not on normal startups |
| **Zero-config** | Installs globally in `~/.local/bin` and `~/.claude/settings.json`; works in every project |
| **Customizable messages** | 4 built-in templates (minimal, detailed, checklist, default) + custom messages |
| **Reliable injection** | Workaround mechanism ensures Claude actually sees the reminder |
| **Idempotent installer** | Safe to run repeatedly; detects existing installs, handles upgrades, creates backups |
| **Self-updating** | `--update` pulls the latest installer from GitHub |

---

## Quick Example

```bash
# Install the workaround hook (one command, globally)
./install-post-compact-reminder-workaround.sh

# Check installation health anytime
./install-post-compact-reminder-workaround.sh --status

# Test the hook manually
./install-post-compact-reminder-workaround.sh --doctor
```

After installation, when compaction happens:
1. The PreCompact hook writes a marker file
2. On your next message, the UserPromptSubmit hook sees the marker
3. Claude receives the reminder in its context
4. The marker is deleted (one-shot, no repeats)

---

## Design Philosophy

**1. Reliability over elegance.**
The ideal SessionStart approach is cleaner, but it doesn't work due to a Claude Code bug. The workaround uses a two-hook + marker-file mechanism that's slightly more complex but actually delivers the reminder to Claude.

**2. Atomic file operations.**
Every modification to `settings.json` is written to a temp file first, then moved into place with `shutil.move()`. If the process crashes mid-write, your settings file stays intact. Backups are created automatically before every modification.

**3. One installer, complete functionality.**
The entire project is a single installer script that generates the hook scripts and configures settings.json. No frameworks, no build steps, no node_modules.

**4. Fail loudly, succeed quietly.**
The installer validates dependencies, tests the hook after installation, and reports clear errors if anything goes wrong. When everything works, you get a concise summary and a reminder to restart Claude Code.

---

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://github.com/Dicklesworthstone/post_compact_reminder/raw/refs/heads/main/install-post-compact-reminder-workaround.sh | bash
```

### Download and Run Locally

```bash
curl -fsSL https://github.com/Dicklesworthstone/post_compact_reminder/raw/refs/heads/main/install-post-compact-reminder-workaround.sh \
  -o install-post-compact-reminder-workaround.sh
chmod +x install-post-compact-reminder-workaround.sh
./install-post-compact-reminder-workaround.sh
```

### Preview Before Installing

```bash
./install-post-compact-reminder-workaround.sh --dry-run
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
   ./install-post-compact-reminder-workaround.sh
   ```

2. **Restart Claude Code** (required for hooks to load)

3. **That's it.** Next time context compacts and you send a message, Claude will automatically see:
   ```
   🚨 IMPORTANT: Context was just compacted. STOP. You MUST:
   1. Read AGENTS.md NOW
   2. Confirm by briefly stating what key rules/conventions you found

   Do not proceed with any task until you have read the file and confirmed what you learned.
   ```

4. **Optionally customize** the reminder message:
   ```bash
   # Interactive template picker
   ./install-post-compact-reminder-workaround.sh --interactive

   # Or apply a preset directly
   ./install-post-compact-reminder-workaround.sh --template detailed

   # Or set a custom message non-interactively
   ./install-post-compact-reminder-workaround.sh --message "🚨 MANDATORY: Context compacted. Read AGENTS.md NOW."
   ./install-post-compact-reminder-workaround.sh --message-file ./my-reminder.txt
   ```

---

## Command Reference

### Installation

```bash
./install-post-compact-reminder-workaround.sh              # Install (idempotent)
./install-post-compact-reminder-workaround.sh --force       # Reinstall even if up to date
./install-post-compact-reminder-workaround.sh --dry-run     # Preview changes, modify nothing
./install-post-compact-reminder-workaround.sh --yes         # Skip confirmation prompts
./install-post-compact-reminder-workaround.sh --skip-deps   # Do not auto-install missing dependencies
./install-post-compact-reminder-workaround.sh --uninstall   # Remove hooks and settings entries
./install-post-compact-reminder-workaround.sh --repair      # Repair installation and sync settings
```

### Customization

```bash
./install-post-compact-reminder-workaround.sh --interactive         # Interactive template picker
./install-post-compact-reminder-workaround.sh --template minimal    # Apply preset: mandatory short message
./install-post-compact-reminder-workaround.sh --template detailed   # Apply preset: step-by-step instructions
./install-post-compact-reminder-workaround.sh --template checklist  # Apply preset: markdown checklist
./install-post-compact-reminder-workaround.sh --template default    # Apply preset: standard message
./install-post-compact-reminder-workaround.sh --message "..."       # Custom message (single-line)
./install-post-compact-reminder-workaround.sh --message-file ./msg.txt  # Custom message from file
./install-post-compact-reminder-workaround.sh --update-reminder-message # Update message interactively
./install-post-compact-reminder-workaround.sh --update-reminder-message "🚨 MANDATORY: Read AGENTS.md NOW."
./install-post-compact-reminder-workaround.sh --update-reminder-message-file ./msg.txt
./install-post-compact-reminder-workaround.sh --show-template       # Show currently installed message
```

### Diagnostics

```bash
./install-post-compact-reminder-workaround.sh --status     # Full health check (scripts, settings, deps, hook test)
./install-post-compact-reminder-workaround.sh --status --json  # JSON status output for automation
./install-post-compact-reminder-workaround.sh --doctor     # Run hook self-tests
./install-post-compact-reminder-workaround.sh --diff       # Compare installed vs. available version
./install-post-compact-reminder-workaround.sh --verbose    # Enable debug output during any operation
./install-post-compact-reminder-workaround.sh --log out.log  # Log all operations to file
```

### Maintenance

```bash
./install-post-compact-reminder-workaround.sh --update     # Self-update installer from GitHub
./install-post-compact-reminder-workaround.sh --restore    # Restore settings.json from automatic backup
./install-post-compact-reminder-workaround.sh --changelog  # Show version history
./install-post-compact-reminder-workaround.sh --completions bash >> ~/.bashrc   # Shell completions
./install-post-compact-reminder-workaround.sh --completions zsh >> ~/.zshrc     # Zsh completions
```

### Output Control

```bash
./install-post-compact-reminder-workaround.sh --quiet      # Suppress non-essential output
./install-post-compact-reminder-workaround.sh --no-color   # Disable ANSI color codes
./install-post-compact-reminder-workaround.sh --no-unicode # ASCII-only output
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
| `HOOK_DIR` | Where to install the hook scripts | `~/.local/bin` |
| `SETTINGS_DIR` | Where to find/create `settings.json` | `~/.claude` |

```bash
# Example: custom install locations
HOOK_DIR=/opt/hooks SETTINGS_DIR=/etc/claude \
  ./install-post-compact-reminder-workaround.sh
```

---

## Configuration

The workaround installer creates three files:

### PreCompact Hook: `~/.local/bin/claude-precompact-marker`

```bash
#!/usr/bin/env bash
# Version: 1.2.4
# PreCompact hook: Write marker file when compaction is about to happen

set -e

MARKER_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-compact-reminder"
MARKER_FILE="$MARKER_DIR/compact-pending"

# Ensure marker directory exists
mkdir -p "$MARKER_DIR"

# Write timestamp to marker file
date -Iseconds > "$MARKER_FILE"

exit 0
```

### UserPromptSubmit Hook: `~/.local/bin/claude-prompt-compact-check`

```bash
#!/usr/bin/env bash
# Version: 1.2.4
# UserPromptSubmit hook: Check for compact marker and inject reminder

set -e

MARKER_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-compact-reminder"
MARKER_FILE="$MARKER_DIR/compact-pending"
MESSAGE="🚨 IMPORTANT: Context was just compacted. STOP. You MUST:
1. Read AGENTS.md NOW
2. Confirm by briefly stating what key rules/conventions you found

Do not proceed with any task until you have read the file and confirmed what you learned."

# Check if marker file exists
if [[ -f "$MARKER_FILE" ]]; then
    # Remove the marker file FIRST to prevent duplicate reminders
    rm -f "$MARKER_FILE"

    # Output the reminder - this gets injected into Claude's context
    echo ""
    printf '%s\n' "$MESSAGE"
    echo ""
fi

exit 0
```

### Settings Entries: `~/.claude/settings.json`

The installer adds (or merges) these into your existing settings:

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.local/bin/claude-precompact-marker"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.local/bin/claude-prompt-compact-check"
          }
        ]
      }
    ]
  }
}
```

---

## Architecture (Workaround Version)

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
│  PreCompact hook fires              │
│  Writes marker file with timestamp  │
│  ~/.local/state/claude-compact-     │
│  reminder/compact-pending           │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  Compaction completes               │
│  Claude has fresh, empty context    │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  User sends next message            │
│  UserPromptSubmit hook fires        │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  Hook checks for marker file        │
│  Marker exists → inject reminder    │
│  Delete marker (one-shot)           │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  Claude sees the reminder in its    │
│  context and re-reads AGENTS.md     │
└─────────────────────────────────────┘
```

### Why This Mechanism?

The ideal approach would use a `SessionStart` hook with `matcher: "compact"` to inject the reminder directly when the session restarts after compaction. However, due to Claude Code bugs [#15174](https://github.com/anthropics/claude-code/issues/15174) and [#13650](https://github.com/anthropics/claude-code/issues/13650), the SessionStart hook's stdout is not injected into context.

The workaround uses two hooks that work reliably:
- **PreCompact**: Fires before compaction, lets us leave a "breadcrumb"
- **UserPromptSubmit**: Fires on every user message, lets us inject content into context

The marker file bridges the gap between these two events.

### How Hooks Compare

| Hook | When It Fires | Can Inject Context? | Use Case |
|------|---------------|---------------------|----------|
| **PreCompact** | Before compaction starts | No (too early) | Write marker file |
| **SessionStart** | Session begins | No (bug) | Would be ideal, currently broken |
| **UserPromptSubmit** | User sends a message | Yes (stdout injected) | Inject reminder |
| **PreToolUse** | Before a tool executes | Yes (can block) | Block dangerous commands |

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
nano ~/.local/bin/claude-prompt-compact-check
```

Modify the `MESSAGE=` text in the hook script. Changes take effect immediately (no restart needed).

---

## Troubleshooting

### Hook doesn't fire after compaction

```bash
# Check installation health
./install-post-compact-reminder-workaround.sh --status

# Run the self-tests
./install-post-compact-reminder-workaround.sh --doctor

# Verify both hook scripts exist and are executable
ls -la ~/.local/bin/claude-precompact-marker
ls -la ~/.local/bin/claude-prompt-compact-check

# Verify settings.json has both hook entries
cat ~/.claude/settings.json | jq '.hooks.PreCompact, .hooks.UserPromptSubmit'
```

If `--doctor` shows all tests passing but the hook still doesn't fire, restart Claude Code. Hooks are loaded at startup.

### Reminder appears on every message (not just after compaction)

This would mean the marker file isn't being deleted. Check:

```bash
# Should NOT exist unless compaction just happened
ls -la ~/.local/state/claude-compact-reminder/compact-pending

# If it exists when it shouldn't, delete it
rm ~/.local/state/claude-compact-reminder/compact-pending
```

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
./install-post-compact-reminder-workaround.sh --restore

# Or manually
cp ~/.claude/settings.json.bak ~/.claude/settings.json
```

### Another instance is running

The installer uses a PID lock file to prevent concurrent runs. If a previous run crashed:

```bash
rm /tmp/.post-compact-reminder-workaround-*.lock
```

---

## The "Ideal" Version (Currently Broken)

For reference, there's also `install-post-compact-reminder.sh` which uses the cleaner SessionStart approach:

```bash
# DON'T USE THIS YET - waiting for Claude Code bug fix
./install-post-compact-reminder.sh
```

This version:
- Uses a single `SessionStart` hook with `matcher: "compact"`
- Parses JSON input to verify `source: "compact"`
- Outputs the reminder directly

It's the cleaner approach, but due to Claude Code bugs [#15174](https://github.com/anthropics/claude-code/issues/15174) and [#13650](https://github.com/anthropics/claude-code/issues/13650), the stdout from SessionStart hooks isn't injected into context. Once these bugs are fixed, this version will be the recommended approach.

---

## Limitations

- **Reminder appears on next message, not immediately.** The workaround can only inject the reminder when you send your next message after compaction. This is slightly delayed compared to the ideal SessionStart approach, but in practice you'll almost always send a message right after compaction anyway.
- **Global only.** The hooks install to `~/.claude/settings.json`, which applies to all projects. There's no per-project override mechanism built in (though you could use `SETTINGS_DIR` to point at a project-local settings file).
- **No Windows support.** This is a Bash script. It works on Linux, macOS, and WSL.

---

## FAQ

### Why is there a "workaround" version?

Claude Code has a bug where `SessionStart` hooks with `matcher: "compact"` don't inject their stdout into context. The workaround uses `PreCompact` + `UserPromptSubmit` hooks with a marker file to reliably deliver the reminder. Once the bug is fixed, the simpler SessionStart version will become the default.

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

### Does the PreCompact hook block compaction?

No. The PreCompact hook runs before compaction but doesn't block it. It just writes a marker file so the UserPromptSubmit hook knows compaction happened.

### How do I update the hook when a new version comes out?

```bash
# Update the installer itself
./install-post-compact-reminder-workaround.sh --update

# Then re-run to update the hook scripts
./install-post-compact-reminder-workaround.sh --force
```

### Can I use this without an AGENTS.md?

Yes, but it's less useful. The default message tells Claude to re-read AGENTS.md. If you don't have one, use `--interactive` or `--template` to set a custom message appropriate for your workflow.

### What happens if I run the installer twice?

Nothing bad. The installer is idempotent: it detects existing installations, compares versions, and skips if already up to date. Use `--force` to reinstall anyway.

### Can I switch from workaround to ideal version later?

Yes. First uninstall the workaround:
```bash
./install-post-compact-reminder-workaround.sh --uninstall
```

Then install the ideal version (once the bug is fixed):
```bash
./install-post-compact-reminder.sh
```

---

## Related

- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks): Official reference for all hook types
- [GitHub Issue #15174](https://github.com/anthropics/claude-code/issues/15174): SessionStart compact matcher stdout not injected
- [GitHub Issue #13650](https://github.com/anthropics/claude-code/issues/13650): Related SessionStart hook issue

---

## About Contributions

Please don't take this the wrong way, but I do not accept outside contributions for any of my projects. I simply don't have the mental bandwidth to review anything, and it's my name on the thing, so I'm responsible for any problems it causes; thus, the risk-reward is highly asymmetric from my perspective. I'd also have to worry about other "stakeholders," which seems unwise for tools I mostly make for myself for free. Feel free to submit issues, and even PRs if you want to illustrate a proposed fix, but know I won't merge them directly. Instead, I'll have Claude or Codex review submissions via `gh` and independently decide whether and how to address them. Bug reports in particular are welcome. Sorry if this offends, but I want to avoid wasted time and hurt feelings. I understand this isn't in sync with the prevailing open-source ethos that seeks community contributions, but it's the only way I can move at this velocity and keep my sanity.

---

## License

MIT License (with OpenAI/Anthropic Rider). See [LICENSE](LICENSE).

---

*Created: January 2026*

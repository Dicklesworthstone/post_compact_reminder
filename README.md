# Post-Compact Reminder for Claude Code

<div align="center">

**Stop Claude from forgetting your project rules after context compaction.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash 4.0+](https://img.shields.io/badge/bash-4.0%2B-blue?style=flat-square)](https://www.gnu.org/software/bash/)
[![Hook: SessionStart](https://img.shields.io/badge/hook-SessionStart-green?style=flat-square)](https://docs.anthropic.com/en/docs/claude-code/hooks)

</div>

<div align="center">
<h3>Quick Install</h3>

```bash
curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/post_compact_reminder/main/install-post-compact-reminder.sh | bash
```

</div>

---

## TL;DR

**The Problem:** During long coding sessions, Claude Code compacts the conversation to stay within context limits. After compaction, Claude loses all memory of your project's AGENTS.md -- the file that defines your coding conventions, forbidden commands, architectural decisions, multi-agent coordination rules, and everything else that keeps Claude on the rails. The result: Claude starts freelancing, ignoring your rules, deleting files you told it never to delete, and generally going on a post-compaction rampage.

**The Solution:** A `SessionStart` hook that detects compaction events and injects a short XML reminder telling Claude to re-read AGENTS.md before doing anything else. One install, zero maintenance, works globally across all your projects.

### Why Use Post-Compact Reminder?

| Feature | What It Does |
|---------|--------------|
| **Automatic detection** | Fires only after compaction (`source: "compact"`), not on normal startups |
| **Zero-config** | Installs globally in `~/.local/bin` and `~/.claude/settings.json` -- works in every project |
| **Customizable messages** | 4 built-in templates (minimal, detailed, checklist, default) + custom messages |
| **Non-blocking** | SessionStart hooks don't block Claude's workflow -- the reminder is injected instantly |
| **Idempotent installer** | Safe to run repeatedly; detects existing installs, handles upgrades, creates backups |
| **Self-updating** | `--update` pulls the latest installer from GitHub |

---

## Quick Example

```bash
# Install the hook (one command, globally)
./install-post-compact-reminder.sh

# Verify it's working
echo '{"session_id": "test-123", "source": "compact"}' | \
  ~/.local/bin/claude-post-compact-reminder

# Output:
# <post-compact-reminder>
# Context was just compacted. Please reread AGENTS.md to refresh your understanding
# of project conventions and agent coordination patterns.
# </post-compact-reminder>

# Verify normal startups produce no output (correct behavior)
echo '{"session_id": "test-123", "source": "startup"}' | \
  ~/.local/bin/claude-post-compact-reminder
# (no output -- exactly right)

# Check installation health anytime
./install-post-compact-reminder.sh --status
```

---

## Design Philosophy

**1. Belt and suspenders.**
The `matcher: "compact"` field in `settings.json` tells Claude Code to only invoke the hook after compaction events. The hook script *also* checks the `source` field in the JSON input. Redundant? Yes. Robust? Also yes.

**2. Atomic file operations.**
Every modification to `settings.json` is written to a temp file first, then moved into place with `shutil.move()`. If the process crashes mid-write, your settings file stays intact. Backups are created automatically before every modification.

**3. One file, one purpose.**
The entire project is a single installer script (`install-post-compact-reminder.sh`) that generates a single hook script (`claude-post-compact-reminder`). No frameworks, no build steps, no node_modules.

**4. Fail loudly, succeed quietly.**
The installer validates dependencies, tests the hook after installation, and reports clear errors if anything goes wrong. When everything works, you get a concise summary and a reminder to restart Claude Code.

---

## How It Compares

| Capability | Post-Compact Reminder | Manual AGENTS.md re-read | Custom PreToolUse hook | No mitigation |
|------------|----------------------|--------------------------|----------------------|---------------|
| Fires automatically after compaction | Yes | No | No | No |
| Requires user intervention each time | No | Yes (every compaction) | No | N/A |
| Targets compaction specifically | Yes (matcher + source check) | N/A | Possible but complex | N/A |
| Installs globally (all projects) | Yes | N/A | Possible | N/A |
| Message customization | 4 templates + custom | N/A | Full control | N/A |
| Setup effort | One command | Repeated manual effort | Write your own hook | None |
| Non-blocking | Yes (SessionStart) | N/A | Depends (PreToolUse blocks) | N/A |

**When to use Post-Compact Reminder:**
- You have an AGENTS.md with conventions Claude should always follow
- You run long coding sessions where compaction happens regularly
- You use multi-agent workflows where consistency matters

**When it might not be enough:**
- If you need Claude to re-read files beyond AGENTS.md, customize the message template to include additional instructions
- If you need to block Claude from acting before re-reading, you'd need a PreToolUse hook instead (this is a non-blocking SessionStart hook)

---

## Installation

### Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/post_compact_reminder/main/install-post-compact-reminder.sh | bash
```

### Download and Run Locally

```bash
curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/post_compact_reminder/main/install-post-compact-reminder.sh \
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
| `jq` | Parse JSON input from Claude Code | Yes (apt, brew, dnf, yum, pacman) |
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
   ```xml
   <post-compact-reminder>
   Context was just compacted. Please reread AGENTS.md to refresh your understanding
   of project conventions and agent coordination patterns.
   </post-compact-reminder>
   ```

4. **Optionally customize** the reminder message:
   ```bash
   # Interactive template picker
   ./install-post-compact-reminder.sh --interactive

   # Or apply a preset directly
   ./install-post-compact-reminder.sh --template detailed

   # Or set a custom message non-interactively
   ./install-post-compact-reminder.sh --message "Context compacted. Re-read AGENTS.md."
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
./install-post-compact-reminder.sh --uninstall   # Remove hook and settings entry
```

### Customization

```bash
./install-post-compact-reminder.sh --interactive         # Interactive template picker
./install-post-compact-reminder.sh --template minimal    # Apply preset: "Context compacted. Re-read AGENTS.md."
./install-post-compact-reminder.sh --template detailed   # Apply preset: step-by-step instructions
./install-post-compact-reminder.sh --template checklist  # Apply preset: markdown checklist
./install-post-compact-reminder.sh --template default    # Apply preset: standard message
./install-post-compact-reminder.sh --message "..."       # Custom message (single-line)
./install-post-compact-reminder.sh --message-file ./msg.txt  # Custom message from file
./install-post-compact-reminder.sh --show-template       # Show currently installed message
```

### Diagnostics

```bash
./install-post-compact-reminder.sh --status     # Full health check (script, settings, deps, hook test)
./install-post-compact-reminder.sh --status --json  # JSON status output for automation
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
```

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

The installer creates two files:

### Hook Script: `~/.local/bin/claude-post-compact-reminder`

```bash
#!/usr/bin/env bash
# Version: 1.1.0
# SessionStart hook: Remind Claude to reread AGENTS.md after compaction

set -e

INPUT=$(cat)
SOURCE=$(echo "$INPUT" | jq -r '.source // empty')

if [[ "$SOURCE" == "compact" ]]; then
    cat <<'EOF'
<post-compact-reminder>
Context was just compacted. Please reread AGENTS.md to refresh your understanding
of project conventions and agent coordination patterns.
</post-compact-reminder>
EOF
fi

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

The `matcher: "compact"` field is key -- it tells Claude Code to only invoke this hook when the SessionStart event's input contains `"compact"`, which only happens after context compaction. Normal startups, resumes, and `/clear` commands are ignored.

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
│  SessionStart event fires           │
│  source: "compact"                  │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  settings.json matcher: "compact"   │
│  matches → invokes hook command     │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  claude-post-compact-reminder       │
│  reads JSON stdin, checks source,   │
│  outputs XML reminder to stdout     │
└──────────────────┬──────────────────┘
                   │
                   ▼
┌─────────────────────────────────────┐
│  Claude sees the reminder in its    │
│  context and re-reads AGENTS.md     │
└─────────────────────────────────────┘
```

### How SessionStart Differs from Other Hooks

| Hook | When It Fires | Can Block? | Use Case |
|------|---------------|------------|----------|
| **SessionStart** | Session begins (startup, resume, clear, compact) | No | Inject context, set environment |
| **PreToolUse** | Before a tool executes | Yes | Block dangerous commands |
| **PostToolUse** | After a tool completes | No | Auto-format, lint |
| **UserPromptSubmit** | User sends a message | Yes | Add context to prompts |

The `source` field in SessionStart input tells you *why* the session started:

| Source Value | Meaning |
|--------------|---------|
| `"startup"` | Fresh session |
| `"resume"` | Resumed via `--resume`, `--continue`, or `/resume` |
| `"clear"` | After `/clear` command |
| `"compact"` | Restarted after context compaction |

---

## Message Templates

The installer includes four built-in templates:

### `minimal`
```
Context compacted. Re-read AGENTS.md.
```

### `detailed`
```
Context was just compacted. Please:
1. Re-read AGENTS.md for project conventions
2. Check the current task list
3. Review recent git commits (git log --oneline -5)
4. Verify any uncommitted changes (git status)
```

### `checklist`
```
Context compacted. Before continuing:
- [ ] Re-read AGENTS.md
- [ ] Check task list (/tasks)
- [ ] Review recent commits
- [ ] Run test suite
- [ ] Check git status
```

### `default`
```
Context was just compacted. Please reread AGENTS.md to refresh your understanding
of project conventions and agent coordination patterns.
```

### Custom Messages

Use `--interactive` to enter any message you want, or edit the hook script directly:

```bash
nano ~/.local/bin/claude-post-compact-reminder
```

Modify the text between `<post-compact-reminder>` and `</post-compact-reminder>`, then test:

```bash
echo '{"source":"compact"}' | ~/.local/bin/claude-post-compact-reminder
```

Changes to the hook script take effect immediately -- no restart needed. Only the initial installation requires restarting Claude Code.

---

## Troubleshooting

### Hook doesn't fire after compaction

```bash
# Check installation health
./install-post-compact-reminder.sh --status

# Verify the hook script exists and is executable
ls -la ~/.local/bin/claude-post-compact-reminder

# Verify settings.json has the hook entry
cat ~/.claude/settings.json | jq '.hooks.SessionStart'
```

If `--status` shows everything green but the hook still doesn't fire, restart Claude Code. Hooks are loaded at startup.

### `jq: command not found`

```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq

# Fedora/RHEL
sudo dnf install jq

# Arch
sudo pacman -S jq
```

Or re-run the installer -- it auto-installs missing dependencies.

### Settings.json is corrupted

The installer creates a `.bak` backup before every modification:

```bash
# Restore from backup
./install-post-compact-reminder.sh --restore

# Or manually
cp ~/.claude/settings.json.bak ~/.claude/settings.json
```

### Hook test produces no output

```bash
# This should produce output:
echo '{"source": "compact"}' | ~/.local/bin/claude-post-compact-reminder

# This should produce NO output (correct):
echo '{"source": "startup"}' | ~/.local/bin/claude-post-compact-reminder
```

If the compact test produces no output, check that `jq` is installed and the script has the correct source check.

### Another instance is running

The installer uses a PID lock file at `/tmp/.post-compact-reminder-install.lock` to prevent concurrent runs. If a previous run crashed:

```bash
rm /tmp/.post-compact-reminder-install.lock
```

---

## Limitations

- **SessionStart hooks are non-blocking.** Claude sees the reminder in its context but isn't *forced* to act on it before proceeding. In practice, Claude reliably follows the instruction to re-read AGENTS.md, but there's no hard enforcement mechanism.
- **Global only.** The hook installs to `~/.claude/settings.json`, which applies to all projects. There's no per-project override mechanism built in (though you could use `SETTINGS_DIR` to point at a project-local settings file).
- **Requires `jq` at runtime.** The hook script uses `jq` to parse the JSON input from Claude Code. If `jq` is somehow removed after installation, the hook will silently fail.
- **No Windows support.** This is a Bash script. It works on Linux, macOS, and WSL.

---

## FAQ

### Why XML tags in the output?

The `<post-compact-reminder>` XML wrapper makes the reminder clearly identifiable in Claude's context. Claude Code's hook system injects the stdout of hook scripts into the conversation, and XML tags help Claude parse structured instructions from the noise.

### Does this work with Claude Code in VS Code / JetBrains?

Yes. The `settings.json` hook configuration works across all Claude Code interfaces -- CLI, VS Code extension, and JetBrains plugin. They all share the same `~/.claude/settings.json`.

### Can I add more files to the reminder (not just AGENTS.md)?

Yes. Edit the hook script or use `--interactive`, `--message`, or `--message-file` to enter a custom message:

```
Context compacted. Before continuing:
1. Re-read AGENTS.md
2. Re-read docs/ARCHITECTURE.md
3. Check .env.example for required environment variables
```

### Does the hook fire on `/clear`?

No. The `matcher: "compact"` ensures it only fires when `source` is `"compact"`. The `/clear` command sends `source: "clear"`, which doesn't match.

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

Nothing bad. The installer is idempotent -- it detects existing installations, compares versions, and skips if already up to date. Use `--force` to reinstall anyway.

---

## Related

- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks) -- Official reference for all hook types
- [DESTRUCTIVE_GIT_COMMAND_CLAUDE_HOOKS_SETUP.md](https://github.com/Dicklesworthstone/post_compact_reminder/blob/main/DESTRUCTIVE_GIT_COMMAND_CLAUDE_HOOKS_SETUP.md) -- Block dangerous `git` and `rm` commands with a PreToolUse hook

---

## About Contributions

Please don't take this the wrong way, but I do not accept outside contributions for any of my projects. I simply don't have the mental bandwidth to review anything, and it's my name on the thing, so I'm responsible for any problems it causes; thus, the risk-reward is highly asymmetric from my perspective. I'd also have to worry about other "stakeholders," which seems unwise for tools I mostly make for myself for free. Feel free to submit issues, and even PRs if you want to illustrate a proposed fix, but know I won't merge them directly. Instead, I'll have Claude or Codex review submissions via `gh` and independently decide whether and how to address them. Bug reports in particular are welcome. Sorry if this offends, but I want to avoid wasted time and hurt feelings. I understand this isn't in sync with the prevailing open-source ethos that seeks community contributions, but it's the only way I can move at this velocity and keep my sanity.

---

## License

MIT

---

*Created: January 2026*

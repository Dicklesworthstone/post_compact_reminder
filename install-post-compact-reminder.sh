#!/usr/bin/env bash
#
# install-post-compact-reminder.sh
# Installs Claude Code hook to remind about AGENTS.md after context compaction
#
# Usage:
#   ./install-post-compact-reminder.sh
#   curl -fsSL <url> | bash
#
# Options (see --help for full list):
#   --help, -h        Show help
#   --dry-run, -n     Preview changes without modifying anything
#   --uninstall       Remove the hook
#   --force           Reinstall even if already installed
#   --message         Use a custom reminder message
#   --message-file    Use a custom reminder message from a file
#   --status          Show installation status
#   --skip-deps       Do not auto-install missing dependencies
#
# Environment variables:
#   HOOK_DIR=/path    Override hook script location (default: ~/.local/bin)
#   SETTINGS_DIR=/p   Override settings location (default: ~/.claude)
#

set -euo pipefail

VERSION="1.2.4"
SCRIPT_NAME="claude-post-compact-reminder"
LOCK_FILE="${TMPDIR:-/tmp}/.post-compact-reminder-install-${USER:-$(id -u)}.lock"
GITHUB_RAW_URL="https://github.com/Dicklesworthstone/post_compact_reminder/raw/refs/heads/main/install-post-compact-reminder.sh"
GITHUB_RELEASES_URL="https://github.com/Dicklesworthstone/post_compact_reminder/releases"
GITHUB_API_URL="https://api.github.com/repos/Dicklesworthstone/post_compact_reminder/releases/latest"

# Changelog (newest first)
CHANGELOG_1_2_4="UI alignment polish (auto-sized boxes), new --update-reminder-message CLI, and safer non-interactive behavior (TTY guard + auto no-color/no-unicode). Show-template now renders the actual installed message."
CHANGELOG_1_2_3="Security hardening: Escaped special characters in generated hook script to prevent potential code injection from custom messages."
CHANGELOG_1_2_2="Fixed lock file permission issues in multi-user environments. Improved regex precision for Bash-based JSON parsing fallback. Added cleanup for temporary files on failure."
CHANGELOG_1_2_1="Added pure Bash fallback for JSON parsing in hook (removing runtime jq dependency). Added symlink resolution for settings.json to support dotfile managers."
CHANGELOG_1_2_0="Added --message/--message-file, --status --json, and --skip-deps. Hardened settings.json edits and made the hook fail-open if jq is missing or JSON is invalid. Safer self-update path resolution. Templates now ensure settings are configured."
CHANGELOG_1_1_0="Added --status, --verbose, --restore, --diff, --interactive, --yes, --completions, --template, --show-template, --update, --changelog, --log flags. Enhanced customization support."
CHANGELOG_1_0_0="Initial release with basic install/uninstall, dry-run, force reinstall, quiet mode, and no-color support."

# -----------------------------------------------------------------------------
# Cleanup and error handling
# -----------------------------------------------------------------------------
cleanup() {
    rm -f "$LOCK_FILE" 2>/dev/null || true
}
# Trap moved to main() to allow sourcing for tests

append_exit_trap() {
    local new_cmd="$1"
    local existing=""
    existing=$(trap -p EXIT | sed -E "s/^trap -- '(.*)' EXIT$/\\1/")
    if [[ -n "$existing" ]]; then
        # shellcheck disable=SC2064
        trap "${new_cmd}; ${existing}" EXIT
    else
        # shellcheck disable=SC2064
        trap "$new_cmd" EXIT
    fi
}

# Acquire lock to prevent concurrent runs
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "Another instance is running (PID: $pid). Exiting." >&2
            exit 1
        fi
        # Stale lock file, remove it
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
}

# -----------------------------------------------------------------------------
# Colors and Styles
# -----------------------------------------------------------------------------
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
MAGENTA=$'\033[0;35m'
WHITE=$'\033[1;37m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
UNDERLINE=$'\033[4m'
NC=$'\033[0m'

# Box drawing characters (rounded corners)
BOX_TL='╭' BOX_TR='╮' BOX_BL='╰' BOX_BR='╯'
BOX_H='─' BOX_V='│'

# Banner box drawing characters (double line)
BANNER_TL='╔' BANNER_TR='╗' BANNER_BL='╚' BANNER_BR='╝'
BANNER_H='═' BANNER_V='║'

# Icons and glyphs
ICON_INFO='ℹ️'
ICON_WARN='⚠️'
ICON_ERROR='❌'
ICON_STEP='🔧'
ICON_SUCCESS='✅'
ICON_SKIP='⏭️'
ICON_ZAP='⚡'

BULLET='•'
ARROW='→'
EM_DASH='—'

# -----------------------------------------------------------------------------
# Logging with Style
# -----------------------------------------------------------------------------
QUIET="false"
VERBOSE="false"
YES_FLAG="false"
SKIP_DEPS="false"
STATUS_JSON="false"
LOG_FILE=""
HAS_JQ="false"
HAS_PYTHON="false"
NO_UNICODE=""

log_to_file() {
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    fi
}

log_info()    { [[ "$QUIET" == "true" ]] || echo -e "${CYAN}${ICON_INFO}${NC}  $1"; log_to_file "INFO: $1"; }
log_warn()    { echo -e "${YELLOW}${ICON_WARN}${NC}  $1"; log_to_file "WARN: $1"; }  # Always show warnings
log_error()   { echo -e "${RED}${ICON_ERROR}${NC}  $1" >&2; log_to_file "ERROR: $1"; }  # Always show errors
log_step()    { [[ "$QUIET" == "true" ]] || echo -e "${BLUE}${ICON_STEP}${NC}  $1"; log_to_file "STEP: $1"; }
log_success() { [[ "$QUIET" == "true" ]] || echo -e "${GREEN}${ICON_SUCCESS}${NC}  $1"; log_to_file "SUCCESS: $1"; }
log_skip()    { [[ "$QUIET" == "true" ]] || echo -e "${DIM}${ICON_SKIP}${NC}  $1"; log_to_file "SKIP: $1"; }
log_verbose() { [[ "$VERBOSE" == "true" ]] && echo -e "${DIM}   $1${NC}"; log_to_file "VERBOSE: $1"; }

# -----------------------------------------------------------------------------
# Output mode helpers
# -----------------------------------------------------------------------------
set_box_single() {
    BOX_TL='┌' BOX_TR='┐' BOX_BL='└' BOX_BR='┘'
    BOX_H='─' BOX_V='│'
    BANNER_TL='┌' BANNER_TR='┐' BANNER_BL='└' BANNER_BR='┘'
    BANNER_H='─' BANNER_V='│'
}

set_box_ascii() {
    BOX_TL='+' BOX_TR='+' BOX_BL='+' BOX_BR='+'
    BOX_H='-' BOX_V='|'
    BANNER_TL='+' BANNER_TR='+' BANNER_BL='+' BANNER_BR='+'
    BANNER_H='-' BANNER_V='|'
}

apply_no_color() {
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' WHITE='' BOLD='' DIM='' ITALIC='' UNDERLINE='' NC=''
    if [[ "$NO_UNICODE" == "true" ]]; then
        set_box_ascii
    else
        set_box_single
    fi
}

apply_no_unicode() {
    NO_UNICODE="true"
    ICON_INFO='i'
    ICON_WARN='!'
    ICON_ERROR='x'
    ICON_STEP='>'
    ICON_SUCCESS='+'
    ICON_SKIP='.'
    ICON_ZAP='!'
    BULLET='*'
    ARROW='->'
    EM_DASH='-'
    set_box_ascii
}

auto_output_mode() {
    local no_color="false"
    local no_unicode="false"

    if [[ -n "${NO_COLOR:-}" ]]; then
        no_color="true"
    fi
    if [[ -n "${NO_UNICODE:-}" ]]; then
        no_unicode="true"
    fi
    if [[ ! -t 1 || "${TERM:-}" == "dumb" ]]; then
        no_color="true"
        no_unicode="true"
    fi

    if [[ "$no_unicode" == "true" ]]; then
        apply_no_unicode
    fi
    if [[ "$no_color" == "true" ]]; then
        apply_no_color
    fi
}

require_tty() {
    local hint="${1:-}"
    if [[ ! -t 0 ]]; then
        if [[ -n "$hint" ]]; then
            log_error "Interactive input requires a TTY. $hint"
        else
            log_error "Interactive input requires a TTY."
        fi
        return 1
    fi
    return 0
}

repeat_char() {
    local ch="$1"
    local count="$2"
    local out=""
    local i
    for ((i = 0; i < count; i++)); do
        out+="$ch"
    done
    printf '%s' "$out"
}

# Calculate display width (emojis are 2 columns, ASCII is 1)
display_width() {
    local str="$1"
    # Use wc -L for display width (works on GNU coreutils with UTF-8 locale)
    # Fall back to character count if wc -L returns 0 or fails
    local width
    width=$(printf '%s' "$str" | LC_ALL=en_US.UTF-8 wc -L 2>/dev/null | tr -d ' ')
    if [[ -z "$width" ]] || (( width == 0 && ${#str} > 0 )); then
        # Fallback: count characters plus extra for likely emojis (4-byte UTF-8)
        width=${#str}
    fi
    printf '%d' "$width"
}

# Pad string to display width (accounting for wide characters)
pad_to_width() {
    local str="$1"
    local target_width="$2"
    local current_width
    current_width=$(display_width "$str")
    local padding=$((target_width - current_width))
    if (( padding > 0 )); then
        printf '%s%*s' "$str" "$padding" ""
    else
        printf '%s' "$str"
    fi
}

split_lines() {
    local input="$1"
    while IFS= read -r line || [[ -n "$line" ]]; do
        printf '%s\n' "$line"
    done <<< "$input"
}

prompt_message() {
    require_tty "Use --update-reminder-message \"...\" or --update-reminder-message-file <file>." || return 1
    local message=""
    echo -e "${CYAN}${BOLD}Enter the new reminder message.${NC}"
    echo -e "${DIM}Finish with a single line containing .done (or press Ctrl-D).${NC}"
    local line
    while IFS= read -r line; do
        if [[ "$line" == ".done" ]]; then
            break
        fi
        message+="$line"$'\n'
    done
    message="${message%$'\n'}"
    printf '%s' "$message"
}

print_box() {
    local style="$1"
    local indent="$2"
    local border_color="$3"
    local text_color="$4"
    shift 4
    local min_width=0
    if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
        min_width="$1"
        shift
    fi
    local -a lines=("$@")

    local tl tr bl br h v
    if [[ "$style" == "banner" ]]; then
        tl="$BANNER_TL"
        tr="$BANNER_TR"
        bl="$BANNER_BL"
        br="$BANNER_BR"
        h="$BANNER_H"
        v="$BANNER_V"
    else
        tl="$BOX_TL"
        tr="$BOX_TR"
        bl="$BOX_BL"
        br="$BOX_BR"
        h="$BOX_H"
        v="$BOX_V"
    fi

    local max=0
    local line len
    for line in "${lines[@]}"; do
        len=$(display_width "$line")
        if (( len > max )); then
            max=$len
        fi
    done
    if (( min_width > max )); then
        max=$min_width
    fi

    local hline
    hline=$(repeat_char "$h" $((max + 2)))
    printf "%s%s%s%s\n" "$indent" "${border_color}${tl}" "$hline" "${tr}${NC}"
    local padded
    for line in "${lines[@]}"; do
        padded=$(pad_to_width "$line" "$max")
        printf "%s%s${text_color} %s ${NC}%s\n" \
            "$indent" "${border_color}${v}${NC}" "$padded" "${border_color}${v}${NC}"
    done
    printf "%s%s%s%s\n" "$indent" "${border_color}${bl}" "$hline" "${br}${NC}"
}

# -----------------------------------------------------------------------------
# Message Templates
# -----------------------------------------------------------------------------
TEMPLATE_MINIMAL="🚨 MANDATORY: Context compacted. Read AGENTS.md NOW. Confirm by stating what you learned."

TEMPLATE_DETAILED="🚨 MANDATORY: Context was just compacted. STOP. BEFORE doing anything else, you MUST:
1. Read AGENTS.md completely
2. Check the current task list
3. Review recent git commits (git log --oneline -5)
4. Verify any uncommitted changes (git status)

After completing these steps, confirm by briefly stating what key rules you found in AGENTS.md.
DO NOT proceed with any other work until you have confirmed."

TEMPLATE_CHECKLIST="🚨 MANDATORY: Context compacted. STOP. Complete ALL items before continuing:
- [ ] Read AGENTS.md completely
- [ ] Check task list (/tasks)
- [ ] Review recent commits
- [ ] Run test suite
- [ ] Check git status

After completing, confirm by stating: \"I have completed the checklist. Key AGENTS.md rules: [list them]\"
DO NOT proceed until you have confirmed."

TEMPLATE_DEFAULT="
🚨 IMPORTANT: Context was just compacted. STOP. You MUST:
1. Read AGENTS.md NOW
2. Confirm by briefly stating what key rules/conventions you found

Do not proceed with any task until you have read the file and confirmed what you learned.
"

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------
print_banner() {
    [[ "$QUIET" == "true" ]] && return
    local -a lines=(
        ""
        "🧠  post-compact-reminder v${VERSION}"
        ""
        "\"We stop your bot from going on a post-compaction rampage.\""
        ""
    )
    echo ""
    print_box "banner" "" "${CYAN}${BOLD}" "${WHITE}${BOLD}" 62 "${lines[@]}"
    echo ""
}

# -----------------------------------------------------------------------------
# Help
# -----------------------------------------------------------------------------
show_help() {
    print_banner
    echo -e "${CYAN}${BOLD}${UNDERLINE}SYNOPSIS${NC}"
    echo -e "  ${WHITE}install-post-compact-reminder.sh${NC} ${DIM}[OPTIONS]${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}${UNDERLINE}DESCRIPTION${NC}"
    echo -e "  Installs a ${GREEN}SessionStart${NC} hook that fires after context compaction"
    echo -e "  and reminds Claude to re-read ${YELLOW}AGENTS.md${NC} for project conventions."
    echo ""
    echo -e "${CYAN}${BOLD}${UNDERLINE}INSTALLATION OPTIONS${NC}"
    echo -e "  ${GREEN}--help${NC}, ${GREEN}-h${NC}            Show this help message"
    echo -e "  ${GREEN}--version${NC}, ${GREEN}-v${NC}         Show version number"
    echo -e "  ${GREEN}--dry-run${NC}, ${GREEN}-n${NC}         Preview changes without modifying anything"
    echo -e "  ${GREEN}--uninstall${NC}, ${GREEN}--remove${NC}  Remove the hook and settings entry"
    echo -e "  ${GREEN}--repair${NC}, ${GREEN}--sync${NC}       Repair installation and sync settings"
    echo -e "  ${GREEN}--force${NC}, ${GREEN}-f${NC}           Reinstall even if already at latest version"
    echo -e "  ${GREEN}--yes${NC}, ${GREEN}-y${NC}             Skip confirmation prompts"
    echo -e "  ${GREEN}--skip-deps${NC}          Do not auto-install missing dependencies"
    echo ""
    echo -e "${CYAN}${BOLD}${UNDERLINE}CUSTOMIZATION OPTIONS${NC}"
    echo -e "  ${GREEN}--interactive${NC}, ${GREEN}-i${NC}     Interactive setup with template selection"
    echo -e "  ${GREEN}--template${NC} ${MAGENTA}<name>${NC}    Apply preset template (minimal|detailed|checklist|default)"
    echo -e "  ${GREEN}--message${NC} ${MAGENTA}<text>${NC}     Use a custom reminder message (single-line)"
    echo -e "  ${GREEN}--message-file${NC} ${MAGENTA}<file>${NC} Use a custom reminder message from a file"
    echo -e "  ${GREEN}--update-reminder-message${NC} ${MAGENTA}[text]${NC} Update message (prompt if no text)"
    echo -e "  ${GREEN}--update-reminder-message-file${NC} ${MAGENTA}<file>${NC} Update message from a file"
    echo -e "  ${GREEN}--show-template${NC}       Show currently installed reminder message"
    echo ""
    echo -e "${CYAN}${BOLD}${UNDERLINE}DIAGNOSTIC OPTIONS${NC}"
    echo -e "  ${GREEN}--status${NC}, ${GREEN}--check${NC}     Show installation health and configuration"
    echo -e "  ${GREEN}--doctor${NC}, ${GREEN}--self-test${NC} Run hook self-tests"
    echo -e "  ${GREEN}--json${NC}                Output status/doctor as JSON"
    echo -e "  ${GREEN}--diff${NC}                Show changes between installed and new version"
    echo -e "  ${GREEN}--verbose${NC}, ${GREEN}-V${NC}        Enable verbose/debug output"
    echo -e "  ${GREEN}--log${NC} ${MAGENTA}<file>${NC}         Log all operations to specified file"
    echo ""
    echo -e "${CYAN}${BOLD}${UNDERLINE}MAINTENANCE OPTIONS${NC}"
    echo -e "  ${GREEN}--restore${NC}             Restore settings.json from backup"
    echo -e "  ${GREEN}--update${NC}              Self-update installer from GitHub"
    echo -e "  ${GREEN}--changelog${NC}           Show version history"
    echo -e "  ${GREEN}--completions${NC} ${MAGENTA}<shell>${NC} Generate shell completions (bash|zsh)"
    echo ""
    echo -e "${CYAN}${BOLD}${UNDERLINE}OUTPUT OPTIONS${NC}"
    echo -e "  ${GREEN}--quiet${NC}, ${GREEN}-q${NC}           Suppress non-essential output"
    echo -e "  ${GREEN}--no-color${NC}            Disable colored output"
    echo -e "  ${GREEN}--no-unicode${NC}, ${GREEN}--plain${NC}  Use ASCII-only output"
    echo ""
    echo -e "${CYAN}${BOLD}${UNDERLINE}ENVIRONMENT VARIABLES${NC}"
    echo -e "  ${MAGENTA}HOOK_DIR${NC}              Override hook script location ${DIM}(default: ~/.local/bin)${NC}"
    echo -e "  ${MAGENTA}SETTINGS_DIR${NC}          Override settings location ${DIM}(default: ~/.claude)${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}${UNDERLINE}EXAMPLES${NC}"
    echo -e "  ${DIM}${ITALIC}# One-liner install${NC}"
    echo -e "  ${WHITE}curl -fsSL <url> | bash${NC}"
    echo ""
    echo -e "  ${DIM}${ITALIC}# Check installation status${NC}"
    echo -e "  ${WHITE}./install-post-compact-reminder.sh --status${NC}"
    echo ""
    echo -e "  ${DIM}${ITALIC}# Interactive setup with custom message${NC}"
    echo -e "  ${WHITE}./install-post-compact-reminder.sh --interactive${NC}"
    echo ""
    echo -e "  ${DIM}${ITALIC}# Apply minimal template${NC}"
    echo -e "  ${WHITE}./install-post-compact-reminder.sh --template minimal${NC}"
    echo ""
    echo -e "  ${DIM}${ITALIC}# Custom message from a file${NC}"
    echo -e "  ${WHITE}./install-post-compact-reminder.sh --message-file ./reminder.txt${NC}"
    echo ""
    echo -e "  ${DIM}${ITALIC}# Preview changes${NC}"
    echo -e "  ${WHITE}./install-post-compact-reminder.sh --dry-run${NC}"
    echo ""
    echo -e "  ${DIM}${ITALIC}# Uninstall${NC}"
    echo -e "  ${WHITE}./install-post-compact-reminder.sh --uninstall${NC}"
    echo ""
    echo -e "  ${DIM}${ITALIC}# Generate bash completions${NC}"
    echo -e "  ${WHITE}./install-post-compact-reminder.sh --completions bash >> ~/.bashrc${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Dependency checks and auto-installation
# -----------------------------------------------------------------------------
detect_dependencies() {
    command -v jq &> /dev/null && HAS_JQ="true" || HAS_JQ="false"
    command -v python3 &> /dev/null && HAS_PYTHON="true" || HAS_PYTHON="false"
}

detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v brew &> /dev/null; then
        echo "brew"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo ""
    fi
}

install_package() {
    local pkg="$1"
    local pkg_manager="$2"

    case "$pkg_manager" in
        apt)
            sudo apt-get update -qq && sudo apt-get install -y "$pkg"
            ;;
        brew)
            if [[ "$pkg" == "python3" ]]; then
                pkg="python"
            fi
            brew install "$pkg"
            ;;
        dnf)
            sudo dnf install -y "$pkg"
            ;;
        yum)
            sudo yum install -y "$pkg"
            ;;
        pacman)
            sudo pacman -S --noconfirm "$pkg"
            ;;
        *)
            return 1
            ;;
    esac
}

check_dependencies() {
    local allow_install="${1:-true}"
    local missing=()

    detect_dependencies

    if [[ "$HAS_JQ" != "true" ]]; then
        missing+=("jq")
    fi

    if [[ "$HAS_PYTHON" != "true" ]]; then
        missing+=("python3")
    fi

    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    fi

    log_warn "Missing dependencies: ${missing[*]}"

    if [[ "$allow_install" != "true" ]]; then
        log_warn "Dry run: skipping auto-install. Some checks may be skipped."
        return 0
    fi

    # Try to auto-install
    local pkg_manager
    pkg_manager=$(detect_package_manager)

    if [[ -z "$pkg_manager" ]]; then
        log_error "Could not detect package manager. Please install manually:"
        echo ""
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        return 1
    fi

    log_step "Attempting to install missing dependencies using $pkg_manager..."

    for dep in "${missing[@]}"; do
        log_step "Installing $dep..."
        if install_package "$dep" "$pkg_manager"; then
            log_success "Installed $dep"
        else
            log_error "Failed to install $dep"
            echo ""
            echo "Please install manually:"
            case "$pkg_manager" in
                apt)
                    echo "  sudo apt-get install $dep"
                    ;;
                brew)
                    echo "  brew install $dep"
                    ;;
                dnf|yum)
                    echo "  sudo $pkg_manager install $dep"
                    ;;
                pacman)
                    echo "  sudo pacman -S $dep"
                    ;;
            esac
            return 1
        fi
    done

    # Verify installation
    local still_missing=()
    detect_dependencies
    if [[ "$HAS_JQ" != "true" ]]; then
        still_missing+=("jq")
    fi
    if [[ "$HAS_PYTHON" != "true" ]]; then
        still_missing+=("python3")
    fi

    if [[ ${#still_missing[@]} -gt 0 ]]; then
        log_error "Dependencies still missing after install attempt: ${still_missing[*]}"
        return 1
    fi

    log_success "All dependencies installed"
    return 0
}

require_python_for_settings() {
    local dry_run="$1"
    if [[ "$dry_run" != "true" && "$HAS_PYTHON" != "true" ]]; then
        log_error "python3 not found; cannot update settings.json. Aborting before writing files."
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# Version management
# -----------------------------------------------------------------------------
get_installed_version() {
    local script_path="$1"
    if [[ -x "$script_path" ]]; then
        grep -m1 '^# Version:' "$script_path" 2>/dev/null | cut -d' ' -f3 || echo ""
    else
        echo ""
    fi
}

# -----------------------------------------------------------------------------
# Hook script content
# -----------------------------------------------------------------------------
render_hook_script() {
    local message="$1"
    local note="${2:-}"
    local note_line=""
    local message_quoted
    message_quoted=$(printf '%q' "$message")

    if [[ -n "$note" ]]; then
        # Sanitize note (remove newlines)
        note="${note//[$'\n\r']}"
        note_line="# $note"
    fi

    cat << HOOK_SCRIPT
#!/usr/bin/env bash
# Version: ${VERSION}
# SessionStart hook: Remind Claude to reread AGENTS.md after compaction
# Input: JSON with session_id, source on stdin
#
# This hook fires when source="compact" (configured via matcher in settings.json)
# and outputs a reminder that Claude sees in its context.
${note_line}

set -e

MESSAGE=${message_quoted}

# Read JSON input from Claude Code
INPUT=\$(cat)
SOURCE=""

# Parse source when jq is available; use bash regex fallback if missing
if command -v jq &> /dev/null; then
    SOURCE=\$(echo "\$INPUT" | jq -r '.source // empty' 2>/dev/null || true)
else
    # Fallback: regex matching for "source": "compact"
    # Matches "source" key preceded by { or , (and whitespace) to avoid false positives
    REGEX='(^|[{,])[[:space:]]*"source"[[:space:]]*:[[:space:]]*"compact"'
    if [[ "\$INPUT" =~ \$REGEX ]]; then
        SOURCE="compact"
    fi
fi

# Double-check source (belt and suspenders with the matcher)
if [[ "\$SOURCE" == "compact" ]]; then
    printf '%s\n' "\$MESSAGE"
fi

# SessionStart hooks don't block, just exit 0
exit 0
HOOK_SCRIPT
}

generate_hook_script() {
    render_hook_script "$TEMPLATE_DEFAULT"
}

# -----------------------------------------------------------------------------
# Settings management
# -----------------------------------------------------------------------------
check_settings_has_hook() {
    local settings_file="$1"
    if [[ ! -f "$settings_file" ]]; then
        return 1
    fi
    if [[ "$HAS_PYTHON" != "true" ]]; then
        return 1
    fi

    SETTINGS_FILE="$settings_file" python3 - << 'PY' 2>/dev/null
import json
import os
import sys

settings_file = os.environ.get("SETTINGS_FILE", "")
if not settings_file:
    sys.exit(1)

# Resolve symlinks to ensure we check the real file
if os.path.islink(settings_file):
    settings_file = os.path.realpath(settings_file)

try:
    with open(settings_file, "r") as f:
        settings = json.load(f)

    hooks = settings.get("hooks", {}).get("SessionStart", [])
    for hook_group in hooks:
        for hook in hook_group.get("hooks", []):
            if "post-compact-reminder" in hook.get("command", ""):
                sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PY
}

add_hook_to_settings() {
    local settings_file="$1"
    local hook_path="$2"
    local dry_run="$3"

    if [[ "$dry_run" == "true" ]]; then
        log_step "[dry-run] Would add SessionStart hook to $settings_file"
        return 0
    fi

    # Create backup before modifying
    if [[ -f "$settings_file" ]]; then
        cp "$settings_file" "${settings_file}.bak" 2>/dev/null || true
    fi

    SETTINGS_FILE="$settings_file" HOOK_PATH="$hook_path" python3 << 'MERGE_SCRIPT'
import json
import os
import sys
import tempfile
import shutil

settings_file = os.environ.get("SETTINGS_FILE", "")
hook_path = os.environ.get("HOOK_PATH", "")
if not settings_file or not hook_path:
    print("error: missing settings file or hook path", file=sys.stderr)
    sys.exit(1)

# Resolve symlinks to ensure we edit the real file and preserve the link
if os.path.islink(settings_file):
    settings_file = os.path.realpath(settings_file)

try:
    # Load or create settings
    if os.path.exists(settings_file):
        with open(settings_file, 'r') as f:
            settings = json.load(f)
    else:
        settings = {}

    original = json.dumps(settings, sort_keys=True)

    # Ensure hooks structure exists
    if 'hooks' not in settings:
        settings['hooks'] = {}

    session_start = settings['hooks'].get('SessionStart', [])
    new_session_start = []
    found_existing = False
    changed = False
    hook_inserted = False
    first_compact_idx = None

    for hook_group in session_start:
        hooks = hook_group.get('hooks', [])
        new_hooks = []
        group_is_compact = hook_group.get('matcher') == 'compact'

        for hook in hooks:
            cmd = hook.get('command', '')
            if 'post-compact-reminder' in cmd:
                found_existing = True
                if group_is_compact and not hook_inserted:
                    new_hook = dict(hook)
                    if new_hook.get('command') != hook_path:
                        new_hook['command'] = hook_path
                        changed = True
                    new_hooks.append(new_hook)
                    hook_inserted = True
                else:
                    changed = True
                    continue
            else:
                new_hooks.append(hook)

        if new_hooks:
            new_group = dict(hook_group)
            new_group['hooks'] = new_hooks
            new_session_start.append(new_group)
            if group_is_compact and first_compact_idx is None:
                first_compact_idx = len(new_session_start) - 1

    if not hook_inserted:
        if first_compact_idx is not None:
            new_session_start[first_compact_idx].setdefault('hooks', []).append({
                "type": "command",
                "command": hook_path
            })
        else:
            new_session_start.append({
                "matcher": "compact",
                "hooks": [
                    {
                        "type": "command",
                        "command": hook_path
                    }
                ]
            })
        changed = True

    settings['hooks']['SessionStart'] = new_session_start

    updated = json.dumps(settings, sort_keys=True)
    if not changed or original == updated:
        print('exists')
        sys.exit(0)

    # Atomic write: write to temp file then rename
    dir_name = os.path.dirname(settings_file) or '.'
    temp_path = None
    with tempfile.NamedTemporaryFile(mode='w', dir=dir_name, delete=False, suffix='.tmp') as tf:
        json.dump(settings, tf, indent=2)
        tf.write('\n')
        temp_path = tf.name

    shutil.move(temp_path, settings_file)
    print('updated' if found_existing else 'added')

except Exception as e:
    if 'temp_path' in locals() and temp_path and os.path.exists(temp_path):
        os.remove(temp_path)
    print(f'error: {e}', file=sys.stderr)
    sys.exit(1)
MERGE_SCRIPT
}

remove_hook_from_settings() {
    local settings_file="$1"
    local dry_run="$2"

    if [[ ! -f "$settings_file" ]]; then
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_step "[dry-run] Would remove SessionStart hook from $settings_file"
        return 0
    fi

    # Create backup before modifying
    cp "$settings_file" "${settings_file}.bak" 2>/dev/null || true

    SETTINGS_FILE="$settings_file" python3 << 'REMOVE_SCRIPT'
import json
import os
import sys
import tempfile
import shutil

settings_file = os.environ.get("SETTINGS_FILE", "")
if not settings_file:
    print("error: missing settings file", file=sys.stderr)
    sys.exit(1)

# Resolve symlinks to ensure we edit the real file and preserve the link
if os.path.islink(settings_file):
    settings_file = os.path.realpath(settings_file)

try:
    if not os.path.exists(settings_file):
        sys.exit(0)

    with open(settings_file, 'r') as f:
        settings = json.load(f)

    session_start = settings.get('hooks', {}).get('SessionStart', [])
    new_session_start = []

    for hook_group in session_start:
        new_hooks = []
        for hook in hook_group.get('hooks', []):
            if 'post-compact-reminder' not in hook.get('command', ''):
                new_hooks.append(hook)
        if new_hooks:
            # Create new dict to avoid mutating original
            new_group = dict(hook_group)
            new_group['hooks'] = new_hooks
            new_session_start.append(new_group)

    if new_session_start:
        settings['hooks']['SessionStart'] = new_session_start
    else:
        settings.get('hooks', {}).pop('SessionStart', None)

    # Clean up empty hooks
    if not settings.get('hooks'):
        settings.pop('hooks', None)

    # Atomic write: write to temp file then rename
    dir_name = os.path.dirname(settings_file) or '.'
    temp_path = None
    with tempfile.NamedTemporaryFile(mode='w', dir=dir_name, delete=False, suffix='.tmp') as tf:
        json.dump(settings, tf, indent=2)
        tf.write('\n')
        temp_path = tf.name

    shutil.move(temp_path, settings_file)

except Exception as e:
    if 'temp_path' in locals() and temp_path and os.path.exists(temp_path):
        os.remove(temp_path)
    print(f'error: {e}', file=sys.stderr)
    sys.exit(1)
REMOVE_SCRIPT
}

# -----------------------------------------------------------------------------
# Test hook
# -----------------------------------------------------------------------------
test_hook() {
    local script_path="$1"

    local test_result
    test_result=$(echo '{"session_id": "test", "source": "compact"}' | \
        "$script_path" 2>/dev/null || true)

    # Any non-empty output on compact input is considered valid
    if [[ -n "${test_result//[[:space:]]/}" ]]; then
        return 0
    fi
    return 1
}

# -----------------------------------------------------------------------------
# Extract rendered message from hook output
# -----------------------------------------------------------------------------
# Extract message lines from hook output
# Handles both new format (plain text) and legacy format (with XML tags)
extract_message_lines() {
    local output="$1"
    # Check if output has legacy XML tags
    if [[ "$output" == *"<post-compact-reminder>"* ]]; then
        local in_message="false"
        local line
        while IFS= read -r line; do
            if [[ "$line" == "<post-compact-reminder>" ]]; then
                in_message="true"
                continue
            fi
            if [[ "$line" == "</post-compact-reminder>" ]]; then
                break
            fi
            if [[ "$in_message" == "true" ]]; then
                printf '%s\n' "$line"
            fi
        done <<< "$output"
    else
        # New format: output is the message directly
        printf '%s' "$output"
    fi
}

get_rendered_message_lines() {
    local script_path="$1"
    if [[ ! -f "$script_path" ]]; then
        printf '%s\n' "$TEMPLATE_DEFAULT"
        return 1
    fi

    local -a cmd=("$script_path")
    if [[ ! -x "$script_path" ]]; then
        cmd=("bash" "$script_path")
    fi

    local output=""
    output=$(echo '{"session_id": "render", "source": "compact"}' | \
        "${cmd[@]}" 2>/dev/null || true)

    local -a lines=()
    mapfile -t lines < <(extract_message_lines "$output")
    if [[ ${#lines[@]} -eq 0 ]]; then
        printf '%s\n' "$TEMPLATE_DEFAULT"
        return 1
    fi
    printf '%s\n' "${lines[@]}"
    return 0
}

# -----------------------------------------------------------------------------
# JSON helpers
# -----------------------------------------------------------------------------
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# -----------------------------------------------------------------------------
# Status check
# -----------------------------------------------------------------------------
do_status() {
    local hook_dir="$1"
    local settings_dir="$2"

    local script_path="${hook_dir}/${SCRIPT_NAME}"
    local settings_file="${settings_dir}/settings.json"

    # Quick dependency check (just set flags, don't install)
    detect_dependencies

    if [[ "$STATUS_JSON" == "true" ]]; then
        local script_exists="false"
        local script_executable="false"
        local installed_version=""
        local update_available="false"
        local settings_exists="false"
        local hook_configured_json="null"
        local backup_exists="false"
        local hook_test_ran="false"
        local hook_test_passed_json="null"

        if [[ -f "$script_path" ]]; then
            script_exists="true"
            installed_version=$(get_installed_version "$script_path")
            if [[ -x "$script_path" ]]; then
                script_executable="true"
            fi
        fi

        if [[ -n "$installed_version" && "$installed_version" != "$VERSION" ]]; then
            update_available="true"
        fi

        if [[ -f "$settings_file" ]]; then
            settings_exists="true"
            if [[ "$HAS_PYTHON" == "true" ]]; then
                if check_settings_has_hook "$settings_file"; then
                    hook_configured_json="true"
                else
                    hook_configured_json="false"
                fi
            fi
            if [[ -f "${settings_file}.bak" ]]; then
                backup_exists="true"
            fi
        fi

        if [[ -x "$script_path" ]]; then
            hook_test_ran="true"
            if test_hook "$script_path"; then
                hook_test_passed_json="true"
            else
                hook_test_passed_json="false"
            fi
        fi

        printf '{\n'
        printf '  "version": "%s",\n' "$(json_escape "$VERSION")"
        printf '  "paths": {"script": "%s", "settings": "%s"},\n' \
            "$(json_escape "$script_path")" "$(json_escape "$settings_file")"
        printf '  "hook_script": {"exists": %s, "executable": %s, "installed_version": "%s", "update_available": %s},\n' \
            "$script_exists" "$script_executable" "$(json_escape "${installed_version:-}")" "$update_available"
        printf '  "settings": {"exists": %s, "hook_configured": %s, "backup_exists": %s},\n' \
            "$settings_exists" "$hook_configured_json" "$backup_exists"
        printf '  "dependencies": {"jq": %s, "python3": %s},\n' \
            "$HAS_JQ" "$HAS_PYTHON"
        printf '  "hook_test": {"ran": %s, "passed": %s}\n' \
            "$hook_test_ran" "$hook_test_passed_json"
        printf '}\n'
        return 0
    fi

    print_banner

    echo -e "  ${WHITE}${BOLD}${UNDERLINE}📊 Installation Status${NC}"
    echo ""

    # Check script
    echo -e "  ${CYAN}${BOLD}📜 Hook Script:${NC}"
    if [[ -f "$script_path" ]]; then
        local installed_version
        installed_version=$(get_installed_version "$script_path")
        if [[ -x "$script_path" ]]; then
            echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Installed at ${WHITE}$script_path${NC}"
            echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Executable: yes"
            echo -e "    ${CYAN}${ICON_INFO}${NC} Version: ${WHITE}${installed_version:-unknown}${NC}"
            if [[ "$installed_version" != "$VERSION" && -n "$installed_version" ]]; then
                echo -e "    ${YELLOW}${ICON_WARN}${NC} Update available: ${installed_version} ${ARROW} ${VERSION}"
            fi
        else
            echo -e "    ${YELLOW}${ICON_WARN}${NC} File exists but not executable"
        fi
    else
        echo -e "    ${RED}${ICON_ERROR}${NC} Not installed at $script_path"
    fi
    echo ""

    # Check settings
    echo -e "  ${CYAN}${BOLD}⚙️  Settings Configuration:${NC}"
    if [[ -f "$settings_file" ]]; then
        echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Settings file exists at ${WHITE}$settings_file${NC}"
        if [[ "$HAS_PYTHON" == "true" ]]; then
            if check_settings_has_hook "$settings_file"; then
                echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Hook configured in settings.json"
            else
                echo -e "    ${RED}${ICON_ERROR}${NC} Hook NOT configured in settings.json"
            fi
        else
            echo -e "    ${YELLOW}${ICON_WARN}${NC} Cannot verify hook config (python3 not available)"
        fi
        if [[ -f "${settings_file}.bak" ]]; then
            echo -e "    ${CYAN}${ICON_INFO}${NC} Backup exists: ${settings_file}.bak"
        fi
    else
        echo -e "    ${RED}${ICON_ERROR}${NC} Settings file not found"
    fi
    echo ""

    # Check dependencies
    echo -e "  ${CYAN}${BOLD}📦 Dependencies:${NC}"
    if [[ "$HAS_JQ" == "true" ]]; then
        echo -e "    ${GREEN}${ICON_SUCCESS}${NC} jq: $(jq --version 2>/dev/null || echo 'installed')"
    else
        echo -e "    ${RED}${ICON_ERROR}${NC} jq: not installed"
    fi
    if [[ "$HAS_PYTHON" == "true" ]]; then
        echo -e "    ${GREEN}${ICON_SUCCESS}${NC} python3: $(python3 --version 2>/dev/null || echo 'installed')"
    else
        echo -e "    ${RED}${ICON_ERROR}${NC} python3: not installed"
    fi
    echo ""

    # Test hook if installed
    if [[ -x "$script_path" ]]; then
        echo -e "  ${CYAN}${BOLD}🧪 Hook Test:${NC}"
        if test_hook "$script_path"; then
            echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Hook responds correctly to compact events"
        else
            echo -e "    ${RED}${ICON_ERROR}${NC} Hook test failed"
        fi
        echo ""
    fi
}

# -----------------------------------------------------------------------------
# Doctor (self-test)
# -----------------------------------------------------------------------------
do_doctor() {
    local hook_dir="$1"
    local settings_dir="$2"

    local script_path="${hook_dir}/${SCRIPT_NAME}"
    local settings_file="${settings_dir}/settings.json"

    detect_dependencies

    local script_exists="false"
    local script_executable="false"
    local settings_exists="false"
    local hook_configured_json="null"
    local compact_test_ran="false"
    local compact_test_passed_json="null"
    local startup_test_ran="false"
    local startup_test_passed_json="null"

    if [[ -f "$script_path" ]]; then
        script_exists="true"
        if [[ -x "$script_path" ]]; then
            script_executable="true"
        fi
    fi

    if [[ -f "$settings_file" ]]; then
        settings_exists="true"
        if [[ "$HAS_PYTHON" == "true" ]]; then
            if check_settings_has_hook "$settings_file"; then
                hook_configured_json="true"
            else
                hook_configured_json="false"
            fi
        fi
    fi

    if [[ -x "$script_path" ]]; then
        compact_test_ran="true"
        if test_hook "$script_path"; then
            compact_test_passed_json="true"
        else
            compact_test_passed_json="false"
        fi

        startup_test_ran="true"
        local startup_output
        startup_output=$(echo '{"session_id": "doctor", "source": "startup"}' | \
            "$script_path" 2>/dev/null || true)
        if [[ -z "$startup_output" ]]; then
            startup_test_passed_json="true"
        else
            startup_test_passed_json="false"
        fi
    fi

    if [[ "$STATUS_JSON" == "true" ]]; then
        printf '{\n'
        printf '  "paths": {"script": "%s", "settings": "%s"},\n' \
            "$(json_escape "$script_path")" "$(json_escape "$settings_file")"
        printf '  "hook_script": {"exists": %s, "executable": %s},\n' \
            "$script_exists" "$script_executable"
        printf '  "settings": {"exists": %s, "hook_configured": %s},\n' \
            "$settings_exists" "$hook_configured_json"
        printf '  "dependencies": {"jq": %s, "python3": %s},\n' \
            "$HAS_JQ" "$HAS_PYTHON"
        printf '  "tests": {"compact": {"ran": %s, "passed": %s}, "startup": {"ran": %s, "passed": %s}}\n' \
            "$compact_test_ran" "$compact_test_passed_json" "$startup_test_ran" "$startup_test_passed_json"
        printf '}\n'
    else
        print_banner

        echo -e "${WHITE}${BOLD}${UNDERLINE}Doctor Results${NC}"
        echo ""

        echo -e "  ${CYAN}${BOLD}📜 Hook Script:${NC}"
        if [[ "$script_exists" == "true" ]]; then
            if [[ "$script_executable" == "true" ]]; then
                echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Installed and executable: ${WHITE}$script_path${NC}"
            else
                echo -e "    ${YELLOW}${ICON_WARN}${NC} Installed but not executable: ${WHITE}$script_path${NC}"
            fi
        else
            echo -e "    ${RED}${ICON_ERROR}${NC} Missing: ${WHITE}$script_path${NC}"
        fi
        echo ""

        echo -e "  ${CYAN}${BOLD}Settings:${NC}"
        if [[ "$settings_exists" == "true" ]]; then
            echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Settings file exists: ${WHITE}$settings_file${NC}"
            if [[ "$HAS_PYTHON" == "true" ]]; then
                if [[ "$hook_configured_json" == "true" ]]; then
                    echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Hook configured in settings.json"
                else
                    echo -e "    ${RED}${ICON_ERROR}${NC} Hook NOT configured in settings.json"
                fi
            else
                echo -e "    ${YELLOW}${ICON_WARN}${NC} Cannot verify hook config (python3 not available)"
            fi
        else
            echo -e "    ${RED}${ICON_ERROR}${NC} Settings file not found"
        fi
        echo ""

        echo -e "  ${CYAN}${BOLD}Tests:${NC}"
        if [[ "$compact_test_ran" == "true" ]]; then
            if [[ "$compact_test_passed_json" == "true" ]]; then
                echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Compact event triggers reminder"
            else
                echo -e "    ${RED}${ICON_ERROR}${NC} Compact event test failed"
            fi
        else
            echo -e "    ${YELLOW}${ICON_WARN}${NC} Compact event test skipped (hook not executable)"
        fi

        if [[ "$startup_test_ran" == "true" ]]; then
            if [[ "$startup_test_passed_json" == "true" ]]; then
                echo -e "    ${GREEN}${ICON_SUCCESS}${NC} Startup event produces no output"
            else
                echo -e "    ${RED}${ICON_ERROR}${NC} Startup event produced unexpected output"
            fi
        else
            echo -e "    ${YELLOW}${ICON_WARN}${NC} Startup event test skipped (hook not executable)"
        fi
        echo ""
    fi

    local ok="true"
    if [[ "$script_exists" != "true" || "$script_executable" != "true" ]]; then
        ok="false"
    fi
    if [[ "$settings_exists" != "true" ]]; then
        ok="false"
    fi
    if [[ "$hook_configured_json" == "false" ]]; then
        ok="false"
    fi
    if [[ "$compact_test_passed_json" == "false" || "$startup_test_passed_json" == "false" ]]; then
        ok="false"
    fi

    if [[ "$ok" == "true" ]]; then
        return 0
    fi
    return 1
}

# -----------------------------------------------------------------------------
# Restore settings backup
# -----------------------------------------------------------------------------
do_restore() {
    local settings_dir="$1"
    local dry_run="$2"

    local settings_file="${settings_dir}/settings.json"
    local backup_file="${settings_file}.bak"

    # Note: banner already printed by main()

    if [[ ! -f "$backup_file" ]]; then
        log_error "No backup file found at $backup_file"
        echo ""
        echo -e "  ${DIM}Backups are created automatically when settings.json is modified.${NC}"
        return 1
    fi

    log_info "Found backup: $backup_file"

    # Show what's different
    if command -v diff &> /dev/null && [[ -f "$settings_file" ]]; then
        echo ""
        echo -e "${WHITE}${BOLD}Changes to restore:${NC}"
        echo ""
        diff --color=auto -u "$settings_file" "$backup_file" 2>/dev/null || true
        echo ""
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_step "[dry-run] Would restore $backup_file to $settings_file"
        return 0
    fi

    # Confirm unless --yes
    if [[ "$YES_FLAG" != "true" ]]; then
        require_tty "Use --yes to skip confirmation." || return 1
        echo -e "${YELLOW}Restore settings.json from backup?${NC} [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Restore cancelled"
            return 0
        fi
    fi

    cp "$backup_file" "$settings_file"
    log_success "Restored settings.json from backup"
    echo ""
    echo -e "${YELLOW}${ICON_ZAP} Restart Claude Code for changes to take effect.${NC}"
}

# -----------------------------------------------------------------------------
# Show diff between installed and new version
# -----------------------------------------------------------------------------
do_diff() {
    local hook_dir="$1"

    local script_path="${hook_dir}/${SCRIPT_NAME}"

    print_banner

    if [[ ! -f "$script_path" ]]; then
        log_error "Hook not installed at $script_path"
        echo -e "  ${DIM}Run without --diff to install first.${NC}"
        return 1
    fi

    local installed_version
    installed_version=$(get_installed_version "$script_path")

    echo -e "${WHITE}${BOLD}${UNDERLINE}Version Comparison${NC}"
    echo ""
    echo -e "  Installed: ${CYAN}${installed_version:-unknown}${NC}"
    echo -e "  Available: ${GREEN}${VERSION}${NC}"
    echo ""

    if [[ "$installed_version" == "$VERSION" ]]; then
        log_info "Already at latest version"
        return 0
    fi

    echo -e "${WHITE}${BOLD}Hook script diff:${NC}"
    echo ""

    # Generate new script to temp file for comparison
    local temp_new
    temp_new=$(mktemp)
    generate_hook_script > "$temp_new"

    if command -v diff &> /dev/null; then
        diff --color=auto -u "$script_path" "$temp_new" || true
    else
        echo -e "${DIM}(diff not available - showing new version)${NC}"
        cat "$temp_new"
    fi

    rm -f "$temp_new"
    echo ""
}

# -----------------------------------------------------------------------------
# Interactive customization mode
# -----------------------------------------------------------------------------
do_interactive() {
    local hook_dir="$1"
    local settings_dir="$2"
    local dry_run="$3"

    local script_path="${hook_dir}/${SCRIPT_NAME}"

    # Note: banner already printed by main()
    require_tty "Use --template, --message, or --message-file for non-interactive usage." || return 1

    echo -e "${WHITE}${BOLD}${UNDERLINE}Interactive Setup${NC}"
    echo ""

    # Step 1: Choose template
    echo -e "${CYAN}${BOLD}Step 1:${NC} Choose a message template"
    echo ""
    echo -e "  ${GREEN}1)${NC} ${WHITE}minimal${NC}   - Short one-liner"
    echo -e "     ${DIM}\"$TEMPLATE_MINIMAL\"${NC}"
    echo ""
    echo -e "  ${GREEN}2)${NC} ${WHITE}detailed${NC}  - Step-by-step instructions"
    echo -e "     ${DIM}\"Context was just compacted. Please: 1. Re-read AGENTS.md...\"${NC}"
    echo ""
    echo -e "  ${GREEN}3)${NC} ${WHITE}checklist${NC} - Markdown checklist format"
    echo -e "     ${DIM}\"Context compacted. Before continuing: - [ ] Re-read AGENTS.md...\"${NC}"
    echo ""
    echo -e "  ${GREEN}4)${NC} ${WHITE}default${NC}   - Standard message"
    echo -e "     ${DIM}\"$TEMPLATE_DEFAULT\"${NC}"
    echo ""
    echo -e "  ${GREEN}5)${NC} ${WHITE}custom${NC}    - Enter your own message"
    echo ""

    echo -n "Choose template [1-5]: "
    read -r template_choice

    local chosen_message=""
    case "$template_choice" in
        1) chosen_message="$TEMPLATE_MINIMAL" ;;
        2) chosen_message="$TEMPLATE_DETAILED" ;;
        3) chosen_message="$TEMPLATE_CHECKLIST" ;;
        4) chosen_message="$TEMPLATE_DEFAULT" ;;
        5)
            echo ""
            echo -e "${CYAN}${BOLD}Step 2:${NC} Enter your custom message (end with empty line):"
            echo ""
            chosen_message=""
            while IFS= read -r line; do
                [[ -z "$line" ]] && break
                chosen_message+="$line"$'\n'
            done
            chosen_message="${chosen_message%$'\n'}"  # Remove trailing newline
            ;;
        *)
            log_warn "Invalid choice, using default"
            chosen_message="$TEMPLATE_DEFAULT"
            ;;
    esac

    echo ""
    echo -e "${WHITE}${BOLD}Preview:${NC}"
    echo ""
    local -a message_lines
    mapfile -t message_lines < <(split_lines "$chosen_message")
    print_box "box" "  " "${MAGENTA}" "" 57 "${message_lines[@]}"
    echo ""

    echo -n "Install with this message? [Y/n]: "
    read -r confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        log_info "Installation cancelled"
        return 0
    fi

    if ! require_python_for_settings "$dry_run"; then
        return 1
    fi

    # Dry run check
    if [[ "$dry_run" == "true" ]]; then
        echo ""
        log_step "[dry-run] Would create $script_path with custom message"
        log_step "[dry-run] Would update settings.json"
        echo ""
        log_info "[dry-run] No changes made"
        return 0
    fi

    # Generate custom hook script
    echo ""
    log_step "Creating directories..."
    mkdir -p "$hook_dir"
    mkdir -p "$settings_dir"

    log_step "Creating hook script with custom message..."

    render_hook_script "$chosen_message" "Generated by interactive setup" > "$script_path"

    chmod +x "$script_path"
    log_success "Created $script_path"

    # Update settings
    if [[ "$HAS_PYTHON" != "true" ]]; then
        log_error "python3 not found; cannot update settings.json"
        return 1
    fi
    log_step "Updating settings.json..."
    local settings_file="${settings_dir}/settings.json"
    local hook_path_for_settings
    local default_hook_dir="$HOME/.local/bin"
    if [[ "$hook_dir" == "$default_hook_dir" ]]; then
        # Use $HOME for portability when using default location
        hook_path_for_settings="\$HOME/.local/bin/${SCRIPT_NAME}"
    else
        # Use absolute path for custom HOOK_DIR
        hook_path_for_settings="$script_path"
    fi
    add_hook_to_settings "$settings_file" "$hook_path_for_settings" "false" > /dev/null
    log_success "Settings updated"

    # Test
    log_step "Testing hook..."
    if test_hook "$script_path"; then
        log_success "Hook test passed"
    else
        log_warn "Hook test inconclusive"
    fi

    echo ""
    log_success "Interactive setup complete!"
    echo ""
    echo -e "${YELLOW}${ICON_ZAP} Restart Claude Code for the hook to take effect.${NC}"
}

# -----------------------------------------------------------------------------
# Show current installed template
# -----------------------------------------------------------------------------
do_show_template() {
    local hook_dir="$1"

    local script_path="${hook_dir}/${SCRIPT_NAME}"

    if [[ ! -f "$script_path" ]]; then
        log_error "Hook not installed at $script_path"
        return 1
    fi

    print_banner

    echo -e "${WHITE}${BOLD}${UNDERLINE}Currently Installed Message${NC}"
    echo ""

    local -a message_lines
    mapfile -t message_lines < <(get_rendered_message_lines "$script_path")
    print_box "box" "  " "${MAGENTA}" "" 57 "${message_lines[@]}"

    echo ""
    echo -e "${DIM}File: $script_path${NC}"
}

# -----------------------------------------------------------------------------
# Apply a preset template
# -----------------------------------------------------------------------------
do_template() {
    local template_name="$1"
    local hook_dir="$2"
    local settings_dir="$3"
    local dry_run="$4"

    local script_path="${hook_dir}/${SCRIPT_NAME}"

    # Note: banner already printed by main()

    local chosen_message=""
    case "$template_name" in
        minimal)   chosen_message="$TEMPLATE_MINIMAL" ;;
        detailed)  chosen_message="$TEMPLATE_DETAILED" ;;
        checklist) chosen_message="$TEMPLATE_CHECKLIST" ;;
        default)   chosen_message="$TEMPLATE_DEFAULT" ;;
        *)
            log_error "Unknown template: $template_name"
            echo ""
            echo -e "Available templates: ${GREEN}minimal${NC}, ${GREEN}detailed${NC}, ${GREEN}checklist${NC}, ${GREEN}default${NC}"
            return 1
            ;;
    esac

    log_info "Applying template: $template_name"
    echo ""

    if ! require_python_for_settings "$dry_run"; then
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_step "[dry-run] Would create $script_path with '$template_name' template"
        echo ""
        echo -e "${WHITE}${BOLD}Preview:${NC}"
        echo ""
        echo "$chosen_message" | while IFS= read -r line; do
            echo "  $line"
        done
        return 0
    fi

    mkdir -p "$hook_dir"

    render_hook_script "$chosen_message" "Template: ${template_name}" > "$script_path"

    chmod +x "$script_path"
    log_success "Applied '$template_name' template to $script_path"

    # Test
    if test_hook "$script_path"; then
        log_success "Hook test passed"
    fi

    # Ensure settings.json is configured
    log_step "Updating settings.json..."
    local settings_file="${settings_dir}/settings.json"
    local hook_path_for_settings
    local default_hook_dir="$HOME/.local/bin"
    if [[ "$hook_dir" == "$default_hook_dir" ]]; then
        # Use $HOME for portability when using default location
        hook_path_for_settings="\$HOME/.local/bin/${SCRIPT_NAME}"
    else
        # Use absolute path for custom HOOK_DIR
        hook_path_for_settings="$script_path"
    fi
    add_hook_to_settings "$settings_file" "$hook_path_for_settings" "false" > /dev/null
    log_success "Settings updated"

    echo ""
    echo -e "${YELLOW}${ICON_ZAP} Restart Claude Code for changes to take effect.${NC}"
}

# -----------------------------------------------------------------------------
# Apply a custom message
# -----------------------------------------------------------------------------
do_message() {
    local message_arg="$1"
    local message_type="$2"
    local hook_dir="$3"
    local settings_dir="$4"
    local dry_run="$5"

    local script_path="${hook_dir}/${SCRIPT_NAME}"
    local chosen_message=""

    case "$message_type" in
        inline)
            chosen_message="$message_arg"
            ;;
        file)
            if [[ ! -f "$message_arg" ]]; then
                log_error "Message file not found: $message_arg"
                return 1
            fi
            chosen_message="$(cat "$message_arg")"
            ;;
        *)
            log_error "Unknown message type: $message_type"
            return 1
            ;;
    esac

    # Trim a single trailing newline for cleaner formatting
    chosen_message="${chosen_message%$'\n'}"

    if [[ -z "$chosen_message" ]]; then
        log_error "Message is empty"
        return 1
    fi

    log_info "Applying custom message"
    echo ""

    if ! require_python_for_settings "$dry_run"; then
        return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_step "[dry-run] Would create $script_path with custom message"
        echo ""
        echo -e "${WHITE}${BOLD}Preview:${NC}"
        echo ""
        echo "$chosen_message" | while IFS= read -r line; do
            echo "  $line"
        done
        return 0
    fi

    mkdir -p "$hook_dir"
    mkdir -p "$settings_dir"

    render_hook_script "$chosen_message" "Custom message" > "$script_path"
    chmod +x "$script_path"
    log_success "Created $script_path"

    log_step "Updating settings.json..."
    local settings_file="${settings_dir}/settings.json"
    local hook_path_for_settings
    local default_hook_dir="$HOME/.local/bin"
    if [[ "$hook_dir" == "$default_hook_dir" ]]; then
        hook_path_for_settings="\$HOME/.local/bin/${SCRIPT_NAME}"
    else
        hook_path_for_settings="$script_path"
    fi
    add_hook_to_settings "$settings_file" "$hook_path_for_settings" "false" > /dev/null
    log_success "Settings updated"

    log_step "Testing hook..."
    if test_hook "$script_path"; then
        log_success "Hook test passed"
    else
        log_warn "Hook test inconclusive"
    fi

    echo ""
    echo -e "${YELLOW}${ICON_ZAP} Restart Claude Code for changes to take effect.${NC}"
}

# -----------------------------------------------------------------------------
# Update reminder message (convenience wrapper)
# -----------------------------------------------------------------------------
do_update_message() {
    local message_arg="$1"
    local message_type="$2"
    local hook_dir="$3"
    local settings_dir="$4"
    local dry_run="$5"

    case "$message_type" in
        inline|file)
            do_message "$message_arg" "$message_type" "$hook_dir" "$settings_dir" "$dry_run"
            return $?
            ;;
        prompt)
            local chosen_message=""
            if ! chosen_message=$(prompt_message); then
                return 1
            fi
            if [[ -z "$chosen_message" ]]; then
                log_error "Message is empty"
                return 1
            fi
            do_message "$chosen_message" "inline" "$hook_dir" "$settings_dir" "$dry_run"
            return $?
            ;;
        *)
            log_error "Unknown message type: $message_type"
            return 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Show changelog
# -----------------------------------------------------------------------------
do_changelog() {
    print_banner

    echo -e "${WHITE}${BOLD}${UNDERLINE}Changelog${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}v1.2.4${NC}"
    echo -e "  ${DIM}$CHANGELOG_1_2_4${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}v1.2.3${NC}"
    echo -e "  ${DIM}$CHANGELOG_1_2_3${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}v1.2.2${NC}"
    echo -e "  ${DIM}$CHANGELOG_1_2_2${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}v1.2.1${NC}"
    echo -e "  ${DIM}$CHANGELOG_1_2_1${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}v1.2.0${NC}"
    echo -e "  ${DIM}$CHANGELOG_1_2_0${NC}"
    echo ""
    echo -e "  ${GREEN}${BOLD}v1.1.0${NC}"
    echo -e "  ${DIM}$CHANGELOG_1_1_0${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}v1.0.0${NC}"
    echo -e "  ${DIM}$CHANGELOG_1_0_0${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# Self-update from GitHub Releases (with SHA256 checksum verification)
# -----------------------------------------------------------------------------
do_update() {
    local dry_run="$1"

    # Note: banner already printed by main()

    log_info "Checking for updates..."

    if ! command -v curl &> /dev/null; then
        log_error "curl is required for updates"
        return 1
    fi

    # Cache-busting query param to defeat CDN caching
    local cache_bust
    cache_bust="?t=$(date +%s)"

    # Try to get latest version from GitHub Releases API first
    local remote_version=""
    local use_releases="false"
    local release_info
    release_info=$(curl -fsSL "${GITHUB_API_URL}${cache_bust}" 2>/dev/null) || true

    if [[ -n "$release_info" ]]; then
        remote_version=$(echo "$release_info" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"v[^"]*"' | head -1 | cut -d'"' -f4 | sed 's/^v//')
        if [[ -n "$remote_version" ]]; then
            use_releases="true"
            log_verbose "Found release version via API: $remote_version"
        fi
    fi

    # Fallback: fetch from raw GitHub URL to check version
    local remote_script=""
    if [[ -z "$remote_version" ]]; then
        log_verbose "Releases API unavailable, falling back to raw URL"
        remote_script=$(curl -fsSL "${GITHUB_RAW_URL}${cache_bust}" 2>/dev/null) || {
            log_error "Failed to fetch from GitHub"
            return 1
        }
        remote_version=$(echo "$remote_script" | grep -m1 '^VERSION=' | cut -d'"' -f2)
    fi

    if [[ -z "$remote_version" ]]; then
        log_error "Could not determine remote version"
        return 1
    fi

    echo ""
    echo -e "  Current version: ${CYAN}${VERSION}${NC}"
    echo -e "  Remote version:  ${GREEN}${remote_version}${NC}"
    if [[ "$use_releases" == "true" ]]; then
        echo -e "  Source:          ${DIM}GitHub Releases (with checksum verification)${NC}"
    else
        echo -e "  Source:          ${DIM}GitHub Raw (no checksum verification)${NC}"
    fi
    echo ""

    if [[ "$VERSION" == "$remote_version" ]]; then
        log_success "Already at latest version"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        log_step "[dry-run] Would update to $remote_version"
        return 0
    fi

    # Confirm unless --yes
    if [[ "$YES_FLAG" != "true" ]]; then
        require_tty "Use --yes to auto-confirm updates." || return 1
        echo -n "Update to $remote_version? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Update cancelled"
            return 0
        fi
    fi

    # Get the path to this script (avoid overwriting the wrong file)
    local this_script=""
    local source_name="${BASH_SOURCE[0]:-}"
    local candidate=""

    if [[ -n "$source_name" ]]; then
        candidate="$source_name"
        if command -v realpath &> /dev/null; then
            candidate=$(realpath "$candidate" 2>/dev/null || true)
        elif command -v readlink &> /dev/null; then
            candidate=$(readlink -f "$candidate" 2>/dev/null || true)
        fi
        if [[ -n "$candidate" && -f "$candidate" ]]; then
            this_script="$candidate"
        fi
    fi

    if [[ -z "$this_script" ]]; then
        candidate=$(command -v install-post-compact-reminder.sh 2>/dev/null || true)
        if [[ -n "$candidate" && -f "$candidate" ]]; then
            this_script="$candidate"
        fi
    fi

    case "$this_script" in
        ""|/dev/fd/*|/proc/self/fd/*)
            log_error "Could not resolve installer path. Run from a file instead of stdin."
            return 1
            ;;
    esac

    if [[ ! -w "$this_script" ]]; then
        log_error "Installer path is not writable: $this_script"
        return 1
    fi

    # Download the new version
    local tmp_script
    tmp_script=$(mktemp "${TMPDIR:-/tmp}/post-compact-reminder-update.XXXXXX")
    local tmp_rm
    tmp_rm=$(printf "rm -f %q" "$tmp_script")
    append_exit_trap "$tmp_rm"

    if [[ "$use_releases" == "true" ]]; then
        # Download from GitHub Releases
        local release_url="${GITHUB_RELEASES_URL}/download/v${remote_version}/install-post-compact-reminder.sh"
        local checksum_url="${GITHUB_RELEASES_URL}/download/v${remote_version}/install-post-compact-reminder.sh.sha256"

        log_step "Downloading v${remote_version} from GitHub Releases..."
        curl -fsSL "${release_url}${cache_bust}" -o "$tmp_script" 2>/dev/null || {
            log_error "Failed to download release v${remote_version}"
            rm -f "$tmp_script"
            return 1
        }

        # Verify SHA256 checksum
        local expected_checksum
        expected_checksum=$(curl -fsSL "${checksum_url}${cache_bust}" 2>/dev/null) || true

        if [[ -n "$expected_checksum" ]]; then
            local actual_checksum=""
            if command -v sha256sum &> /dev/null; then
                actual_checksum=$(sha256sum "$tmp_script" | awk '{print $1}')
            elif command -v shasum &> /dev/null; then
                actual_checksum=$(shasum -a 256 "$tmp_script" | awk '{print $1}')
            fi

            if [[ -n "$actual_checksum" ]]; then
                if [[ "$expected_checksum" != "$actual_checksum" ]]; then
                    log_error "Checksum verification FAILED!"
                    echo -e "  Expected: ${GREEN}${expected_checksum}${NC}"
                    echo -e "  Actual:   ${RED}${actual_checksum}${NC}"
                    log_error "The downloaded file may be corrupted or tampered with."
                    rm -f "$tmp_script"
                    return 1
                fi
                log_success "SHA256 checksum verified"
            else
                log_warn "sha256sum/shasum not available; skipping checksum verification"
            fi
        else
            log_warn "Checksum file not found; skipping verification"
        fi
    else
        # Fallback: use the already-fetched script from raw URL
        echo "$remote_script" > "$tmp_script"
    fi

    # Validate bash syntax before replacing
    if ! bash -n "$tmp_script" 2>/dev/null; then
        log_error "Downloaded script has syntax errors! Aborting update."
        rm -f "$tmp_script"
        return 1
    fi
    log_verbose "Bash syntax validation passed"

    # Verify the downloaded script has a VERSION string
    local downloaded_version
    downloaded_version=$(grep -m1 '^VERSION=' "$tmp_script" | cut -d'"' -f2)
    if [[ -z "$downloaded_version" ]]; then
        log_error "Downloaded script is missing VERSION string! Aborting update."
        rm -f "$tmp_script"
        return 1
    fi

    # Create backup
    cp "$this_script" "${this_script}.bak"
    log_verbose "Backup created at ${this_script}.bak"

    # Atomic replacement: copy to temp in same dir, then mv (preserves inode on rename)
    local tmp_dest
    tmp_dest=$(mktemp "${this_script}.tmp.XXXXXX")
    cp "$tmp_script" "$tmp_dest"
    chmod +x "$tmp_dest"
    mv -f "$tmp_dest" "$this_script"
    rm -f "$tmp_script"

    log_success "Updated to version $remote_version"
    echo ""
    echo -e "${YELLOW}Run the installer again to update the hook script.${NC}"
}

# -----------------------------------------------------------------------------
# Generate shell completions
# -----------------------------------------------------------------------------
do_completions() {
    local shell_type="$1"

    case "$shell_type" in
        bash)
            cat << 'BASH_COMPLETIONS'
# Bash completions for install-post-compact-reminder.sh
# Add to ~/.bashrc or /etc/bash_completion.d/

_post_compact_reminder() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    opts="--help -h --version -v --dry-run -n --uninstall --remove --repair --sync --force -f --quiet -q --no-color --no-unicode --plain --status --check --doctor --self-test --json --verbose -V --restore --diff --interactive -i --yes -y --skip-deps --completions --template --message --message-file --update-reminder-message --update-reminder-message-file --update-message --update-message-file --show-template --update --changelog --log"

    case "$prev" in
        --template)
            COMPREPLY=( $(compgen -W "minimal detailed checklist default" -- "$cur") )
            return 0
            ;;
        --completions)
            COMPREPLY=( $(compgen -W "bash zsh" -- "$cur") )
            return 0
            ;;
        --message-file|--update-reminder-message-file|--update-message-file)
            COMPREPLY=( $(compgen -f -- "$cur") )
            return 0
            ;;
        --log)
            COMPREPLY=( $(compgen -f -- "$cur") )
            return 0
            ;;
    esac

    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}

complete -F _post_compact_reminder install-post-compact-reminder.sh
complete -F _post_compact_reminder ./install-post-compact-reminder.sh
BASH_COMPLETIONS
            ;;

        zsh)
            cat << 'ZSH_COMPLETIONS'
#compdef install-post-compact-reminder.sh

# Zsh completions for install-post-compact-reminder.sh
# Add to ~/.zshrc or place in your fpath

_install_post_compact_reminder() {
    local -a opts
    opts=(
        '--help[Show help message]::'
        '-h[Show help message]::'
        '--version[Show version number]::'
        '-v[Show version number]::'
        '--dry-run[Preview changes without modifying]::'
        '-n[Preview changes without modifying]::'
        '--uninstall[Remove the hook]::'
        '--remove[Remove the hook]::'
        '--repair[Repair installation and sync settings]::'
        '--sync[Repair installation and sync settings]::'
        '--force[Reinstall even if already installed]::'
        '-f[Reinstall even if already installed]::'
        '--quiet[Suppress non-essential output]::'
        '-q[Suppress non-essential output]::'
        '--no-color[Disable colored output]::'
        '--no-unicode[Use ASCII-only output]::'
        '--plain[Use ASCII-only output]::'
        '--status[Show installation status]::'
        '--check[Show installation status]::'
        '--doctor[Run hook self-tests]::'
        '--self-test[Run hook self-tests]::'
        '--json[Output status as JSON (use with --status or --doctor)]::'
        '--verbose[Enable verbose output]::'
        '-V[Enable verbose output]::'
        '--restore[Restore settings.json from backup]::'
        '--diff[Show changes on upgrade]::'
        '--interactive[Interactive setup mode]::'
        '-i[Interactive setup mode]::'
        '--yes[Skip confirmation prompts]::'
        '-y[Skip confirmation prompts]::'
        '--skip-deps[Do not auto-install missing dependencies]::'
        '--completions[Generate shell completions]:shell:(bash zsh)'
        '--template[Apply a preset template]:template:(minimal detailed checklist default)'
        '--message[Use a custom reminder message]:message:'
        '--message-file[Use a custom message from a file]:file:_files'
        '--update-reminder-message[Update reminder message (prompt if empty)]:message:'
        '--update-reminder-message-file[Update reminder message from a file]:file:_files'
        '--update-message[Update reminder message (prompt if empty)]:message:'
        '--update-message-file[Update reminder message from a file]:file:_files'
        '--show-template[Show current installed message]::'
        '--update[Self-update from GitHub]::'
        '--changelog[Show version history]::'
        '--log[Log operations to file]:file:_files'
    )

    _arguments -s $opts
}

_install_post_compact_reminder "$@"
ZSH_COMPLETIONS
            ;;

        *)
            log_error "Unknown shell: $shell_type"
            echo ""
            echo -e "Supported shells: ${GREEN}bash${NC}, ${GREEN}zsh${NC}"
            return 1
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Repair / sync installation
# -----------------------------------------------------------------------------
do_repair() {
    local hook_dir="$1"
    local settings_dir="$2"
    local dry_run="$3"

    local script_path="${hook_dir}/${SCRIPT_NAME}"
    local settings_file="${settings_dir}/settings.json"

    if ! require_python_for_settings "$dry_run"; then
        return 1
    fi

    log_info "Repairing installation..."
    echo ""

    if [[ "$dry_run" != "true" ]]; then
        mkdir -p "$hook_dir"
        mkdir -p "$settings_dir"
    fi

    if [[ -f "$script_path" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            log_step "[dry-run] Would ensure $script_path is executable"
        else
            if [[ ! -x "$script_path" ]]; then
                chmod +x "$script_path"
                log_success "Fixed executable bit on $script_path"
            else
                log_skip "Hook script already present and executable"
            fi
        fi
    else
        if [[ "$dry_run" == "true" ]]; then
            log_step "[dry-run] Would create $script_path"
        else
            log_step "Creating hook script..."
            generate_hook_script > "$script_path"
            chmod +x "$script_path"
            log_success "Created $script_path"
        fi
    fi

    log_step "Synchronizing settings.json..."
    local hook_path_for_settings
    local default_hook_dir="$HOME/.local/bin"
    if [[ "$hook_dir" == "$default_hook_dir" ]]; then
        hook_path_for_settings="\$HOME/.local/bin/${SCRIPT_NAME}"
    else
        hook_path_for_settings="$script_path"
    fi
    add_hook_to_settings "$settings_file" "$hook_path_for_settings" "$dry_run" > /dev/null

    if [[ "$dry_run" != "true" ]]; then
        log_success "Settings synchronized"
    fi

    if [[ "$dry_run" != "true" && -x "$script_path" ]]; then
        log_step "Testing hook..."
        if test_hook "$script_path"; then
            log_success "Hook test passed"
        else
            log_warn "Hook test inconclusive"
        fi
    fi

    echo ""
    echo -e "${YELLOW}${ICON_ZAP} Restart Claude Code for changes to take effect.${NC}"
}

# -----------------------------------------------------------------------------
# Install
# -----------------------------------------------------------------------------
do_install() {
    local hook_dir="$1"
    local settings_dir="$2"
    local dry_run="$3"
    local force="$4"

    local script_path="${hook_dir}/${SCRIPT_NAME}"
    local settings_file="${settings_dir}/settings.json"

    # Check existing installation
    local installed_version
    installed_version=$(get_installed_version "$script_path")

    if [[ -n "$installed_version" && "$force" != "true" ]]; then
        if [[ "$installed_version" == "$VERSION" ]]; then
            log_info "Already installed at version ${VERSION}"
            if [[ "$HAS_PYTHON" != "true" ]]; then
                log_warn "python3 not found; skipping settings.json inspection"
            else
                if check_settings_has_hook "$settings_file"; then
                    log_skip "Hook already configured in settings.json"
                    echo ""
                    log_success "Nothing to do. Use --force to reinstall."
                    return 0
                else
                    log_warn "Script exists but settings.json needs updating"
                fi
            fi
        else
            log_info "Upgrading: ${installed_version} ${ARROW} ${VERSION}"
        fi
    fi

    if ! require_python_for_settings "$dry_run"; then
        return 1
    fi

    # Create directories
    if [[ "$dry_run" != "true" ]]; then
        mkdir -p "$hook_dir"
        mkdir -p "$settings_dir"
    fi

    # Install hook script
    if [[ "$dry_run" == "true" ]]; then
        log_step "[dry-run] Would create $script_path"
    else
        log_step "Creating hook script..."
        generate_hook_script > "$script_path"
        chmod +x "$script_path"
        log_success "Created $script_path"
    fi

    # Update settings.json
    # Note: We use $HOME in settings.json for portability, but only if using default HOOK_DIR
    log_step "Updating settings.json..."
    local hook_path_for_settings
    local default_hook_dir="$HOME/.local/bin"
    if [[ "$hook_dir" == "$default_hook_dir" ]]; then
        # Use $HOME for portability when using default location
        hook_path_for_settings="\$HOME/.local/bin/${SCRIPT_NAME}"
    else
        # Use absolute path for custom HOOK_DIR
        hook_path_for_settings="$script_path"
    fi
    local result
    result=$(add_hook_to_settings "$settings_file" "$hook_path_for_settings" "$dry_run")

    if [[ "$dry_run" != "true" ]]; then
        if [[ "$result" == "added" ]]; then
            log_success "Added SessionStart hook with matcher: compact"
        elif [[ "$result" == "updated" ]]; then
            log_success "Updated SessionStart hook configuration"
        else
            log_skip "Hook already present in settings.json"
        fi
    fi

    # Test the hook
    if [[ "$dry_run" != "true" ]]; then
        log_step "Testing hook..."
        if test_hook "$script_path"; then
            log_success "Hook test passed"
        else
            log_error "Hook test failed"
            return 1
        fi
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------
do_uninstall() {
    local hook_dir="$1"
    local settings_dir="$2"
    local dry_run="$3"

    local script_path="${hook_dir}/${SCRIPT_NAME}"
    local settings_file="${settings_dir}/settings.json"

    log_info "Uninstalling post-compact-reminder..."
    echo ""

    # Confirmation prompt (skip if --yes or --dry-run)
    if [[ "$YES_FLAG" != "true" ]] && [[ "$dry_run" != "true" ]]; then
        require_tty "Use --yes to skip confirmation." || return 1
        echo -e "${YELLOW}This will remove:${NC}"
        [[ -f "$script_path" ]] && echo -e "  ${DIM}${BULLET}${NC} $script_path"
        [[ -f "$settings_file" ]] && echo -e "  ${DIM}${BULLET}${NC} Hook entry from $settings_file"
        echo ""
        echo -n -e "${BOLD}Are you sure you want to uninstall? [y/N]${NC} "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Uninstall cancelled."
            exit 0
        fi
        echo ""
    fi

    # Remove script
    if [[ -f "$script_path" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            log_step "[dry-run] Would remove $script_path"
        else
            rm -f "$script_path"
            log_success "Removed $script_path"
        fi
    else
        log_skip "Script not found at $script_path"
    fi

    # Remove from settings
    if [[ -f "$settings_file" ]]; then
        if [[ "$HAS_PYTHON" != "true" ]]; then
            log_warn "python3 not found; skipping settings.json update"
        else
            if check_settings_has_hook "$settings_file"; then
                remove_hook_from_settings "$settings_file" "$dry_run"
                if [[ "$dry_run" != "true" ]]; then
                    log_success "Removed hook from settings.json"
                fi
            else
                log_skip "Hook not found in settings.json"
            fi
        fi
    else
        log_skip "Settings file not found"
    fi

    echo ""
    if [[ "$dry_run" == "true" ]]; then
        log_info "[dry-run] No changes made"
    else
        log_success "Uninstall complete"
        echo ""
        echo -e "${YELLOW}${ICON_ZAP} Restart Claude Code for changes to take effect.${NC}"
    fi
}

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
print_summary() {
    local dry_run="$1"
    local hook_dir="$2"
    local script_path="${hook_dir}/${SCRIPT_NAME}"

    echo ""
    if [[ "$dry_run" == "true" ]]; then
        print_box "box" "" "${BLUE}${BOLD}" "${BLUE}${BOLD}" 62 " 📋  DRY RUN ${EM_DASH} No changes were made"
    else
        print_box "box" "" "${GREEN}${BOLD}" "${GREEN}${BOLD}" 62 " 🎉  Installation complete!"
    fi
    echo ""
    echo -e "  ${WHITE}${BOLD}${UNDERLINE}👁️  What Claude sees after compaction:${NC}"
    echo ""
    local -a message_lines
    if [[ "$dry_run" == "true" ]]; then
        mapfile -t message_lines < <(split_lines "$TEMPLATE_DEFAULT")
    else
        mapfile -t message_lines < <(get_rendered_message_lines "$script_path")
        if [[ ${#message_lines[@]} -eq 0 ]]; then
            mapfile -t message_lines < <(split_lines "$TEMPLATE_DEFAULT")
        fi
    fi
    print_box "box" "  " "${MAGENTA}" "" 57 "${message_lines[@]}"
    echo ""

    if [[ "$dry_run" != "true" ]]; then
        echo -e "  ${YELLOW}${ICON_ZAP} ${ITALIC}Restart Claude Code for the hook to take effect.${NC}"
        echo ""

        # Customization section
        echo -e "  ${WHITE}${BOLD}${UNDERLINE}🎨 Customizing the reminder:${NC}"
        echo ""
        echo -e "  The reminder message can be easily customized to fit your workflow."
        echo -e "  Use the CLI to update the message without editing files."
        echo ""
        echo -e "  ${CYAN}${BOLD}Step 1:${NC} Update the reminder message"
        echo ""
        echo -e "    ${WHITE}\$ ${GREEN}./install-post-compact-reminder.sh --update-reminder-message${NC}"
        echo -e "    ${DIM}${ITALIC}  Finish with a line containing .done (or Ctrl-D).${NC}"
        echo ""
        echo -e "  ${CYAN}${BOLD}Step 2:${NC} Or set it inline"
        echo ""
        echo -e "    ${WHITE}\$ ${GREEN}./install-post-compact-reminder.sh --update-reminder-message \"Context compacted. Re-read AGENTS.md.\"${NC}"
        echo ""
        echo -e "  ${CYAN}${BOLD}Step 3:${NC} Or load from a file"
        echo ""
        echo -e "    ${WHITE}\$ ${GREEN}./install-post-compact-reminder.sh --update-reminder-message-file ./reminder.txt${NC}"
        echo ""
        echo -e "  ${CYAN}${BOLD}Step 4:${NC} Test your changes"
        echo ""
        echo -e "    ${WHITE}\$ ${GREEN}echo '{\"source\":\"compact\"}' | ~/.local/bin/claude-post-compact-reminder${NC}"
        echo ""
        echo -e "  ${DIM}${ITALIC}Tip: Changes take effect immediately ${EM_DASH} no restart needed for the hook itself.${NC}"
        echo -e "  ${DIM}${ITALIC}     Claude Code only needs restarting after the initial installation.${NC}"
        echo ""
    fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    trap cleanup EXIT
    local dry_run="false"
    local uninstall="false"
    local force="false"
    local action=""  # Track which standalone action to perform
    local action_arg=""  # Argument for the action (if needed)
    local action_arg_type=""  # Argument type for the action (if needed)

    # Parse arguments (using while + shift for flags with values)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            # Help and version
            --help|-h)
                show_help
                exit 0
                ;;
            --version|-v)
                echo "post-compact-reminder v${VERSION}"
                exit 0
                ;;

            # Installation options
            --dry-run|-n)
                dry_run="true"
                shift
                ;;
            --uninstall|--remove)
                uninstall="true"
                shift
                ;;
            --repair|--sync)
                action="repair"
                shift
                ;;
            --force|-f)
                force="true"
                shift
                ;;
            --yes|-y)
                YES_FLAG="true"
                shift
                ;;
            --skip-deps)
                SKIP_DEPS="true"
                shift
                ;;

            # Customization options
            --interactive|-i)
                action="interactive"
                shift
                ;;
            --template)
                if [[ -z "${2:-}" ]] || [[ "$2" == -* ]]; then
                    log_error "--template requires a value (minimal, detailed, checklist, default)"
                    exit 1
                fi
                action="template"
                action_arg="$2"
                shift 2
                ;;
            --message)
                if [[ -z "${2:-}" ]] || [[ "$2" == -* ]]; then
                    log_error "--message requires a value"
                    exit 1
                fi
                action="message"
                action_arg="$2"
                action_arg_type="inline"
                shift 2
                ;;
            --message-file)
                if [[ -z "${2:-}" ]] || [[ "$2" == -* ]]; then
                    log_error "--message-file requires a file path"
                    exit 1
                fi
                action="message"
                action_arg="$2"
                action_arg_type="file"
                shift 2
                ;;
            --update-reminder-message|--update-message)
                if [[ -n "${2:-}" && "$2" != -* ]]; then
                    action="update-message"
                    action_arg="$2"
                    action_arg_type="inline"
                    shift 2
                else
                    action="update-message"
                    action_arg_type="prompt"
                    shift
                fi
                ;;
            --update-reminder-message-file|--update-message-file)
                if [[ -z "${2:-}" ]] || [[ "$2" == -* ]]; then
                    log_error "--update-reminder-message-file requires a file path"
                    exit 1
                fi
                action="update-message"
                action_arg="$2"
                action_arg_type="file"
                shift 2
                ;;
            --show-template)
                action="show-template"
                shift
                ;;
            --completions)
                if [[ -z "${2:-}" ]] || [[ "$2" == -* ]]; then
                    log_error "--completions requires a shell name (bash, zsh)"
                    exit 1
                fi
                action="completions"
                action_arg="$2"
                shift 2
                ;;

            # Diagnostic options
            --status|--check)
                action="status"
                shift
                ;;
            --doctor|--self-test)
                action="doctor"
                shift
                ;;
            --json)
                STATUS_JSON="true"
                shift
                ;;
            --diff)
                action="diff"
                shift
                ;;
            --changelog)
                action="changelog"
                shift
                ;;

            # Maintenance options
            --update)
                action="update"
                shift
                ;;
            --restore)
                action="restore"
                shift
                ;;

            # Output options
            --quiet|-q)
                QUIET="true"
                shift
                ;;
            --verbose|-V)
                VERBOSE="true"
                shift
                ;;
            --no-color)
                apply_no_color
                shift
                ;;
            --no-unicode|--plain)
                apply_no_unicode
                shift
                ;;
            --log)
                if [[ -z "${2:-}" ]] || [[ "$2" == -* ]]; then
                    log_error "--log requires a file path"
                    exit 1
                fi
                LOG_FILE="$2"
                shift 2
                ;;

            # Unknown options
            -*)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done

    if [[ "$STATUS_JSON" == "true" && "$action" != "status" && "$action" != "doctor" ]]; then
        log_error "--json is only valid with --status or --doctor"
        exit 1
    fi

    # Initialize log file if specified
    if [[ -n "$LOG_FILE" ]]; then
        log_to_file "=== Session started: $(date) ==="
        log_to_file "Version: $VERSION"
        log_verbose "Logging to: $LOG_FILE"
    fi

    # Auto-adjust output when running non-interactively
    auto_output_mode

    # Configuration
    local hook_dir="${HOOK_DIR:-$HOME/.local/bin}"
    local settings_dir="${SETTINGS_DIR:-$HOME/.claude}"

    # Handle standalone actions (these don't need banner/dependencies/lock)
    case "$action" in
        status)
            do_status "$hook_dir" "$settings_dir"
            exit $?
            ;;
        doctor)
            do_doctor "$hook_dir" "$settings_dir"
            exit $?
            ;;
        changelog)
            do_changelog
            exit 0
            ;;
        completions)
            do_completions "$action_arg"
            exit $?
            ;;
        show-template)
            do_show_template "$hook_dir"
            exit $?
            ;;
        diff)
            do_diff "$hook_dir"
            exit $?
            ;;
    esac

    # Acquire lock for operations that modify files
    acquire_lock

    print_banner

    # Check dependencies
    local allow_install="true"
    if [[ "$dry_run" == "true" || "$SKIP_DEPS" == "true" ]]; then
        allow_install="false"
    fi
    if [[ "$uninstall" == "true" || "$action" == "update" ]]; then
        detect_dependencies
    else
        if ! check_dependencies "$allow_install"; then
            exit 1
        fi
    fi

    log_info "Hook directory: ${hook_dir}"
    log_info "Settings directory: ${settings_dir}"
    log_verbose "Dry run: $dry_run, Force: $force, Uninstall: $uninstall"
    echo ""

    # Handle actions that modify files
    case "$action" in
        interactive)
            do_interactive "$hook_dir" "$settings_dir" "$dry_run"
            exit $?
            ;;
        template)
            do_template "$action_arg" "$hook_dir" "$settings_dir" "$dry_run"
            exit $?
            ;;
        message)
            do_message "$action_arg" "$action_arg_type" "$hook_dir" "$settings_dir" "$dry_run"
            exit $?
            ;;
        update-message)
            do_update_message "$action_arg" "$action_arg_type" "$hook_dir" "$settings_dir" "$dry_run"
            exit $?
            ;;
        repair)
            do_repair "$hook_dir" "$settings_dir" "$dry_run"
            exit $?
            ;;
        update)
            do_update "$dry_run"
            exit $?
            ;;
        restore)
            do_restore "$settings_dir" "$dry_run"
            exit $?
            ;;
    esac

    # Default action: install or uninstall
    if [[ "$uninstall" == "true" ]]; then
        do_uninstall "$hook_dir" "$settings_dir" "$dry_run"
    else
        if do_install "$hook_dir" "$settings_dir" "$dry_run" "$force"; then
            print_summary "$dry_run" "$hook_dir"
        else
            exit 1
        fi
    fi
}

if [[ -z "${BASH_SOURCE[0]:-}" ]] || [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

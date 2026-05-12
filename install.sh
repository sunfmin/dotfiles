#!/usr/bin/env bash
# Install Claude Code settings, statusline scripts, and iTerm2 profile.
# Existing files are backed up to <file>.bak-<timestamp> before being overwritten.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }

backup_and_install() {
    local src="$1" dst="$2"
    local dst_dir
    dst_dir="$(dirname "$dst")"
    mkdir -p "$dst_dir"

    if [[ -e "$dst" || -L "$dst" ]]; then
        local bak="${dst}.bak-${TS}"
        mv "$dst" "$bak"
        warn "backed up existing $dst -> $bak"
    fi

    cp "$src" "$dst"
    ok "installed $dst"
}

# --- Claude ----------------------------------------------------------------

log "Installing Claude settings into ~/.claude/"
backup_and_install "$REPO_DIR/claude/settings.json"          "$HOME/.claude/settings.json"
backup_and_install "$REPO_DIR/claude/statusline.sh"          "$HOME/.claude/statusline.sh"
backup_and_install "$REPO_DIR/claude/statusline-command.sh"  "$HOME/.claude/statusline-command.sh"
chmod +x "$HOME/.claude/statusline.sh" "$HOME/.claude/statusline-command.sh"

# --- iTerm2 ----------------------------------------------------------------

ITERM_DYN_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
log "Installing iTerm2 Dynamic Profile into $ITERM_DYN_DIR"
backup_and_install "$REPO_DIR/iterm/Default.json" "$ITERM_DYN_DIR/Default.json"

cat <<'EOF'

Done.

iTerm2 will pick up the Dynamic Profile automatically (named "Synced").
To make it the default profile:
  iTerm2 → Settings → Profiles → select "Synced" → Other Actions → Set as Default.

If iTerm2 was already running, it reloads dynamic profiles on file change — no restart needed.
EOF

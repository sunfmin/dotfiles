#!/usr/bin/env bash
# Install Claude Code settings, statusline scripts, and iTerm2 profile.
# Existing files are backed up to <file>.bak-<timestamp> before being overwritten.
#
# Usage:
#   ./install.sh                       # from a local clone
#   curl -fsSL https://raw.githubusercontent.com/sunfmin/claude-settings/main/install.sh | bash
#                                      # self-bootstraps: clones the repo to /tmp and reruns

set -euo pipefail

REPO_URL="https://github.com/sunfmin/claude-settings.git"

# Resolve where this script lives. When piped from curl, BASH_SOURCE[0] is empty
# or unreliable, so we treat that as "not a local clone" and bootstrap.
SELF="${BASH_SOURCE[0]:-}"
if [[ -n "$SELF" && -f "$SELF" ]]; then
    REPO_DIR="$(cd "$(dirname "$SELF")" && pwd)"
else
    REPO_DIR=""
fi

if [[ -z "$REPO_DIR" || ! -f "$REPO_DIR/claude/settings.json" ]]; then
    TMP_DIR="/tmp/claude-settings-$(date +%Y%m%d-%H%M%S)"
    printf '\033[1;34m==>\033[0m Bootstrapping: cloning %s into %s\n' "$REPO_URL" "$TMP_DIR"
    git clone --depth=1 "$REPO_URL" "$TMP_DIR"
    exec bash "$TMP_DIR/install.sh"
fi

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

# Merge curated top-level iTerm prefs into ~/Library/Preferences/com.googlecode.iterm2.plist.
# Existing keys not in app-prefs.json are preserved; listed keys are overwritten.
ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
APP_PREFS="$REPO_DIR/iterm/app-prefs.json"
if [[ -f "$APP_PREFS" ]]; then
    log "Merging iTerm app-level preferences into $ITERM_PLIST"
    if [[ -f "$ITERM_PLIST" ]]; then
        cp "$ITERM_PLIST" "${ITERM_PLIST}.bak-${TS}"
        warn "backed up existing $ITERM_PLIST -> ${ITERM_PLIST}.bak-${TS}"
    fi
    python3 - "$APP_PREFS" "$ITERM_PLIST" <<'PYEOF'
import json, plistlib, sys, os
prefs_json, plist_path = sys.argv[1], sys.argv[2]
with open(prefs_json) as f:
    updates = json.load(f)
existing = {}
if os.path.exists(plist_path):
    with open(plist_path, 'rb') as f:
        existing = plistlib.load(f)
for k, v in updates.items():
    existing[k] = v
os.makedirs(os.path.dirname(plist_path), exist_ok=True)
with open(plist_path, 'wb') as f:
    plistlib.dump(existing, f, fmt=plistlib.FMT_BINARY)
print(f"  merged {len(updates)} keys")
PYEOF
    # Invalidate cfprefsd cache so iTerm sees the new values on next read.
    # Brief, harmless: cfprefsd respawns automatically.
    killall -u "$USER" cfprefsd 2>/dev/null || true
    ok "applied app-level preferences"
fi

cat <<'EOF'

Done.

iTerm2 will pick up the Dynamic Profile automatically (named "Synced").
To make it the default profile:
  iTerm2 → Settings → Profiles → select "Synced" → Other Actions → Set as Default.

App-level preferences (tab bar, pointer actions, etc.) were merged into the plist.
Already-open iTerm windows keep their old settings; new windows / a relaunch will
pick up the merged values.
EOF

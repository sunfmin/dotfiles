#!/usr/bin/env bash
# Install personal dotfiles: Claude Code, iTerm2, cmux, Ghostty.
# Existing files are backed up to <file>.bak-<timestamp> before being overwritten.
#
# Usage:
#   ./install.sh                       # from a local clone
#   curl -fsSL https://raw.githubusercontent.com/sunfmin/dotfiles/main/install.sh | bash
#                                      # self-bootstraps: clones the repo to /tmp and reruns

set -euo pipefail

REPO_URL="https://github.com/sunfmin/dotfiles.git"

# Resolve where this script lives. When piped from curl, BASH_SOURCE[0] is empty
# or unreliable, so we treat that as "not a local clone" and bootstrap.
SELF="${BASH_SOURCE[0]:-}"
if [[ -n "$SELF" && -f "$SELF" ]]; then
    REPO_DIR="$(cd "$(dirname "$SELF")" && pwd)"
else
    REPO_DIR=""
fi

if [[ -z "$REPO_DIR" || ! -f "$REPO_DIR/claude/settings.json" ]]; then
    TMP_DIR="/tmp/dotfiles-$(date +%Y%m%d-%H%M%S)"
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
backup_and_install "$REPO_DIR/claude/settings.json" "$HOME/.claude/settings.json"
backup_and_install "$REPO_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$HOME/.claude/statusline.sh"

# --- iTerm2 ----------------------------------------------------------------

ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
PROFILE_JSON="$REPO_DIR/iterm/Default.json"
APP_PREFS="$REPO_DIR/iterm/app-prefs.json"

# Remove any prior Dynamic Profile install — earlier versions of this script
# dropped Default.json into DynamicProfiles/, which collides with the in-plist
# profile that shares the same Guid. The non-dynamic profile in the plist is
# now the single source of truth on the machine.
ITERM_DYN_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
if [[ -f "$ITERM_DYN_DIR/Default.json" ]]; then
    mv "$ITERM_DYN_DIR/Default.json" "$ITERM_DYN_DIR/Default.json.bak-${TS}"
    warn "removed legacy Dynamic Profile $ITERM_DYN_DIR/Default.json (backed up)"
fi

if [[ -f "$ITERM_PLIST" ]]; then
    cp "$ITERM_PLIST" "${ITERM_PLIST}.bak-${TS}"
    warn "backed up existing $ITERM_PLIST -> ${ITERM_PLIST}.bak-${TS}"
fi

log "Merging Default profile into $ITERM_PLIST"
python3 - "$PROFILE_JSON" "$APP_PREFS" "$ITERM_PLIST" <<'PYEOF'
import json, plistlib, sys, os
profile_json, prefs_json, plist_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(profile_json) as f:
    repo_profile = json.load(f)["Profiles"][0]
target_guid = repo_profile["Guid"]

existing = {}
if os.path.exists(plist_path):
    with open(plist_path, 'rb') as f:
        existing = plistlib.load(f)

bookmarks = list(existing.get("New Bookmarks", []))
idx = next((i for i, b in enumerate(bookmarks) if b.get("Guid") == target_guid), None)
if idx is None:
    bookmarks.append(repo_profile)
    print(f"  appended profile {repo_profile.get('Name')!r} (Guid {target_guid})")
else:
    bookmarks[idx] = repo_profile
    print(f"  replaced profile at index {idx} ({repo_profile.get('Name')!r})")
existing["New Bookmarks"] = bookmarks
existing["Default Bookmark Guid"] = target_guid

if os.path.exists(prefs_json):
    with open(prefs_json) as f:
        updates = json.load(f)
    for k, v in updates.items():
        existing[k] = v
    print(f"  merged {len(updates)} app-level keys")

os.makedirs(os.path.dirname(plist_path), exist_ok=True)
with open(plist_path, 'wb') as f:
    plistlib.dump(existing, f, fmt=plistlib.FMT_BINARY)
PYEOF

# Invalidate cfprefsd cache so iTerm sees the new values on next read.
# Brief, harmless: cfprefsd respawns automatically.
killall -u "$USER" cfprefsd 2>/dev/null || true
ok "applied iTerm profile + app-level preferences"

# --- cmux ------------------------------------------------------------------

if [[ -f "$REPO_DIR/cmux/cmux.json" ]]; then
    log "Installing cmux config into ~/.config/cmux/"
    backup_and_install "$REPO_DIR/cmux/cmux.json" "$HOME/.config/cmux/cmux.json"
fi

# --- Ghostty ---------------------------------------------------------------

if [[ -f "$REPO_DIR/ghostty/config" ]]; then
    log "Installing Ghostty config into ~/.config/ghostty/"
    backup_and_install "$REPO_DIR/ghostty/config" "$HOME/.config/ghostty/config"
fi

cat <<'EOF'

Done.

The Default profile in iTerm has been updated in place.
Already-open iTerm windows keep their old settings; new windows / a relaunch
will pick up the merged values.

cmux + Ghostty pick up their configs on next launch (or new terminal tab).
EOF

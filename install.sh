#!/usr/bin/env bash
# Install personal dotfiles + the software they configure.
#
# Software: installed via Homebrew (Brewfile) — iTerm2, Ghostty, cmux, node, jq, git.
# Claude Code CLI: installed via npm (`@anthropic-ai/claude-code`).
#
# Config: file-based configs (claude, cmux, ghostty) are installed as symlinks
# pointing back into the repo, so editing the live file *is* editing the repo.
# Any existing file at the target is removed without backup.
#
# iTerm's profile + app-prefs are NOT symlinks — they're merged into the iTerm
# plist directly, since the plist isn't a file we own.
#
# Usage:
#   ./install.sh                       # from a local clone (anywhere)
#   curl -fsSL https://raw.githubusercontent.com/sunfmin/dotfiles/main/install.sh | bash
#                                      # self-bootstraps by cloning to ~/dotfiles

set -euo pipefail

REPO_URL="https://github.com/sunfmin/dotfiles.git"
DEFAULT_CLONE="$HOME/dotfiles"

# Resolve where this script lives. When piped from curl, BASH_SOURCE[0] is empty
# or unreliable, so we treat that as "not a local clone" and bootstrap.
SELF="${BASH_SOURCE[0]:-}"
if [[ -n "$SELF" && -f "$SELF" ]]; then
    REPO_DIR="$(cd "$(dirname "$SELF")" && pwd)"
else
    REPO_DIR=""
fi

if [[ -z "$REPO_DIR" || ! -f "$REPO_DIR/claude/settings.json" ]]; then
    # Symlinks need a stable repo location — bootstrap into ~/dotfiles, not /tmp.
    if [[ -e "$DEFAULT_CLONE" ]]; then
        echo "error: $DEFAULT_CLONE already exists; cd into it and run ./install.sh manually" >&2
        exit 1
    fi
    printf '\033[1;34m==>\033[0m Bootstrapping: cloning %s into %s\n' "$REPO_URL" "$DEFAULT_CLONE"
    git clone "$REPO_URL" "$DEFAULT_CLONE"
    exec bash "$DEFAULT_CLONE/install.sh"
fi

TS="$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }

link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    ok "linked $dst -> $src"
}

# --- Homebrew + Brewfile ---------------------------------------------------

if ! command -v brew >/dev/null 2>&1; then
    log "Homebrew not found — installing"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for the rest of this script (Apple Silicon default).
    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

log "Installing software via Brewfile"
brew bundle --file="$REPO_DIR/Brewfile"
ok "brew bundle done"

# --- Claude Code CLI -------------------------------------------------------

if ! command -v claude >/dev/null 2>&1; then
    log "Installing Claude Code CLI via npm"
    npm install -g @anthropic-ai/claude-code
fi

log "Linking Claude settings into ~/.claude/"
link "$REPO_DIR/claude/settings.json" "$HOME/.claude/settings.json"
link "$REPO_DIR/claude/statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$REPO_DIR/claude/statusline.sh"

# --- iTerm2 ----------------------------------------------------------------

ITERM_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
PROFILE_JSON="$REPO_DIR/iterm/Default.json"
APP_PREFS="$REPO_DIR/iterm/app-prefs.json"

# Remove any prior Dynamic Profile install — earlier versions of this script
# dropped Default.json into DynamicProfiles/, which collides with the in-plist
# profile that shares the same Guid. The non-dynamic profile in the plist is
# now the single source of truth on the machine.
ITERM_DYN_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
rm -f "$ITERM_DYN_DIR/Default.json"

# The iTerm plist holds settings that aren't in this repo (window arrangements,
# command history, other profiles…), so we DO back it up before the merge —
# unlike the symlinked configs whose content is in git already.
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
    log "Linking cmux config into ~/.config/cmux/"
    link "$REPO_DIR/cmux/cmux.json" "$HOME/.config/cmux/cmux.json"
fi

# --- Ghostty ---------------------------------------------------------------
#
# Ghostty on macOS reads from BOTH paths and merges them, with the macOS path
# winning on conflicts:
#   1. ~/.config/ghostty/config                                   (XDG, read first)
#   2. ~/Library/Application Support/com.mitchellh.ghostty/config (macOS, overrides)
# cmux's bundled Ghostty + the standalone Ghostty.app both write to path #2,
# so if we only symlink #1, anything they write silently overrides our repo
# values. Symlink BOTH paths to the same repo file so there's one source of
# truth and UI-driven writes flow back into git.

if [[ -f "$REPO_DIR/ghostty/config" ]]; then
    log "Linking Ghostty config into ~/.config/ghostty/ and macOS Application Support"
    link "$REPO_DIR/ghostty/config" "$HOME/.config/ghostty/config"
    link "$REPO_DIR/ghostty/config" "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
fi

cat <<EOF

Done.

Software (iTerm2, Ghostty, cmux, node, etc.) installed via Brewfile.
Claude Code CLI installed via npm.

Claude / cmux / Ghostty configs are now symlinks into $REPO_DIR —
edit them in either place and the change is the same. Commit + push when ready.

The Default profile in iTerm has been merged into the plist (not a symlink);
relaunch iTerm to pick up the new values.
EOF

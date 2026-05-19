# dotfiles

Personal macOS dotfiles — Claude Code, iTerm2, cmux, Ghostty — synced across machines.

## Contents

| Path | Installed to |
| --- | --- |
| `claude/settings.json` | `~/.claude/settings.json` |
| `claude/statusline.sh` | `~/.claude/statusline.sh` |
| `iterm/Default.json` | merged into the **Default** profile inside `~/Library/Preferences/com.googlecode.iterm2.plist` (matched by Guid) |
| `iterm/app-prefs.json` | merged into `~/Library/Preferences/com.googlecode.iterm2.plist` |
| `cmux/cmux.json` | `~/.config/cmux/cmux.json` |
| `ghostty/config` | `~/.config/ghostty/config` |

The iTerm profile is installed directly into the plist — the existing Default profile (matched by Guid `DC718448-DCA9-4DE4-9CDC-989D58A849A4`) is replaced in place, so no extra profile appears in the picker.

`app-prefs.json` carries top-level iTerm preferences that aren't part of a profile (tab bar width / position, pointer & gesture actions, ESC indicator settings, etc.). The installer merges them into the plist, then nudges `cfprefsd` so new iTerm windows pick them up.

## Install

One-liner — the script self-bootstraps by cloning the repo into `/tmp` and re-running itself:

```bash
curl -fsSL https://raw.githubusercontent.com/sunfmin/dotfiles/main/install.sh | bash
```

Or from a local clone:

```bash
git clone https://github.com/sunfmin/dotfiles.git
cd dotfiles && ./install.sh
```

Existing files are backed up to `<file>.bak-<timestamp>` before being overwritten — nothing is lost.

Already-open iTerm windows keep their old settings; relaunch (or open a new window) to pick up the merged values.

## Updating the repo from the current machine

After tweaking settings locally, re-export and commit:

```bash
# Claude
cp ~/.claude/settings.json  claude/settings.json
cp ~/.claude/statusline.sh  claude/statusline.sh

# iTerm — re-export the Default profile (matched by its stable Guid)
/usr/libexec/PlistBuddy -x -c 'Print :"New Bookmarks":0' \
    ~/Library/Preferences/com.googlecode.iterm2.plist > /tmp/iterm.plist
plutil -convert json -o /tmp/iterm.json /tmp/iterm.plist
jq '{Profiles: [.]}' /tmp/iterm.json > iterm/Default.json

# iTerm app-level prefs — re-export the curated key subset
python3 - <<'PY' > iterm/app-prefs.json
import plistlib, json, os
keys = ['HapticFeedbackForEsc','SoundForEsc','VisualIndicatorForEsc',
        'HideTab','LeftTabBarWidth','PointerActions','TabViewType','findMode_iTerm']
with open(os.path.expanduser('~/Library/Preferences/com.googlecode.iterm2.plist'),'rb') as f:
    d = plistlib.load(f)
print(json.dumps({k: d[k] for k in keys if k in d}, indent=2, default=str))
PY

# cmux + Ghostty
cp ~/.config/cmux/cmux.json    cmux/cmux.json
cp ~/.config/ghostty/config    ghostty/config

git add -A && git commit -m "sync settings from $(hostname -s)" && git push
```

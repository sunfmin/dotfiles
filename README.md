# dotfiles

Personal macOS setup — Claude Code, iTerm2, cmux, Ghostty — configs synced
across machines. The installer wires up configs only; it does **not** install
software.

## What it does

The installer (`install.sh`) wires up configs — it does **not** install any
software:

1. **Symlinks file-based configs** from this repo into their live locations
   (see the table below). Editing the live file *is* editing the repo file.
2. **Merges iTerm settings** into the iTerm plist — the iTerm profile and
   app-level prefs can't be symlinks because the plist holds other state
   too, so the installer rewrites just the **Default** profile (matched by
   its stable Guid `DC718448-DCA9-4DE4-9CDC-989D58A849A4`) plus a curated
   set of app-level keys.

The software these configs are for is **not** installed automatically —
install it yourself:

```bash
brew bundle --file=Brewfile          # iTerm2, Ghostty, cmux, node, jq, git
npm i -g @anthropic-ai/claude-code   # Claude Code CLI
```

| Path in repo | Installed as | Mechanism |
| --- | --- | --- |
| `claude/settings.json` | `~/.claude/settings.json` | symlink |
| `claude/statusline.sh` | `~/.claude/statusline.sh` | symlink |
| `claude/daily-review/com.sunfmin.claude-daily-review.plist` | `~/Library/LaunchAgents/` | symlink, loaded: at 06:00 reviews yesterday's Claude Code work against the principles in `CLAUDE.md`: a detailed report in `~/.local/share/claude-daily-review/`, and a PR here when a rule should change, its findings in the PR body |
| `cmux/cmux.json` | `~/.config/cmux/cmux.json` | symlink |
| `ghostty/config` | `~/.config/ghostty/config` | symlink |
| `iterm/Default.json` | Default profile inside `~/Library/Preferences/com.googlecode.iterm2.plist` | plist merge by Guid |
| `iterm/app-prefs.json` | top-level keys in the same plist | plist merge |
| `Brewfile` | (not installed; run `brew bundle` manually) | — |

## Install (new machine)

```bash
curl -fsSL https://raw.githubusercontent.com/sunfmin/dotfiles/main/install.sh | bash
```

The script bootstraps by cloning the repo into `~/dotfiles` (the symlinks
need a stable location), then re-runs itself from there.

Or from an existing clone anywhere:

```bash
git clone https://github.com/sunfmin/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

> Re-running is safe. `ln -sfn` overwrites old symlinks, and the iTerm plist
> merge only touches the keys we manage.
>
> Already-open iTerm windows keep their old settings until relaunch.

## Updating

Because file-based configs are symlinks, just edit the live file (e.g.
change `font-size` in Ghostty's settings UI, or hand-edit
`~/.config/ghostty/config`) — you're editing the repo. Then:

```bash
cd ~/dotfiles && git add -A && git commit -m "sync from $(hostname -s)" && git push
```

iTerm is the only thing that needs re-exporting, since its config isn't a
symlinkable file:

```bash
cd ~/dotfiles

# Re-export the Default profile (matched by its stable Guid)
/usr/libexec/PlistBuddy -x -c 'Print :"New Bookmarks":0' \
    ~/Library/Preferences/com.googlecode.iterm2.plist > /tmp/iterm.plist
plutil -convert json -o /tmp/iterm.json /tmp/iterm.plist
jq '{Profiles: [.]}' /tmp/iterm.json > iterm/Default.json

# Re-export the curated app-level key subset
python3 - <<'PY' > iterm/app-prefs.json
import plistlib, json, os
keys = ['HapticFeedbackForEsc','SoundForEsc','VisualIndicatorForEsc',
        'HideTab','LeftTabBarWidth','PointerActions','TabViewType','findMode_iTerm']
with open(os.path.expanduser('~/Library/Preferences/com.googlecode.iterm2.plist'),'rb') as f:
    d = plistlib.load(f)
print(json.dumps({k: d[k] for k in keys if k in d}, indent=2, default=str))
PY

git add -A && git commit -m "iterm sync from $(hostname -s)" && git push
```

To capture additional Homebrew-installed apps into the Brewfile later:

```bash
brew bundle dump --file=Brewfile --force   # overwrites with current state
```

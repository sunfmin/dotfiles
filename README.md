# claude-settings

Personal Claude Code + iTerm2 config, synced across machines.

## Contents

| Path | Installed to |
| --- | --- |
| `claude/settings.json` | `~/.claude/settings.json` |
| `claude/statusline.sh` | `~/.claude/statusline.sh` |
| `claude/statusline-command.sh` | `~/.claude/statusline-command.sh` |
| `iterm/Default.json` | `~/Library/Application Support/iTerm2/DynamicProfiles/Default.json` |

The iTerm profile is shipped as an [iTerm2 Dynamic Profile](https://iterm2.com/documentation-dynamic-profiles.html) named **Synced**. iTerm reloads it automatically when the file changes — no restart needed.

## Install

One-liner — the script self-bootstraps by cloning the repo into `/tmp` and re-running itself:

```bash
curl -fsSL https://raw.githubusercontent.com/sunfmin/claude-settings/main/install.sh | bash
```

Or from a local clone:

```bash
git clone https://github.com/sunfmin/claude-settings.git
cd claude-settings && ./install.sh
```

Existing files are backed up to `<file>.bak-<timestamp>` before being overwritten — nothing is lost.

After install, set the iTerm profile as default:

> iTerm2 → Settings → Profiles → select **Synced** → *Other Actions…* → *Set as Default*.

## Updating the repo from the current machine

After tweaking settings locally, re-export and commit:

```bash
# Claude
cp ~/.claude/settings.json          claude/settings.json
cp ~/.claude/statusline.sh          claude/statusline.sh
cp ~/.claude/statusline-command.sh  claude/statusline-command.sh

# iTerm — re-export the Default profile
/usr/libexec/PlistBuddy -x -c 'Print :"New Bookmarks":0' \
    ~/Library/Preferences/com.googlecode.iterm2.plist > /tmp/iterm.plist
plutil -convert json -o /tmp/iterm.json /tmp/iterm.plist
jq '{Profiles: [(. + {Name: "Synced", Guid: "DC718448-DCA9-4DE4-9CDC-989D58A849A4", "Working Directory": ""})]}' \
    /tmp/iterm.json > iterm/Default.json

git add -A && git commit -m "sync settings from $(hostname -s)" && git push
```

# Global Claude config

## sudo

No tty here. Plain `sudo` fail. Use sudoplz askpass.

Prefix every sudo cmd:

```
SUDO_ASKPASS=$HOME/.local/bin/askpass sudo -A <cmd>
```

GUI dialog pop -> user approve per cmd. Deny -> cmd fail, retry not allowed.

Setup (once, user terminal):

```
brew install age
uv tool install sudoplz
sudoplz set
```

Needs: `uv`, `age`, ed25519 key at `~/.ssh/id_ed25519`.

## skills

Installed via `npx skills`. Copies at `~/.agents/skills/<name>/` (symlinked into
`~/.claude/skills/`). **Never edit there** -> `npx skills update` overwrites from
source repo, edits lost.

Source of truth: `~/.agents/.skill-lock.json`. Each entry has `source`
(e.g. `sunfmin/whats-hot`) + `skillPath`. `source` under `sunfmin/` = mine.

Mine live at `~/Developments/<repo>`, `<repo>` = `source` after `sunfmin/`
(`sunfmin/whats-hot` -> `~/Developments/whats-hot`). Git remote = same repo on GitHub.

Change my skill:

1. Lockfile -> get `source` + `skillPath`.
2. Edit `~/Developments/<repo>` (file at `skillPath`, e.g. `SKILL.md`).
3. `git commit` + `git push`.
4. `npx skills update` -> pulls into `~/.agents/skills/`.

`source` not under `sunfmin/` (mattpocock/skills, anthropics/skills,
mvanhorn/cli-printing-press) = third-party, not mine. No edit+push. Surface instead.

## rg, not grep

Search files -> built-in Grep tool (rg under the hood). Filter output -> pipe to `rg`.
Never shell out to `grep`/`egrep`/`fgrep` -> a global PreToolUse hook denies them.
`pgrep`, `zgrep`, `git grep` still ok.

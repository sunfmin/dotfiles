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

# Global Claude config

## 时间意识

用户等的每一秒都是成本。做之前先估这事该花多久；实际明显超出 → 停下来换路子，别闷头硬等。

- **小事直接做**：读已知文件、改一行、答已知事实 → 别 spawn subagent、别开 workflow、别全仓库大搜。
- **测量，别猜**：报告里给**实测秒数**，不写「应该很快」「大概几分钟」；优化前后都要有数。
- **超过 ~30s 先打招呼**：一句话说清在干嘛、大概多久；有阶段性结果先给出来。
- **等待要有上限**：轮询 / 等状态设死上限，超了就报告当前状况。

## sudo

No tty here. Plain `sudo` fail -> prefix every sudo cmd:

```
SUDO_ASKPASS=$HOME/.local/bin/askpass sudo -A <cmd>
```

GUI dialog pop -> user approve per cmd. Deny -> cmd fail, retry not allowed.

## skills

Installed via `npx skills` into `~/.agents/skills/<name>/` (symlinked into
`~/.claude/skills/`). **Never edit there** -> `npx skills update` overwrites.

- Source of truth: `~/.agents/.skill-lock.json` -> `source` + `skillPath` per skill.
- `source` under `sunfmin/` = mine, repo at `~/Developments/<repo>`
  (`sunfmin/whats-hot` -> `~/Developments/whats-hot`).
- Change mine: edit the file at `skillPath` in that repo -> `git commit` + `git push`
  -> `npx skills update`.
- Any other `source` = third-party. No edit+push. Surface instead.

## rg, not grep

Never shell out to `grep`/`egrep`/`fgrep` (a PreToolUse hook denies them) -> Grep tool,
or pipe to `rg`. `pgrep`, `zgrep`, `git grep` still ok.

## python 一律用 uv

跑任何 Python 都走 `uv`（`uv run` / `uvx` / `uv add`），别用系统 `python3`、`pip`、手管 venv。
一行验证也一样：`uv run --with <pkg> python -c '...'`。细则见 `mypython` skill。

## 大文件下载

下大文件（模型权重、数据集、release、镜像、视频……）前先查本地有没有（`~/.cache/huggingface`、
`~/.cache/modelscope`、下载目录、工具自带缓存），有就直接用。确实要下 -> **先和我确认**，
工具首次运行触发的隐式拉取也算。

## auto commit & push

阶段性任务完成 -> 自动 `git commit` + `git push` 到当前工作分支，不用等我开口（覆盖默认的
「要求了才 commit / push」）。非 git repo -> skip。

- 每个有意义的阶段一个 commit（一个 feature / fix / 一段测试跑通 / 一步 refactor），别攒成一个大 commit。Message 简洁；保留 `Co-Authored-By` trailer。
- 只推自己的工作分支：`git push -u origin <当前分支>`。
- **绝不主动动主干**（`main` / `master` / `staging` / `develop` 之类）：不 push、不 merge、不 rebase，除非我明确说。当前就在主干上 -> 先开一条新 branch。
- `--force` / `--force-with-lease` 也要我明确说。
- **任务做完 -> 自动开 PR**：`gh pr create` 到默认分支（`git symbolic-ref refs/remotes/origin/HEAD` 现取，别背常量）。只开，不 merge、不 approve、不打 auto-merge；分支已有 PR -> push 即更新。Body 写清做了啥、怎么验证的、哪些没验证；`Closes #n` 关联对应 issue。

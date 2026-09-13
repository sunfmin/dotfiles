# Global Claude config

## 时间意识（贯穿所有任务）

做任何事之前先问一句：**这事本来该花多久？** 然后按那个量级去做。用户等的每一秒都是成本，快 = 好体验。

- **先估，再做**：这一步是 1 秒、10 秒还是 5 分钟的事？实际明显超出预期 → 停下来换路子，别闷头硬等。
- **小事必须快**：读一个已知文件、改一行、答一个已经知道的事实 → 直接做。别为此 spawn subagent、别开 workflow、别全仓库大搜。工具选最短路径（知道文件就 Read，别 Explore）。
- **能并行就并行**：互相不依赖的工具调用放同一个 block 一起发，别一个个串着等。
- **长活儿放后台**：build / test / 下载 / 跑模型这类，用 `run_in_background` + 合理 timeout，别把会话卡死在前台。
- **测量，别猜**：怀疑慢就计时（`time`、`--verbose`、打点），报告里给**实测秒数**，不要写「应该很快」「大概几分钟」。优化前后都要有数。
- **超过 ~30s 的事先打个招呼**：一句话说清在干嘛、大概多久；中间有阶段性结果就先给出来，别攒到最后一次性倒。
- **等待要有上限**：轮询 / 等状态设死上限，超了就报告当前状况，不要无限等下去。
- **别把快的做慢**：一次调用能解决的不拆成五步；缓存里已经有的不重下、不重算。

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

## dreamina credits

Every `dreamina` generation call (text2image, image2image, text2video, image2video,
frames2video, multiframe2video, multimodal2video, image_upscale ...) -> after it
returns, report credit spend as a per-step line:

```
第N步 <cmd>: 消耗 <credit_count> credits, 余额 <total_credit>
```

`credit_count` -> from the task result JSON. Balance -> `dreamina user_credit`
(`total_credit`). Multiple calls in a turn -> one line each, plus a total-consumed
summary at the end.

## dreamina video queue (vip = 快队列)

Dreamina video gen has TWO queues, gated by model tier:

- `_vip` models (`seedance2.0_vip`, `seedance2.0fast_vip`) -> **快队列 / priority**:
  reach `queue_status: Generating` in ~1-2 min, finish in a few min.
- non-vip models (`seedance2.0`, `seedance2.0fast`, `seedance2.0mini`) -> **慢队列 / free**:
  can sit at `queue_status: Queueing` for 30-40+ min, sometimes effectively stuck.

Rule: any video that must land promptly -> ALWAYS use a `_vip` model. Non-vip only for
"don't care when it finishes". `_vip` also costs more and is the only tier reaching 1080p/4K.
There is NO CLI cancel -> a slow-queue task, once submitted, can't be aborted (only ignored).

## rg, not grep

Search files -> built-in Grep tool (rg under the hood). Filter output -> pipe to `rg`.
Never shell out to `grep`/`egrep`/`fgrep` -> a global PreToolUse hook denies them.
`pgrep`, `zgrep`, `git grep` still ok.

## python 一律用 uv

跑任何 Python 都走 `uv`，别直接用系统/homebrew 的 `python3`、`pip`、`venv`。

- 单文件脚本 -> `uv run script.py`。要依赖就写 PEP 723 inline metadata（文件头 `# /// script` 块里列 `dependencies`），`uv run` 自己装，不用先建环境。
- 一次性跑某个包的命令 -> `uvx <tool>`。
- 装常驻 CLI 工具 -> `uv tool install <pkg>`。
- 项目内 -> `uv sync` + `uv run <cmd>`；加依赖用 `uv add`，**不要** `pip install`。
- 要指定版本 -> `uv run --python 3.12 ...`，别手动装 python。
- 临时验证一行代码也一样：`uv run --with <pkg> python -c '...'`，别 `python3 -c`。

理由：系统 python 的包不全（连 `import packaging` 都可能炸）、`pip install` 会污染 homebrew
的 site-packages、手管 venv 容易漂。uv 每次都从锁定依赖起一个干净环境。

## 大文件下载

下大文件（模型权重、数据集、release、tarball/zip、ISO、镜像、视频……）前，**先搜确认本地有没有**：

- 查 `~/.cache/huggingface`、`~/.cache/modelscope`、aria2/下载目标目录、已有产物、venv/工具自带缓存等。
- 已有 -> 直接用，**别重复下**。
- 确实缺、真需要下 -> **先和我确认**，得到同意再下。别擅自 `hf download` / `wget` / `curl -O` / aria2 / 工具首次运行触发的隐式拉取就把几个 G 拉下来。

不确定「会不会触发下载」也先说一声，别默默开下。

## auto commit & push

阶段性任务完成 -> 自动 `git commit` + `git push` 到当前这条工作分支，不用等我开口。这条覆盖默认的「只有我要求才 commit / push」。

- Git repo only. 非 repo -> skip.
- 每个有意义的阶段 = 一个 commit：一个 feature、一个 fix、一段测试跑通、一步 refactor。别把整个 session 攒成一个大 commit。
- **Push 只推自己这条工作分支**：`git push -u origin <当前分支>`（第一次带 `-u` 建 upstream）。
- **绝不主动动主干分支**（`main` / `master` / `staging` / `develop` 之类）：不往主干 push、不 merge 进主干、不 rebase 主干、不开 PR。要进主干必须我明确说。
- 任何 `--force` / `--force-with-lease` 也要我明确说。
- 当前就在主干分支上 -> 先开一条新 branch 再 commit + push，别直接推主干。
- Message 简洁，描述这一步做了啥；保留 `Co-Authored-By` trailer。

## 新任务 -> 先判断要不要开新 worktree（Orca）

接到一个**要动代码**的新任务，动手前先过这三问：

1. 这是改代码的活儿吗？问答 / 调研 / 只读 / 改我的配置 -> **不开**，就地做。
2. 跟当前 worktree 正在做的是同一件事吗？是（修它、续它、补测试、改它的文档）-> **不开**，就地做。
3. 当前分支已开 PR / 在 review，或工作区的脏改动跟新任务无关 -> **开**。

要开就**派出去**，别自己搬：

```
orca worktree create --name <任务名> --agent claude --prompt "<原任务原样转述>" \
  --base-branch <base> --json
```

- **base 怎么定**：`git symbolic-ref refs/remotes/origin/HEAD`（gaokaowiki 上 = `origin/staging`）。
  绝不拿当前 feature 分支当 base，除非我明说「从当前分支切」/ 要 stacked。
- **lineage**：跟当前活儿相关 -> 默认继承 parent（或 `--parent-worktree active`）；完全无关 -> `--no-parent`。
- `--name` 用任务本身起名，别用随机词。
- 建完回我一行：worktree 名 + 路径 + 分支 + base，然后**这边收工**，别在旧 worktree 里把同一件事再做一遍。

禁止项：

- 别用 Claude Code 自带的 `EnterWorktree` 新建 -> 它建在 `.claude/worktrees/`，Orca 不认，卡片里看不见。Orca 环境一律 `orca worktree create`。
- 不在 Orca 里（没 `orca`、或 `orca status` 不通）-> 整条跳过，按 auto commit & push 那条走（当前在主干就先开分支）。
- 拿不准算不算「换任务」-> 问我一句，别默默开。

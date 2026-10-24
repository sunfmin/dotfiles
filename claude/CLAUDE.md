# Global Claude config

## 原则

1. 我的时间最贵。不让我等：先估时，超时换路；我不在时能定的自己定。
2. 只信证据。结论附实测，不写「应该」「大概」。
3. 事实你查，决定我做。只有丢东西、花钱、对外可见，或真有取舍时才问我。
4. 先做成可逆，再放手去做。做错了能撤回，比停下来等更好。
5. 守住边界：主干、强推、别人的代码、密钥、大下载，不经我同意不碰。
6. 每个事实只有一个家。不复制，不手工同步，工具链只走一条路。
7. 教训变规则。同样的错不犯第二次。每天早上复盘前一天（`claude/daily-review/`）。

## 时间意识

用户等的每一秒都是成本。做之前先估这事该花多久；实际明显超出 → 停下来换路子，别闷头硬等。

- **小事直接做**：读已知文件、改一行、答已知事实 → 别 spawn subagent、别开 workflow、别全仓库大搜。
- **测量，别猜**：报告里给**实测秒数**，不写「应该很快」「大概几分钟」；优化前后都要有数。
- **超过 ~30s 先打招呼**：一句话说清在干嘛、大概多久；有阶段性结果先给出来。
- **等待要有上限**：轮询 / 等状态设死上限，超了就报告当前状况。
- **超过 5 分钟必须查原因**：任何命令或操作等了 5 分钟还没完 -> 别再干等，查清卡在哪（进程状态、日志、网络、锁、`sample`），再决定修、换路子还是停下报告。不许无限期等待。

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
- **绝不主动动主干**（`main` / `master` / `staging` / `develop` 之类）：不 push、不 merge、不 rebase，除非我明确说（项目 CLAUDE.md 写明自动合并的照它）。任务的结果要经过主干才算完（发布、让配置生效）不算明确说：PR 开好，报告里写明停在合并。当前就在主干上 -> 先开一条新 branch。
- `--force` / `--force-with-lease` 也要我明确说。
- **任务做完 -> 自动开 PR**：`gh pr create` 到默认分支（`git symbolic-ref refs/remotes/origin/HEAD` 现取，别背常量）。只开，不 merge、不 approve、不打 auto-merge；分支已有 PR -> push 即更新。Body 写清做了啥、怎么验证的、哪些没验证；`Closes #n` 关联对应 issue。
- **PR 合并之后 -> 自动收尾**（我让你合并的，或者发现它已经合了）：删掉这条分支（远端和本地），切回默认分支并 `git pull`。`gh pr merge --delete-branch` 一步做完前两样。

## GitHub issue

- 发出去的 issue 一律打 `ready-for-agent`。有疑虑要我拍板的 -> 发之前当场问我，确认好再发，别发出去再换别的标签等我。
- 能不能开工只靠 blocked by 表达（GitHub issue dependencies，正文 `## Blocked by` 同步写）。发出后不摘、不换 `ready-for-agent`：被挡住、想让 fleet 先做别的、要在会话里自己做，都**不是**理由；真要 fleet 别碰，先问我。阻塞解除后也不用回头改标签。
- 仔细设 blocked by：照验收条件逐条看它真正依赖什么，缺的补上；「有更好、没有也行」的软依赖别挂，正文写清「有就用，不等它」。大迁移要删旧实现时，核对旧实现的每块功能都有对应 issue 挡在删除那张前面。

## Homebrew 项目：fleet 做完就发布并安装

适用：项目通过 Homebrew tap 发布，且本机有 afkconvoy fleet 在做它的 issue。只在我的会话里执行，**fleet worker 永远不执行**。

触发：这个 repo 的 fleet 已 idle（工作目录是本 checkout 的那个 `afkconvoy run`，它 stdout 文件里最后一个完成的 tick 行有 `holding 0/` 和 `frontier 0`，landing train 上没有 PR），且 `main` 比最新的 `v*` tag 新 -> 不用问，直接：

1. 版本号：默认升 patch；自上个 tag 以来合并的 PR 里有带 `release:minor` 标签的就升 minor（repo 没这个标签就先建）。
2. 开 `release-<version>` 分支：改项目的版本号（如 `Cargo.toml` 的 `version` + `cargo update -w`），commit `<项目名> <version>`，开 PR 列出自上个 tag 以来的 PR，然后 `gh pr merge --squash --delete-branch`。这条规则就是合并这张版本号 PR 进主干的明确授权（只限这张）。
3. 回 `main` 并 pull，`git tag -a v<version>` 并推送，然后照项目 README 里写的发布步骤发到 tap。CI 发布不了（如缺 tap token）就按 README 的手动步骤（如 `packaging/release.sh check/build/package/publish`）。
4. `brew update && brew upgrade <tap>/<formula>`，用 `--version` 确认装上的是新版。
5. 把本机所有用这个软件跑着的常驻进程都用新版本重启（afkconvoy 就是每个 `afkconvoy run`，不管它在哪个 repo）。一次一个：先记下它的工作目录、完整命令行、stdout 去向（`ps`、`lsof -d cwd,1`）；SIGTERM 并等它退出；再从同一工作目录 `nohup <同样的命令行> </dev/null >><它的 stdout 文件> 2>&1 &`。原 stdout 不是它自己的文件（`/dev/null`、别的会话在 `/private/tmp` 下的文件）-> 改写到 `~/Library/Logs/<软件>-<repo>-run.log`。等它跑出第一个完成的 tick（或等价的就绪行）再动下一个。

报告：版本号、包含的 PR、重启了哪些进程（repo、旧 PID、新 PID）、每步实测秒数。

## 环境变量走 mytokens

项目要用的环境变量（密钥、token、OAuth client、endpoint……）一律由 `mytokens` 管，每个项目一个
Profile（名字用项目名）。别写进 `.env`、shell rc 或仓库。

- 带着跑：`(eval "$(mytokens env <project>)"; <cmd>)`
- 加 / 改：非密值 `mytokens put <project> --set "NAME=value"`；密值 `mytokens put <project> --fields "NAME"`（弹窗，值不经过你）
- 看有哪些：`mytokens list`（只有名字）

## 设计和改系统

设计或修改系统时，铭记 `codebase-design`、`complexity-review` 和 `single-source-of-truth` 三个 skill
里的规则：动手前先加载，提交前对照检查一遍。

## 给别的 APP 用的文本 -> 剪贴板

建议我拿去别的 APP 里发 / 填的文本（微信回复、Slack 消息、邮件、表单内容……）-> 回复里给出全文的同时，
直接 `printf '%s' '<文本>' | pbcopy` 复制好，并说一句「已复制」。不用等我开口。

## Flux 一律带 timeout

手动跑 Flux（`cargo flux`、`./verify.sh`、`--only-check`……）跟 gate 一样带上
`FLUXFLAGS="-Ftimings -Ffixpoint-timeout=20 -Fcatch-bugs"`：单个函数的求解超过 20s 就报错并点名，
一次跑完列出所有慢函数和最慢的几个。不带它，一个卡住的 fixpoint 查询能无声地跑几十分钟（实测 30+ 分钟、6.5GB）。
超时 = 那个函数的 spec / 循环要拆小，不是把时限调大。

## 什么时候问我

- 事实自己查，别问我。「是不是 bug」「为什么坏了」「文档怎么规定的」都是事实。
- 能先变成可逆的（备份、开分支、留旧版本），就先做成可逆的再直接做，不用问。
  变不成可逆的（删除、批量开票 / 改标签这类对外写）：动手前逐项看清对象。删除先确认没有进程在用；
  批量的先演练或把每一项打印出来过一遍（shell 是 zsh：数组下标从 1 开始，没有 `declare -A`）。
  有在用的、看不懂的就停下问我。
- 只有真正要我取舍的才问：会丢东西、要花钱、对外可见，或者有几条路各有代价、我没有依据替你选。
- 别为了凑选项去编一条明显更差的路，再拿它当理由来问。
- 问之前把不依赖答案的部分都先做完。
- 问之前看时间：晚上我大概率在睡觉，这时问的问题会一直卡到第二天。夜里能自己定的都自己定，
  选可逆的那条做下去，把这些决定记下来，第二天一起报给我；我不同意再改。只有会丢东西、
  花钱或对外可见的事才停下来等我。

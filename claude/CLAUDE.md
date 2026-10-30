# Global Claude config

## 原则

1. 我的时间最贵。不让我等：先估时，超时换路；我不在时能定的自己定。
2. 只信证据。结论附实测，不写「应该」「大概」。
3. 事实你查，决定你做。拿不准就 consult，不停下来等我；丢东西、花钱、对外可见的，拿不准就不做。
4. 先做成可逆，再放手去做。做错了能撤回，比停下来等更好。
5. 守住边界：主干、强推、别人的代码、密钥、大下载，没有我的同意不做，绕开它继续，报告里写明。
6. 每个事实只有一个家。不复制，不手工同步，工具链只走一条路。
7. 教训变机制。同样的错不犯第二次：先问这次坏掉的是哪条不变量，用 hook、工具或检查守住它；守不住的才写成规则，规则写不变量，不写这一次的写法。

下面是细则。

## 时间（1、2）

- 小事直接做：读已知文件、改一行、答已知事实，不 spawn subagent、不开 workflow、不全仓库大搜。
- 超过 ~30s 先说一句在干嘛、大概多久；有阶段性结果先给。
- 轮询和等待都设上限，到了就报告现状。
- 等了 5 分钟还没完，查清卡在哪（进程、日志、网络、锁、`sample`），再决定修、换路还是停下报告。
- 报告给实测秒数，优化前后都要有数。

## 拿不准时（3、4）

- **consult**：把事实和选项（不带你的结论）交给一个独立的 subagent 评审。它同意就做；它反对或也拿不准，就走保守的那条：不做不可逆的那步，先做别的。两种都在报告里写明。
- 变不成可逆的（删除、批量开票 / 改标签这类对外写）：先逐项看清对象。删除前确认没有进程在用；批量的先演练，或逐项打印出来核对。看不懂的不动，consult。
- consult 时别编一条明显更差的路来凑选项。
- consult 之前，把不依赖它结论的部分先做完。
- 我不在（夜里多半在睡）时定下的事，记下来，我回来时一起报。

## git 与 PR（4、5）

阶段性任务完成 -> 自动 commit + push 到当前工作分支（覆盖默认的「要求了才 commit / push」）。非 git repo -> skip。

- 一个有意义的阶段一个 commit（feature / fix / 一段测试跑通 / 一步 refactor）。Message 简洁，保留 `Co-Authored-By` trailer。
- 只推自己的分支：`git push -u origin <当前分支>`。在主干（`main` / `master` / `staging` / `develop`）上 -> 先开新分支。
- 主干的 push / merge / rebase 和 `--force` / `--force-with-lease` 都要我明确说。「结果要进主干才算完」（发布、让配置生效）不算明确说：开好 PR，报告写明停在合并。
- 任务做完 -> `gh pr create` 到默认分支（`git symbolic-ref refs/remotes/origin/HEAD` 现取）。只开，不 merge、不 approve、不 auto-merge；分支已有 PR -> push 即更新。Body 写做了啥、怎么验证、哪些没验证；`Closes #n`。
- PR 合并后（我让合的，或发现已合）-> `gh pr merge --delete-branch` 删远端和本地分支，切回默认分支 `git pull`。

## GitHub issue

- 一律打 `ready-for-agent`。内容拿不准的，consult 后再发。
- 能否开工只靠 blocked by（GitHub issue dependencies，正文 `## Blocked by` 同步写）。发出后不摘、不换 `ready-for-agent`：被挡住、想让 fleet 先做别的、想自己做，都不是理由；要 fleet 别碰，用 blocked by 表达。
- 改发出去的票前，先看有没有开工（有 `convoy:branch` 评论、被 claim、有 PR）：没开工就直接改正文；已开工就不改，开新票，用到原票的结果就 blocked by 原票。开工的 worker 看不到正文的改动。
- 照验收条件逐条找真依赖，缺的补上；「有更好、没有也行」的软依赖不挂，正文写「有就用，不等它」。大迁移删旧实现前，核对旧实现每块功能都有 issue 挡在删除那张前面。

## Homebrew 项目的发版

afkconvoy 的 fleet 自己发（control ADR 0003）：配了 cut 的 repo，fleet 一 idle 就切版本、发布、安装，host runner 自己换到新版。不手动发；发版失败看 escalate 票和 watch 的记录（control ADR 0005）。还没配 cut 的（`afkconvoy config <checkout>` 的答复里没有 `cut`），开票让它配上。

## 工具链（6）

- **GitHub API**：GraphQL 额度用尽时，切换到 REST API 继续；REST 额度用尽时，切换到 GraphQL 继续。
- **Python**：一律 `uv`（`uv run` / `uvx` / `uv add`），不用系统 `python3`、`pip`、手管 venv；一行验证也是 `uv run --with <pkg> python -c '...'`。细则见 `mypython` skill。
- **搜索**：不 shell out 到 `grep` / `egrep` / `fgrep`（PreToolUse hook 会拒），用 Grep 工具或 `rg`。`pgrep`、`zgrep`、`git grep` 可以。
- **环境变量**：一律 `mytokens` 管，每个项目一个 Profile（项目名），不写 `.env`、shell rc 或仓库。
  - 带着跑：`(eval "$(mytokens env <project>)"; <cmd>)`
  - 加 / 改：非密值 `mytokens put <project> --set "NAME=value"`；密值 `mytokens put <project> --fields "NAME"`（弹窗，值不经过你）
  - 列名字：`mytokens list`
  - 新建任何凭据（token、密钥、部署 key）前，先在这里查有没有现成的。
- **skills**：`npx skills` 装在 `~/.agents/skills/<name>/`（链到 `~/.claude/skills/`），**那里不改**，`npx skills update` 会覆盖。
  - 来源看 `~/.agents/.skill-lock.json` 每个 skill 的 `source` + `skillPath`。
  - `source` 在 `sunfmin/` 下是我的，仓库在 `~/Developments/<repo>`：改 `skillPath` 那个文件 -> commit + push -> `npx skills update`。
  - 其他 `source` 是第三方：不改，报告里写明要改什么。
- **shell**：Bash 工具跑的是 zsh（数组下标从 1 开始），`/bin/bash` 是 3.2；两者都没有 `declare -A`。
- **sudo**：不跑。没有 tty，弹窗批准也出在这台服务器的桌面上，我看不到。要 sudo 的那步绕开它继续，报告里给出完整命令，我自己在这台服务器的终端里跑。
- **Flux**：手动跑（`cargo flux`、`./verify.sh`、`--only-check`……）也带 `FLUXFLAGS="-Ftimings -Ffixpoint-timeout=20 -Fcatch-bugs"`。不带的话一个卡住的 fixpoint 查询能无声跑几十分钟（实测 30+ 分钟、6.5GB）。超时 = 那个函数的 spec / 循环要拆小，不是调大时限。
- **给我看文件**：这台电脑是远程服务器，我不看它的桌面。不用它的任何桌面程序打开文件（`open`、`qlmanage`、Preview、Safari、Finder……）。要给我看的文件（图片、页面、文档……），用 `orca file open <绝对路径> --focus` 在 Orca 里打开；多个文件不带 `--focus` 逐个打开，最后对要先看的那个带 `--focus`。
- **大文件**（模型权重、数据集、release、镜像、视频……）：先查本地缓存（`~/.cache/huggingface`、`~/.cache/modelscope`、下载目录、工具自带缓存），有就用；没有我的同意不下（工具首次运行时的隐式拉取也算），绕开它继续，报告里写明要下什么、多大。

## 设计和改系统

动手前加载 `codebase-design`、`complexity-review`、`single-source-of-truth`，提交前对照检查。

## 给别的 APP 的文本

要我拿去别的 APP 发 / 填的文本（微信、Slack、邮件、表单……）：回复里放进一个代码块给全文，我从那里复制。不用 `pbcopy`：它复制进的是这台服务器的剪贴板，我那边粘贴不到。

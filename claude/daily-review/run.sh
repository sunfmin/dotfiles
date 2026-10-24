#!/usr/bin/env bash
# Review one day of Claude Code work against the principles in CLAUDE.md and
# open a PR on this repo with what to change. Run by launchd each morning
# for the day before; run again for a day it skips one whose PR exists.
#
# The detailed report stays on this machine (this repo is public); the PR
# carries only the abstracted findings and the rule changes.
#
# Usage: run.sh [YYYY-MM-DD]   (default: yesterday)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(git -C "$here" rev-parse --show-toplevel)"
day="${1:-$(date -v-1d +%F)}"
out="$HOME/.local/share/claude-daily-review"
branch="daily-review-$day"
mkdir -p "$out"

echo "$(date '+%F %T') review $day: start"

if [[ -n "$(gh pr list -R sunfmin/dotfiles --head "$branch" --state all --json number -q '.[].number')" ]]; then
  echo "$(date '+%F %T') review $day: PR exists, nothing to do"
  exit 0
fi

digest="$out/$day.digest.md"
"$here/extract.sh" "$day" > "$digest"
echo "$(date '+%F %T') review $day: digest $(wc -c < "$digest") bytes"

# A worktree off origin/main, so the live ~/dotfiles checkout (what
# ~/.claude links to) never changes branch.
wt="$out/worktree"
git -C "$repo" worktree remove --force "$wt" 2>/dev/null || true
base="${REVIEW_BASE:-main}"   # a branch of origin to review against (main; another to try a change)
git -C "$repo" fetch -q origin "$base"
git -C "$repo" worktree add -q -B "$branch" "$wt" "origin/$base"
trap 'git -C "$repo" worktree remove --force "$wt" 2>/dev/null || true' EXIT

prompt="$(sed -e "s|{{DAY}}|$day|g" -e "s|{{DIGEST}}|$digest|g" -e "s|{{PRIVATE}}|$out/$day.md|g" "$here/prompt.md")"

cd "$wt"
timeout 3600 claude -p "$prompt" \
  --add-dir "$out" \
  --allowedTools "Read" "Grep" "Glob" "Edit" "Write" \
    "Bash(git:*)" "Bash(gh:*)" "Bash(rg:*)" "Bash(jq:*)" "Bash(wc:*)" "Bash(ls:*)" "Bash(date:*)"

echo "$(date '+%F %T') review $day: done"

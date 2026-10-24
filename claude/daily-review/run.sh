#!/usr/bin/env bash
# Review one day of Claude Code work against the principles in CLAUDE.md:
# a detailed report on this machine, and, when a rule should change, a PR
# on this repo with the change and the abstracted findings in its body (the
# repo is public). Run by launchd each morning for the day before; run
# again for a day already reviewed (its report or PR exists), it does nothing.
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

if [[ -s "$out/$day.md" ]] \
  || [[ -n "$(gh pr list -R sunfmin/dotfiles --head "$branch" --state all --json number -q '.[].number')" ]]; then
  echo "$(date '+%F %T') review $day: already reviewed, nothing to do"
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

prompt="$(sed -e "s|{{DAY}}|$day|g" -e "s|{{DIGEST}}|$digest|g" -e "s|{{PRIVATE}}|$out/$day.md|g" -e "s|{{BASE}}|$base|g" "$here/prompt.md")"

cd "$wt"
timeout 3600 claude -p "$prompt" \
  --add-dir "$out" \
  --allowedTools "Read" "Grep" "Glob" "Edit" "Write" \
    "Bash(git:*)" "Bash(gh:*)" "Bash(rg:*)" "Bash(jq:*)" "Bash(wc:*)" "Bash(ls:*)" "Bash(date:*)"

echo "$(date '+%F %T') review $day: done"

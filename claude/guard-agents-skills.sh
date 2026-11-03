#!/usr/bin/env bash
# PreToolUse hook on file edits: a skill installed by `npx skills` is never
# edited in place. Its copy (in ~/.claude/skills/<name>/, or ~/.agents/skills/)
# is overwritten by `npx skills update`; the edit belongs in the skill's source,
# which ~/.agents/.skill-lock.json names. Symlinks are resolved first.
set -uo pipefail

input="$(cat)"
path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")"
[ -n "$path" ] || exit 0

# Real path of the nearest existing ancestor, plus the part that doesn't exist yet.
dir="$path" rest=""
while [ ! -e "$dir" ] && [ "$dir" != "/" ]; do
  rest="/$(basename "$dir")$rest"; dir="$(dirname "$dir")"
done
if [ -d "$dir" ]; then real="$(cd "$dir" && pwd -P)$rest"
else real="$(cd "$(dirname "$dir")" && pwd -P)/$(basename "$dir")$rest"; fi

lock="$HOME/.agents/.skill-lock.json"
name=""
for root in "$HOME/.agents/skills" "$HOME/.claude/skills"; do
  [ -d "$root" ] || continue
  r="$(cd "$root" && pwd -P)"
  case "$real" in "$r"/*) name="${real#"$r"/}"; name="${name%%/*}"; break ;; esac
done
[ -n "$name" ] || exit 0
# Under ~/.claude/skills only what npx skills installed is guarded; a skill made there by hand is not.
case "$root" in */.claude/skills) jq -e --arg n "$name" ".skills[\$n]" "$lock" >/dev/null 2>&1 || exit 0 ;; esac
src="$(jq -r --arg n "$name" '.skills[$n] | select(.) | "\(.source) \(.skillPath)"' "$lock" 2>/dev/null)"
if [ -n "$src" ]; then
  repo="${src%% *}" file="${src#* }"
  where="Its source is $repo, file $file."
  case "$repo" in sunfmin/*) where="$where Edit ~/Developments/${repo#*/}/$file, commit + push, then \`npx skills update\`." ;;
    *) where="$where It is third-party: do not change it; say in your record what should change." ;; esac
else
  where="~/.agents/.skill-lock.json does not name it; find where it came from before changing it."
fi

jq -n --arg r "$path is an installed copy of skill \"$name\" that \`npx skills update\` overwrites. $where" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'

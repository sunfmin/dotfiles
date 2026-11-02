#!/usr/bin/env bash
# PreToolUse hook on Bash: a branch with an open pull request is never deleted
# on the remote. Deleting it closes the PR unmerged. Delete a PR's branch only
# after GitHub says the PR is MERGED (`gh pr merge --delete-branch` does both
# in order and is not stopped here).
#
# Catches `git push <remote> --delete|-d <branch>...` and `git push <remote>
# :<branch>`; asks `gh` about each branch in the repo of the command's
# directory. If gh can't answer, the push is let through.
set -uo pipefail

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
case "$cmd" in *"git push"*) ;; *) exit 0 ;; esac

branches=()
# Each `git push ...` segment, up to the next ; & | or newline.
while IFS= read -r seg; do
  # shellcheck disable=SC2206
  words=($seg)
  deleting=
  for w in "${words[@]:2}"; do
    case "$w" in
      --delete | -d) deleting=1 ;;
      -*) ;;
      :*) branches+=("${w#:}") ;;
      *) [ -n "$deleting" ] && branches+=("$w") ;;
    esac
  done
  # The first plain word after the flags is the remote, not a branch.
  if [ -n "$deleting" ] && [ "${#branches[@]}" -gt 0 ]; then
    for w in "${words[@]:2}"; do
      case "$w" in -*) ;; *)
        rest=()
        for b in "${branches[@]}"; do [ "$b" = "$w" ] || rest+=("$b"); done
        branches=("${rest[@]}")
        break ;;
      esac
    done
  fi
done < <(printf '%s\n' "$cmd" | tr ';&|' '\n\n\n' | sed -n 's/.*\(git push .*\)/\1/p')

[ "${#branches[@]}" -gt 0 ] || exit 0
cd "${cwd:-.}" 2>/dev/null || exit 0
open=()
for b in "${branches[@]}"; do
  n="$(gh pr list --head "$b" --state open --json number --jq '.[].number' 2>/dev/null)" || continue
  [ -n "$n" ] && open+=("$b (PR #$n)")
done
[ "${#open[@]}" -gt 0 ] || exit 0
reason="Not deleting: these branches still have an OPEN pull request, and deleting the branch closes it unmerged: ${open[*]}. Check with gh pr view that the PR is MERGED first; then delete (or use gh pr merge --delete-branch)."
jq -nc --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'

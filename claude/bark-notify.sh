#!/usr/bin/env bash
# Push one line to Felix's phone through Bark, the one channel for "Felix must
# decide or act" (CLAUDE.md, 推送通知). The push URL, key included, lives only
# in mytokens as `bark`.
#
#   bark-notify.sh ask      Claude Code PreToolUse hook on AskUserQuestion:
#                           stdin is the hook's JSON. Never blocks the tool;
#                           a failed push is shown as a system message.
#   bark-notify.sh decision afkconvoy --notify-command: stdin is one human
#                           decision ({host, question, answer, url, ...}).
#                           Exits non-zero on failure, so afkconvoy retries.
set -uo pipefail

mode="${1:-}"
input="$(cat)"

case "$mode" in
ask)
  title="$(basename "$(jq -r '.cwd // empty' <<<"$input")")"
  body="$(jq -r '.tool_input.questions[0].question // "Claude is asking you something"' <<<"$input")"
  url=""
  ;;
decision)
  title="afkconvoy $(jq -r '.host // ""' <<<"$input")"
  body="$(jq -r '.question // .condition // "a decision waits for you"' <<<"$input")"
  url="$(jq -r '.url // empty' <<<"$input")"
  ;;
*)
  echo "usage: bark-notify.sh ask|decision < json" >&2
  exit 2
  ;;
esac
body="${body:0:180}"

fail() {
  if [ "$mode" = ask ]; then
    jq -nc --arg m "Bark push failed: $1 — Felix was not notified of this question." '{systemMessage: $m}'
    exit 0
  fi
  echo "bark-notify: $1" >&2
  exit 1
}

bark="$(mytokens get bark 2>&1)" || fail "mytokens get bark: ${bark:0:200}"
args=(--data-urlencode "title=${title:-claude}" --data-urlencode "body=$body")
[ -n "$url" ] && args+=(--data-urlencode "url=$url")
out="$(curl -sS --max-time 10 "$bark" "${args[@]}" 2>&1)" || fail "curl: ${out:0:200}"
jq -e '.code == 200' >/dev/null 2>&1 <<<"$out" || fail "Bark answered: ${out:0:200}"
exit 0

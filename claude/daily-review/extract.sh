#!/usr/bin/env bash
# Print one day's Claude Code sessions as a compact digest: what the user
# said, what Claude said, each tool it called and each tool error, with
# local times. Fleet workers' sessions (afkconvoy copies, orca workspaces)
# are left out: the review is of work done with the user.
#
# Usage: extract.sh YYYY-MM-DD   (a local date)
set -euo pipefail

day="$1"
projects="$HOME/.claude/projects"
since="$(date -j -f %F "$day" +%Y%m%d0000)"
stamp="$(mktemp)"; trap 'rm -f "$stamp"' EXIT
touch -t "$since" "$stamp"

find "$projects" -name '*.jsonl' -newer "$stamp" \
  | rg -v -F -e '-cache-afkconvoy-copies-' -e '-orca-workspaces-' \
  | sort \
  | while read -r f; do
      body="$(jq -r --arg day "$day" '
        def at: .timestamp | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601 | localtime;
        def clip(n): if length > n then .[0:n] + " …" else . end;
        def human: select(startswith("<system-reminder>") or startswith("Caveat:") or startswith("Base directory for this skill") | not);
        select(.timestamp? and (.type == "user" or .type == "assistant"))
        | select((at | strftime("%F")) == $day)
        | (at | strftime("%H:%M")) as $t
        | if .type == "user" then
            if (.message.content | type) == "string" then
              (.message.content | human | "[\($t)] USER: \(clip(1500))")
            else
              .message.content[]?
              | if .type == "text" then (.text | human | "[\($t)] USER: \(clip(1500))")
                elif .type == "tool_result" and .is_error == true then
                  "[\($t)] TOOL ERROR: \(.content | tostring | clip(300))"
                else empty end
            end
          else
            .message.content[]?
            | if .type == "text" then "[\($t)] CLAUDE: \(.text | clip(1500))"
              elif .type == "tool_use" then
                "[\($t)] TOOL \(.name): \((.input.description // .input.command // .input.file_path // (.input | tostring)) | tostring | clip(200))"
              else empty end
          end
      ' "$f" 2>/dev/null || true)"
      if [[ -n "$body" ]]; then
        printf '\n## %s\n\n%s\n' "$(basename "$(dirname "$f")")/$(basename "$f" .jsonl)" "$body"
      fi
    done

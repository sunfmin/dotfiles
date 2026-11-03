#!/usr/bin/env bash
# Converge the live Claude settings onto the keys this repo owns.
#
# claude/settings.mine.json declares only what is ours. Other tools (Orca,
# Claude Code's own /config) write the live ~/.claude/settings.json too, so
# the live file is a plain file, not a symlink, and is never stored here.
#
#   apply  merge mine into live: our keys win, other keys stay; arrays under
#          `permissions` are unioned; a hook of ours replaces any live hook
#          with the same command, so re-running adds nothing
#   check  print each key of ours the live file disagrees with; exit 1 if any
#
# A live file that is still a symlink (the old install) is first turned into
# a plain copy of what it points at, so nothing it holds is lost.
set -euo pipefail

mode="${1:-apply}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mine="$here/settings.mine.json"
live="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

# One jq program, two modes. $m is mine, . is live.
read -r -d '' JQ <<'EOF' || true
def cmds: [.. | objects | .command? // empty];
def merge_hooks($m):
  reduce ($m | to_entries[]) as $e (.;
    ($e.value | cmds) as $ours
    | .[$e.key] = (
        [ (.[$e.key] // [])[]
          | .hooks |= map(select(.command as $c | $ours | index($c) | not))
          | select(.hooks | length > 0) ]
        + $e.value));
def apply($m):
  (. * ($m | del(.hooks, .permissions)))
  | .permissions = (
      (.permissions // {}) as $p
      | $p * ($m.permissions // {})
      | reduce (($m.permissions // {}) | to_entries[] | select(.value | type == "array")) as $a (.;
          .[$a.key] = (reduce (($p[$a.key] // []) + $a.value)[] as $x ([]; if index([$x]) then . else . + [$x] end))))
  | .hooks = ((.hooks // {}) | merge_hooks($m.hooks // {}));
def drift($m):
  . as $l
  | [ ($m | del(.hooks, .permissions) | paths(scalars) ) as $p
      | select(($l | getpath($p)) != ($m | getpath($p)))
      | ($p | map(tostring) | join(".")) ]
  + [ ($m.permissions // {}) | to_entries[] as $e
      | if ($e.value | type) == "array"
        then ($e.value - ($l.permissions[$e.key] // []))[] | "permissions.\($e.key) missing \(.)"
        elif $l.permissions[$e.key] != $e.value then "permissions.\($e.key)"
        else empty end ]
  + [ ($m.hooks // {}) | to_entries[] as $e | $e.value[] as $g | ($g | cmds)[] as $c
      | select([ ($l.hooks[$e.key] // [])[] | select(.matcher == $g.matcher) | cmds[] ] | index($c) | not)
      | "hooks.\($e.key)[\($g.matcher)] missing \($c)" ];
if $mode == "apply" then apply($m) else drift($m)[] end
EOF

if [ -L "$live" ]; then
  tmp="$(mktemp)"; cp -L "$live" "$tmp"; rm "$live"; mv "$tmp" "$live"
  echo "  $live was a symlink; now a plain copy of what it pointed at"
fi
[ -f "$live" ] || echo '{}' > "$live"

case "$mode" in
  apply)
    tmp="$(mktemp)"
    jq --slurpfile mm "$mine" --arg mode apply '$mm[0] as $m | '"$JQ" "$live" > "$tmp"
    mv "$tmp" "$live"
    echo "  merged $(basename "$mine") into $live"
    ;;
  check)
    out="$(jq -r --slurpfile mm "$mine" --arg mode check '$mm[0] as $m | '"$JQ" "$live")"
    if [ -n "$out" ]; then
      echo "Claude settings: live differs from settings.mine.json on keys we own:"
      sed 's/^/  /' <<<"$out"
      exit 1
    fi
    echo "  Claude settings: in step with settings.mine.json"
    ;;
  *) echo "usage: $0 apply|check" >&2; exit 2 ;;
esac

#!/usr/bin/env bash
# Converge this machine's global skills onto skills.txt.
#
# skills.txt is the one list of global skills a machine has: one line per
# source, `<source> <skill>...`, or `<source> *` for every skill the source ships
# (so a skill added upstream arrives with the next run). A new skill goes into
# the list first, then this script installs it; installing by hand leaves the list behind.
#
#   apply  `npx skills add` each source's skills (reinstalling is harmless)
#   check  compare the list with ~/.agents/.skill-lock.json; exit 1 on drift
set -euo pipefail
set -f  # `*` in skills.txt means every skill, never a filename glob

mode="${1:-apply}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
list="$here/skills.txt"
lock="$HOME/.agents/.skill-lock.json"

entries() { grep -v '^[[:space:]]*\(#\|$\)' "$list"; }

# The skills a source ships, as `npx skills add -l` lists them (it has no --json for -l).
available() {
  npx -y skills add "$1" -l </dev/null 2>/dev/null | sed "s/\x1b\[[0-9;?]*[a-zA-Z]//g" \
    | grep -E "^│    [a-z0-9][a-z0-9-]*\$" | sed "s/^│    //"
}

case "$mode" in
  apply)
    entries | while read -r src names; do
      # shellcheck disable=SC2086
      npx -y skills add "$src" -g -y -a claude-code -s $names </dev/null >/dev/null 2>&1 \
        && echo "  installed from $src: $names" \
        || { echo "  FAILED: npx skills add $src -s $names" >&2; exit 1; }
    done
    ;;
  check)
    want="$(entries | while read -r src names; do
      [ "$names" = "*" ] && names="$(available "$src")"
      for n in $names; do echo "$src $n"; done
    done | sort)"
    have="$(jq -r '.skills | to_entries[] | "\(.value.source) \(.key)"' "$lock" 2>/dev/null | sort)"
    missing="$(comm -23 <(echo "$want") <(echo "$have"))"
    extra="$(comm -13 <(echo "$want") <(echo "$have"))"
    [ -z "$missing" ] && [ -z "$extra" ] && { echo "  skills: in step with skills.txt"; exit 0; }
    [ -n "$missing" ] && { echo "skills in skills.txt, not installed:"; sed 's/^/  /' <<<"$missing"; }
    [ -n "$extra" ] && { echo "skills installed, not in skills.txt:"; sed 's/^/  /' <<<"$extra"; }
    exit 1
    ;;
  *) echo "usage: $0 apply|check" >&2; exit 2 ;;
esac

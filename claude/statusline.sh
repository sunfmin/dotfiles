#!/bin/bash
set -f

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ── Colors ──────────────────────────────────────────────
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;175;80m'
cyan='\033[38;2;86;182;194m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
dim='\033[2m'
reset='\033[0m'

sep=" ${dim}│${reset} "

# ── Helpers ─────────────────────────────────────────────
color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "$red"
    elif [ "$pct" -ge 70 ]; then printf "$yellow"
    elif [ "$pct" -ge 50 ]; then printf "$orange"
    else printf "$green"
    fi
}

format_epoch_time() {
    local epoch=$1
    local style=$2
    [ -z "$epoch" ] || [ "$epoch" = "null" ] || [ "$epoch" = "0" ] && return

    local result=""
    case "$style" in
        time)
            result=$(date -j -r "$epoch" +"%l:%M%p" 2>/dev/null)
            [ -z "$result" ] && result=$(date -d "@$epoch" +"%l:%M%P" 2>/dev/null)
            result=$(echo "$result" | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
            ;;
        datetime)
            result=$(date -j -r "$epoch" +"%b %-d, %l:%M%p" 2>/dev/null)
            [ -z "$result" ] && result=$(date -d "@$epoch" +"%b %-d, %l:%M%P" 2>/dev/null)
            result=$(echo "$result" | sed 's/  / /g; s/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
            ;;
        *)
            result=$(date -j -r "$epoch" +"%b %-d" 2>/dev/null)
            [ -z "$result" ] && result=$(date -d "@$epoch" +"%b %-d" 2>/dev/null)
            result=$(echo "$result" | tr '[:upper:]' '[:lower:]')
            ;;
    esac
    printf "%s" "$result"
}

iso_to_epoch() {
    local iso_str="$1"

    local epoch
    epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi

    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"

    if [[ "$iso_str" == *"Z"* ]] || [[ "$iso_str" == *"+00:00"* ]] || [[ "$iso_str" == *"-00:00"* ]]; then
        epoch=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
        [ -z "$epoch" ] && epoch=$(env TZ=UTC date -d "${stripped/T/ }" +%s 2>/dev/null)
    else
        epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
        [ -z "$epoch" ] && epoch=$(date -d "${stripped/T/ }" +%s 2>/dev/null)
    fi

    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi

    return 1
}

# ── Extract JSON data ───────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // "Claude"')

size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
[ "$size" -eq 0 ] 2>/dev/null && size=200000

input_tokens=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
current=$(( input_tokens + cache_create + cache_read ))

if [ "$size" -gt 0 ]; then
    pct_used=$(( current * 100 / size ))
else
    pct_used=0
fi

# ── Line: Model │ Context % │ Directory (branch) │ 5h │ 7d ──
pct_color=$(color_for_pct "$pct_used")
cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)

git_branch=""
git_dirty=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
        git_dirty="*"
    fi
fi

line1="${blue}${model_name}${reset}"
line1+="${sep}"
line1+="◐ ${pct_color}${pct_used}%${reset}"
if [ -n "$git_branch" ]; then
    line1+="${sep}${green}${git_branch}${red}${git_dirty}${reset}"
fi

# ── Rate limits from stdin (primary) ───────────────────
has_stdin_rates=false
five_hour_pct=""
five_hour_reset_epoch=""
seven_day_pct=""
seven_day_reset_epoch=""

stdin_five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$stdin_five_pct" ]; then
    has_stdin_rates=true
    five_hour_pct=$(printf "%.0f" "$stdin_five_pct")
    five_hour_reset_epoch=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
    seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' | awk '{printf "%.0f", $1}')
    seven_day_reset_epoch=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')
fi

# ── Fallback: stablehand's books ───────────────────────
# A session stablehand run started on a setup token gets no rate_limits;
# stablehand statusline (which runs this script via --then) keeps its
# account's books fresh, so show those. No network here.
books_age=""
if ! $has_stdin_rates && [ -n "$STABLEHAND_ACCOUNT" ] && command -v stablehand >/dev/null 2>&1; then
    books=$(stablehand status "$STABLEHAND_ACCOUNT" 2>/dev/null | jq -c '.accounts[0] // empty' 2>/dev/null)
    if [ -n "$books" ]; then
        five_hour_pct=$(echo "$books" | jq -r '.windows[]? | select(.name=="five_hour") | .used_percent // empty' | awk 'NF{printf "%.0f", $1}')
        five_hour_reset_epoch=$(iso_to_epoch "$(echo "$books" | jq -r '.windows[]? | select(.name=="five_hour") | .resets_at // empty')")
        seven_day_pct=$(echo "$books" | jq -r '.windows[]? | select(.name=="seven_day") | .used_percent // empty' | awk 'NF{printf "%.0f", $1}')
        seven_day_reset_epoch=$(iso_to_epoch "$(echo "$books" | jq -r '.windows[]? | select(.name=="seven_day") | .resets_at // empty')")
        read_epoch=$(iso_to_epoch "$(echo "$books" | jq -r '.read_at // empty')")
        if [ -n "$read_epoch" ]; then
            mins=$(( ($(date +%s) - read_epoch) / 60 ))
            [ "$mins" -gt 10 ] && books_age="${dim}(${mins}m ago)${reset}"
        fi
    fi
fi

# ── Rate limits (inline) ────────────────────────────────
line1_rates=""

if [ -n "$five_hour_pct" ]; then
    five_hour_reset=$(format_epoch_time "$five_hour_reset_epoch" "time")
    line1_rates+="${sep}${dim}5h${reset} $(color_for_pct "$five_hour_pct")${five_hour_pct}%${reset}"
    [ -n "$five_hour_reset" ] && line1_rates+="${dim}→${five_hour_reset}${reset}"
fi

if [ -n "$seven_day_pct" ]; then
    seven_day=$(color_for_pct "$seven_day_pct")"${seven_day_pct}%${reset}"
    if [ -n "$seven_day_reset_epoch" ] && [ "$seven_day_reset_epoch" != "null" ]; then
        secs_left=$(( seven_day_reset_epoch - $(date +%s) ))
        if [ "$secs_left" -gt 0 ]; then
            days=$(( secs_left / 86400 )); hours=$(( secs_left % 86400 / 3600 ))
            left=""
            [ "$days" -gt 0 ] && left="${days}d"
            [ "$hours" -gt 0 ] || [ -z "$left" ] && left+="${hours}h"
            seven_day+="${dim}→${reset}${left}"
        fi
    fi
    line1="${dim}7d${reset} ${seven_day}${sep}${line1}"
fi

[ -n "$books_age" ] && line1_rates+=" ${books_age}"
[ -n "$STABLEHAND_ACCOUNT" ] && line1_rates+="${sep}${cyan}${STABLEHAND_ACCOUNT}${reset}"

# ── Output ──────────────────────────────────────────────
printf "%b" "${line1}${line1_rates}"

exit 0

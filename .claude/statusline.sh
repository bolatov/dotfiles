#!/usr/bin/env bash
# Custom Claude Code status line.
# Shows: model | git branch | context usage bar | session cost | session duration | idle time since last activity
#
# Cost and duration come straight from the statusLine payload's `.cost` object
# (`total_cost_usd`, `total_duration_ms`) - no transcript parsing needed for those.
# Idle time (time since the last transcript entry) has no dedicated field, so it is
# derived cheaply by reading only the last line of the transcript (no full-file parse).
# Git branch lookups are cached per working directory for a few seconds to avoid
# spawning `git` on every status line refresh.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.cwd')
transcript=$(echo "$input" | jq -r '.transcript_path')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
BLUE='\033[34m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
GRAY='\033[90m'
DIM='\033[2m'
SEP="${GRAY} | ${RESET}"

# --- Git branch (cached, TTL in seconds, to avoid spawning git on every refresh) ---
GIT_CACHE_TTL=5
cache_dir="$HOME/.claude/.cache/statusline"
mkdir -p "$cache_dir" 2>/dev/null
cache_file="$cache_dir/branch_${cwd//\//_}"
now_epoch=$(date +%s)

branch=""
cache_fresh=""
if [ -f "$cache_file" ]; then
  cache_mtime=$(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file" 2>/dev/null)
  if [ -n "$cache_mtime" ] && [ $(( now_epoch - cache_mtime )) -lt "$GIT_CACHE_TTL" ]; then
    branch=$(cat "$cache_file")
    cache_fresh=1
  fi
fi
if [ -z "$cache_fresh" ]; then
  branch=""
  if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  fi
  printf '%s' "$branch" > "$cache_file" 2>/dev/null
fi

# --- PR/MR indicator, shown inline next to the branch (only when a PR exists for it) ---
pr_number=$(echo "$input" | jq -r '.pr.number // empty')
pr_url=$(echo "$input" | jq -r '.pr.url // empty')
pr_state=$(echo "$input" | jq -r '.pr.review_state // empty')
pr_kind=$(echo "$input" | jq -r '.pr.kind // empty')

pr_seg=""
if [ -n "$pr_number" ] && [ -n "$pr_url" ]; then
  case "$pr_state" in
    approved) prcolor="$GREEN" ;;
    changes_requested) prcolor="$RED" ;;
    pending) prcolor="$YELLOW" ;;
    draft) prcolor="$GRAY" ;;
    *) prcolor="$DIM" ;;
  esac
  if [ "$pr_kind" = "mr" ]; then prlabel="MR !${pr_number}"; else prlabel="PR #${pr_number}"; fi
  pr_seg="${prcolor}\033]8;;${pr_url}\a${prlabel}\033]8;;\a${RESET}"
fi

ctx_seg=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  pct=$(printf '%.0f' "$used_pct")
  filled=$(( pct / 10 ))
  if [ "$filled" -gt 10 ]; then filled=10; fi
  if [ "$filled" -lt 0 ]; then filled=0; fi
  empty=$(( 10 - filled ))
  if [ "$pct" -ge 80 ]; then ctxcolor="$RED"
  elif [ "$pct" -ge 50 ]; then ctxcolor="$YELLOW"
  else ctxcolor="$GREEN"
  fi
  bar=$(printf '%*s' "$filled" '' | tr ' ' '█')$(printf '%*s' "$empty" '' | tr ' ' '░')
  ctx_seg="${ctxcolor}ctx ${bar} ${pct}%${RESET}"
fi

# --- Session cost & duration, straight from the payload's .cost object ---
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
dur_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')

cost_seg=""
if [ -n "$cost_usd" ]; then
  cost_fmt=$(printf '%.2f' "$cost_usd" 2>/dev/null)
  if [ -n "$cost_fmt" ]; then cost_seg="${DIM}\$${cost_fmt}${RESET}"; fi
fi

dur_seg=""
if [ -n "$dur_ms" ]; then
  dur_s=$(( dur_ms / 1000 ))
  dh=$(( dur_s / 3600 ))
  dm=$(( (dur_s % 3600) / 60 ))
  if [ "$dh" -gt 0 ]; then durfmt="${dh}h${dm}m"; else durfmt="${dm}m"; fi
  dur_seg="${DIM}${durfmt}${RESET}"
fi

# --- Idle time since last transcript activity (only the last line is read, cheap even on huge transcripts) ---
idle_seg=""
if [ -f "$transcript" ]; then
  last_ts=$(tail -n 1 "$transcript" 2>/dev/null | jq -r '
    (.timestamp // empty) as $t
    | if $t == "" then empty else ($t | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) end
  ' 2>/dev/null)
  if [ -n "$last_ts" ]; then
    now=$(date +%s)
    idle=$(( now - last_ts ))
    im=$(( idle / 60 ))
    is=$(( idle % 60 ))
    if [ "$idle" -ge 300 ]; then
      idlecolor="$RED"
      # Prompt cache TTL (5m) has lapsed: the cached prefix (cache read + cache write
      # tokens from the last turn) would be billed as fresh input on the next message.
      stale_tokens=$(echo "$input" | jq -r '
        ((.context_window.current_usage.cache_read_input_tokens // 0)
         + (.context_window.current_usage.cache_creation_input_tokens // 0))
      ' 2>/dev/null)
      if [ -n "$stale_tokens" ] && [ "$stale_tokens" -gt 0 ] 2>/dev/null; then
        stale_fmt=$(awk -v t="$stale_tokens" 'BEGIN { printf (t >= 1000) ? "%.1fk" : "%d", (t >= 1000 ? t/1000 : t) }')
        idle_seg="${idlecolor}wait ${im}m${is}s (${stale_fmt} tok stale)${RESET}"
      fi
    else
      idlecolor="$GREEN"
    fi
    if [ -z "$idle_seg" ]; then idle_seg="${idlecolor}wait ${im}m${is}s${RESET}"; fi
  fi
fi

parts="${BOLD}${CYAN}${model}${RESET}"
if [ -n "$branch" ]; then
  parts="${parts}${SEP}${BLUE}${branch}${RESET}"
  if [ -n "$pr_seg" ]; then parts="${parts} ${pr_seg}"; fi
fi
if [ -n "$ctx_seg" ]; then parts="${parts}${SEP}${ctx_seg}"; fi
if [ -n "$cost_seg" ]; then parts="${parts}${SEP}${cost_seg}"; fi
if [ -n "$dur_seg" ]; then parts="${parts}${SEP}${dur_seg}"; fi
if [ -n "$idle_seg" ]; then parts="${parts}${SEP}${idle_seg}"; fi

printf "%b\n" "$parts"
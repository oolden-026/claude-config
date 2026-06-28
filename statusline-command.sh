#!/bin/bash
input=$(cat)
echo "$input" > /tmp/statusline-debug.json

MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
RL_5H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0' | cut -d. -f1)
RL_5H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0' | cut -d. -f1)
RL_7D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0' | cut -d. -f1)
RL_7D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0' | cut -d. -f1)
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty')

CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; PURPLE='\033[35m'; RESET='\033[0m'

# Context bar
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi
FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" || FILL=""
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" || PAD=""
BAR="${FILL// /█}${PAD// /░}"

MINS=$((DURATION_MS / 60000)); SECS=$(((DURATION_MS % 60000) / 1000))

BRANCH=""
if [ -n "$DIR" ]; then
  BRANCH=$(GIT_OPTIONAL_LOCKS=0 git -C "$DIR" symbolic-ref --short HEAD 2>/dev/null)
  [ -n "$BRANCH" ] && BRANCH=" | 🌿 $BRANCH"
fi
DIRNAME="${DIR##*[/\\]}"

# Rate limit bars (8 chars each)
make_bar() {
  local pct=$1 filled empty f="" e=""
  filled=$(( pct * 8 / 100 ))
  [ "$pct" -gt 0 ] && [ "$filled" -eq 0 ] && filled=1
  empty=$(( 8 - filled ))
  [ "$filled" -gt 0 ] && printf -v f "%${filled}s" && f="${f// /█}"
  [ "$empty"  -gt 0 ] && printf -v e "%${empty}s"  && e="${e// /░}"
  echo "${f}${e}"
}
bar_color() {
  if [ "$1" -ge 90 ]; then echo "$RED"
  elif [ "$1" -ge 70 ]; then echo "$YELLOW"
  else echo "$GREEN"; fi
}

fmt_remaining() {
  local ts=$1 now diff h m d
  now=$(date +%s 2>/dev/null || echo 0)
  diff=$(( ts - now ))
  if [ "$diff" -le 0 ]; then echo "now"; return; fi
  h=$(( diff / 3600 )); m=$(( (diff % 3600) / 60 ))
  if [ "$h" -ge 24 ]; then d=$(( h / 24 )); echo "${d}d $((h % 24))h"
  elif [ "$h" -gt 0 ]; then echo "${h}h ${m}m"
  else echo "${m}m"; fi
}
FMT_5H=$(fmt_remaining "$RL_5H_RESET")
FMT_7D=$(fmt_remaining "$RL_7D_RESET")

BAR_5H=$(make_bar "$RL_5H_PCT")
BAR_7D=$(make_bar "$RL_7D_PCT")
COL_5H=$(bar_color "$RL_5H_PCT")
COL_7D=$(bar_color "$RL_7D_PCT")

# Week cost from JSONL logs
WEEK_COST=$(python3 "$HOME/.claude/usage-stats.py" --session "$SESSION_ID" 2>/dev/null | grep WEEK_COST | cut -d= -f2)
WEEK_FMT=$(printf '$%.2f' "${WEEK_COST:-0}")

# ── Output ──────────────────────────────────────────────────────────────
echo -e "${CYAN}[$MODEL]${RESET} 📁 ${DIRNAME}${BRANCH}"
COST_FMT=$(printf '$%.2f' "$COST")
echo -e "${BAR_COLOR}${BAR}${RESET} ctx: ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${MINS}m ${SECS}s"
echo -e "5h ${COL_5H}${BAR_5H}${RESET} ${RL_5H_PCT}% → ${FMT_5H} | 7d ${COL_7D}${BAR_7D}${RESET} ${RL_7D_PCT}% → ${FMT_7D} | wk: ${YELLOW}${WEEK_FMT}${RESET}"

JOBS_DIR="$HOME/.claude/jobs"
AGENT_COUNT=0
AGENT_NAMES_LIST=""
if [ -d "$JOBS_DIR" ]; then
  for state_file in "$JOBS_DIR"/*/state.json; do
    [ -f "$state_file" ] || continue
    JOB_STATE=$(jq -r '.state // ""' "$state_file" 2>/dev/null)
    JOB_NAME=$(jq -r '.name // "unnamed"' "$state_file" 2>/dev/null)
    if [ "$JOB_STATE" = "working" ] || [ "$JOB_STATE" = "idle" ]; then
      AGENT_COUNT=$((AGENT_COUNT + 1))
      [ -n "$AGENT_NAMES_LIST" ] && AGENT_NAMES_LIST="$AGENT_NAMES_LIST · $JOB_NAME" || AGENT_NAMES_LIST="$JOB_NAME"
    fi
  done
fi

if [ "$AGENT_COUNT" -gt 0 ]; then
  echo -e "${PURPLE}🤖 ${AGENT_COUNT} agent(s):${RESET} ${AGENT_NAMES_LIST}"
else
  echo -e "💤 no active agents"
fi

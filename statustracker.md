Claude Code Custom Statusline
A 4-line statusline for Claude Code showing model/context, rate limit bars, active agents, and rolling week cost.

[Sonnet 4.6] 📁 GrasshopperScripts | 🌿 master
███░░░░░░░ ctx: 30% | $0.84 | ⏱️ 68m 36s
5h █████░░░ 64% → 11:40 | 7d █░░░░░░░ 10% → Jun 21 | wk: $21.73
🤖 1 agent(s): Fix statusline display
Line 1 — model, working directory, git branch
Line 2 — context window bar, session cost, session duration
Line 3 — 5-hour and 7-day rate limit bars with reset times (matches /usage), plus rolling 7-day cost
Line 4 — active background agents with their names, or 💤 when none
Bars turn yellow at 70% and red at 90%.

Prerequisites
Claude Code installed
jq — JSON processor used by the bash script
python3 — used for timestamp formatting and cost calculation
Install jq on Windows (winget):

winget install jqlang.jq
Install jq on macOS:

brew install jq
Setup
1. Create the bash script
Save this file as ~/.claude/statusline-command.sh:

#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
RL_5H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // 0')
RL_5H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0')
RL_7D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // 0')
RL_7D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // 0')
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

RESET_FMTS=$(python3 - "$RL_5H_RESET" "$RL_7D_RESET" <<'PYEOF' 2>/dev/null
import sys
from datetime import datetime, timezone, timedelta
import time
t5, t7 = int(sys.argv[1]), int(sys.argv[2])
offset = datetime.fromtimestamp(0) - datetime.utcfromtimestamp(0)
tz = timezone(offset)
d5 = datetime.fromtimestamp(t5, tz).strftime('%H:%M')
d7 = datetime.fromtimestamp(t7, tz)
d7s = d7.strftime('%b') + ' ' + str(d7.day)
print(d5 + '|' + d7s)
PYEOF
)
FMT_5H=$(echo "$RESET_FMTS" | cut -d'|' -f1)
FMT_7D=$(echo "$RESET_FMTS" | cut -d'|' -f2)

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
Make it executable:

chmod +x ~/.claude/statusline-command.sh
2. Create the Python cost helper
Save this file as ~/.claude/usage-stats.py:

#!/usr/bin/env python3
"""Compute 7-day rolling cost from Claude Code JSONL logs."""
import sys, json, os, glob
from datetime import datetime, timezone, timedelta

PRICING = {
    # model-prefix → (input, output, cache_read, cache_write) per million tokens
    "claude-sonnet-4": (3.0, 15.0, 0.30, 3.75),
    "claude-opus-4":   (15.0, 75.0, 1.50, 18.75),
    "claude-haiku-4":  (0.8,  4.0,  0.08, 1.00),
}

def get_pricing(model):
    for prefix, rates in PRICING.items():
        if model and model.startswith(prefix):
            return rates
    return (3.0, 15.0, 0.30, 3.75)  # default sonnet

def calc_cost(usage, model=""):
    pi, po, pr, pw = get_pricing(model)
    it = usage.get("input_tokens", 0)
    ot = usage.get("output_tokens", 0)
    cr = usage.get("cache_read_input_tokens", 0)
    cc = usage.get("cache_creation_input_tokens", 0)
    return (it * pi + ot * po + cr * pr + cc * pw) / 1_000_000

session_id = None
if len(sys.argv) > 2 and sys.argv[1] == "--session":
    session_id = sys.argv[2]

base = os.path.expanduser("~/.claude/projects")
now = datetime.now(timezone.utc)
week_ago = now - timedelta(days=7)

session_in = session_out = session_cache_r = 0
week_cost = 0.0

for fpath in glob.glob(f"{base}/**/*.jsonl", recursive=True):
    # Skip files not touched in the last 7 days (fast path)
    try:
        if os.path.getmtime(fpath) < week_ago.timestamp():
            continue
    except OSError:
        continue
    is_session = session_id and os.path.basename(fpath) == f"{session_id}.jsonl"
    try:
        with open(fpath, encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    d = json.loads(line)
                    if d.get("type") != "assistant":
                        continue
                    ts = d.get("timestamp", "")
                    if not ts:
                        continue
                    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    if dt < week_ago:
                        continue
                    msg = d.get("message", {})
                    usage = msg.get("usage", {})
                    if not usage:
                        continue
                    week_cost += calc_cost(usage, msg.get("model", ""))
                    if is_session:
                        session_in += usage.get("input_tokens", 0)
                        session_out += usage.get("output_tokens", 0)
                        session_cache_r += usage.get("cache_read_input_tokens", 0)
                except Exception:
                    pass
    except Exception:
        pass

print(f"SESSION_IN={session_in}")
print(f"SESSION_OUT={session_out}")
print(f"SESSION_CACHE_R={session_cache_r}")
print(f"WEEK_COST={week_cost:.4f}")
3. Enable the statusline in Claude Code settings
Add this to ~/.claude/settings.json (merge with any existing content):

{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
The file lives at: - Windows: C:\Users\<you>\.claude\settings.json - macOS/Linux: ~/.claude/settings.json

Notes on the week cost
The week cost is calculated by reading Claude Code's local conversation logs (~/.claude/projects/**/*.jsonl) and multiplying token counts by the published API prices. Files older than 7 days are skipped for speed. The pricing table in usage-stats.py covers Sonnet 4, Opus 4, and Haiku 4 — update it if you use other models or if prices change.

The rate limit bars (5h / 7d) come directly from Claude Code's own JSON data and will always match what /usage shows.
#!/usr/bin/env bash
# ============================================================
#  AIMeter — Interactive Demo / Preview Launcher
#  Run:  bash demo.sh
# ============================================================
set -euo pipefail

# ── Colour helpers ──────────────────────────────────────────
bold='\033[1m'; cyan='\033[0;36m'; green='\033[0;32m'
orange='\033[0;33m'; red='\033[0;31m'; reset='\033[0m'

echo ""
echo -e "${bold}${cyan}╔══════════════════════════════════════╗${reset}"
echo -e "${bold}${cyan}║     AIMeter  ·  Demo Mode Launcher   ║${reset}"
echo -e "${bold}${cyan}╚══════════════════════════════════════╝${reset}"
echo ""

# ── Find the binary ─────────────────────────────────────────
BINARY=""

# 1. Installed app
if [ -f "/Applications/AIMeter.app/Contents/MacOS/AIMeter" ]; then
    BINARY="/Applications/AIMeter.app/Contents/MacOS/AIMeter"
fi

# 2. Xcode DerivedData (Debug build)
if [ -z "$BINARY" ]; then
    BINARY=$(find ~/Library/Developer/Xcode/DerivedData \
        -name "AIMeter" -type f \
        -path "*/Debug/AIMeter" 2>/dev/null | head -1 || true)
fi

# 3. Local build/ folder produced by `make build` or xcodebuild with CONFIGURATION_BUILD_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "$BINARY" ] && [ -f "$SCRIPT_DIR/build/AIMeter.app/Contents/MacOS/AIMeter" ]; then
    BINARY="$SCRIPT_DIR/build/AIMeter.app/Contents/MacOS/AIMeter"
fi
# 4. Flat binary (older builds)
if [ -z "$BINARY" ] && [ -f "$SCRIPT_DIR/build/AIMeter" ]; then
    BINARY="$SCRIPT_DIR/build/AIMeter"
fi

if [ -z "$BINARY" ]; then
    echo -e "${red}Error:${reset} AIMeter binary not found."
    echo ""
    echo "  • Build the project in Xcode first (⌘B)"
    echo "  • Or install the app to /Applications"
    exit 1
fi

echo -e "Binary: ${cyan}$BINARY${reset}"
echo ""

# ── Which providers? ─────────────────────────────────────────
echo -e "${bold}Which providers do you want to test?${reset}"
echo "  1) Both Cursor and Claude"
echo "  2) Cursor only"
echo "  3) Claude only"
echo ""
read -rp "Choice [1-3, default=1]: " PROVIDER_CHOICE
PROVIDER_CHOICE=${PROVIDER_CHOICE:-1}

# Validate
if [[ ! "$PROVIDER_CHOICE" =~ ^[1-3]$ ]]; then
    echo -e "${red}Invalid choice.${reset}" && exit 1
fi

ARGS="--demo"

# ── Cursor setup ─────────────────────────────────────────────
if [[ "$PROVIDER_CHOICE" == "1" || "$PROVIDER_CHOICE" == "2" ]]; then
    echo ""
    echo -e "${bold}─── Cursor ───────────────────────────────${reset}"

    read -rp "Token consumption % (0-100) [default: 67]: " CURSOR_PCT
    CURSOR_PCT=${CURSOR_PCT:-67}
    if ! [[ "$CURSOR_PCT" =~ ^[0-9]+([.][0-9]+)?$ ]] || (( $(echo "$CURSOR_PCT > 100" | bc -l) )); then
        echo -e "${red}Invalid percentage.${reset}" && exit 1
    fi

    read -rp "Plan label [default: 'Included in Pro+']: " CURSOR_PLAN
    CURSOR_PLAN=${CURSOR_PLAN:-"Included in Pro+"}

    ARGS="$ARGS --cursor-percent $CURSOR_PCT --cursor-plan \"$CURSOR_PLAN\""

    # Show colour hint
    if (( $(echo "$CURSOR_PCT >= 86" | bc -l) )); then
        echo -e "  → ${red}Red zone${reset} (≥86%)"
    elif (( $(echo "$CURSOR_PCT >= 61" | bc -l) )); then
        echo -e "  → ${orange}Orange zone${reset} (61–85%)"
    else
        echo -e "  → ${green}Green zone${reset} (≤60%)"
    fi
fi

# ── Claude setup ─────────────────────────────────────────────
if [[ "$PROVIDER_CHOICE" == "1" || "$PROVIDER_CHOICE" == "3" ]]; then
    echo ""
    echo -e "${bold}─── Claude ───────────────────────────────${reset}"

    read -rp "Token consumption % (0-100) [default: 82]: " CLAUDE_PCT
    CLAUDE_PCT=${CLAUDE_PCT:-82}
    if ! [[ "$CLAUDE_PCT" =~ ^[0-9]+([.][0-9]+)?$ ]] || (( $(echo "$CLAUDE_PCT > 100" | bc -l) )); then
        echo -e "${red}Invalid percentage.${reset}" && exit 1
    fi

    read -rp "Plan label [default: 'Claude Pro']: " CLAUDE_PLAN
    CLAUDE_PLAN=${CLAUDE_PLAN:-"Claude Pro"}

    ARGS="$ARGS --claude-percent $CLAUDE_PCT --claude-plan \"$CLAUDE_PLAN\""

    if (( $(echo "$CLAUDE_PCT >= 86" | bc -l) )); then
        echo -e "  → ${red}Red zone${reset} (≥86%)"
    elif (( $(echo "$CLAUDE_PCT >= 61" | bc -l) )); then
        echo -e "  → ${orange}Orange zone${reset} (61–85%)"
    else
        echo -e "  → ${green}Green zone${reset} (≤60%)"
    fi
fi

# ── Provider isolation flags ─────────────────────────────────
if [[ "$PROVIDER_CHOICE" == "2" ]]; then
    ARGS="$ARGS --cursor-only"
elif [[ "$PROVIDER_CHOICE" == "3" ]]; then
    ARGS="$ARGS --claude-only"
fi

# ── Kill existing instance ────────────────────────────────────
echo ""
if pgrep -x "AIMeter" > /dev/null 2>&1; then
    echo -e "${orange}Stopping existing AIMeter instance...${reset}"
    pkill -x "AIMeter" || true
    sleep 0.5
fi

# ── Launch ───────────────────────────────────────────────────
echo -e "${bold}${green}Launching AIMeter in demo mode...${reset}"
echo -e "  Args: ${cyan}$ARGS${reset}"
echo ""

eval "\"$BINARY\" $ARGS" &

echo -e "${green}Done!${reset} Click the AIMeter icon in your menu bar."
echo ""

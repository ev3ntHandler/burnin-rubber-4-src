#!/bin/sh
# Compile the project with the actual Godot 4 editor, run the addon self-test and smoke-test
# the demo. Godot can print script errors but exit 0, so also check its output explicitly.
set -eu
GODOT_BIN=${GODOT_BIN:-godot}
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../godot" && pwd)
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT HUP INT TERM

run_godot() {
    echo "+ $GODOT_BIN $*"
    if ! "$GODOT_BIN" --headless --path "$ROOT" "$@" >"$LOG" 2>&1; then
        cat "$LOG"
        return 1
    fi
    cat "$LOG"
    if grep -E '(^|[[:space:]])(SCRIPT ERROR|ERROR):' "$LOG" >/dev/null; then
        return 1
    fi
}

# The initial editor scan builds Godot's global class cache and compiles the editor plugin too.
run_godot --editor --quit
run_godot --script res://addons/shockwave_bridge/bridge_selftest.gd
run_godot --quit-after 5
if ! grep -F '[bridge demo] bridge bound as gd:Demo' "$LOG" >/dev/null; then
    echo 'Demo did not bind to the ShockwaveBridge autoload.' >&2
    exit 1
fi

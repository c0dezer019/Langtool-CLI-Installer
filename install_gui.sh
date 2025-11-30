#!/usr/bin/env bash

# GUI installer entry point
# Automatically detects and uses best available UI backend (GTK > TUI > CLI)

[ -n "$LANGTOOL_DEBUG" ] && set -x

# Suppress harmless GTK module warnings
export GTK_MODULES=""

# Change to script directory
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# shellcheck disable=SC1091
source "./lib/ui_abstraction.sh"
# shellcheck disable=SC1091
source "./lib/install_state.sh"

# Initialize state
init_state

# Cleanup on exit
trap 'clear_state' EXIT INT TERM

# Detect UI backend if not explicitly set
if [ "$UI_BACKEND" = "auto" ] || [ -z "$UI_BACKEND" ]; then
    UI_BACKEND=$(detect_ui_backend)
fi

# Launch appropriate installer
case "$UI_BACKEND" in
    gtk)
        # GTK wizard (prefer system Python for GTK bindings)
        PYTHON_CMD="/usr/bin/python3"
        [ -x "$PYTHON_CMD" ] || PYTHON_CMD="python3"
        "$PYTHON_CMD" "$(dirname "$0")/lib/install_gtk_wizard.py"
        exit $?
        ;;
    tui)
        # TUI fallback
        exec ./install_gui_tui.sh
        ;;
    cli|*)
        # CLI fallback
        exec ./install.sh
        ;;
esac

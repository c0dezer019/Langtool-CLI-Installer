#!/bin/bash
#
# GTK Backend Wrapper
# Provides bash interface to the Python GTK wizard

# Prevent multiple sourcing
[ -n "$_UI_GTK_LOADED" ] && return
readonly _UI_GTK_LOADED=1

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Run the GTK wizard
ui_run_wizard() {
    local wizard_script="$SCRIPT_DIR/install_gtk_wizard.py"

    if [ ! -f "$wizard_script" ]; then
        echo "Error: GTK wizard script not found: $wizard_script" >&2
        return 1
    fi

    # Ensure script is executable
    if [ ! -x "$wizard_script" ]; then
        chmod +x "$wizard_script" 2>/dev/null || true
    fi

    # Launch Python wizard
    python3 "$wizard_script"
    return $?
}

# Show a simple message dialog (for errors, warnings, etc.)
ui_show_message() {
    local message_type="$1"  # info, warning, error
    local title="$2"
    local message="$3"

    python3 -c "
import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk
import sys

message_types = {
    'info': Gtk.MessageType.INFO,
    'warning': Gtk.MessageType.WARNING,
    'error': Gtk.MessageType.ERROR
}

dialog = Gtk.MessageDialog(
    modal=True,
    message_type=message_types.get('${message_type}', Gtk.MessageType.INFO),
    buttons=Gtk.ButtonsType.OK,
    text='${title}'
)
dialog.format_secondary_text('${message}')
dialog.run()
dialog.destroy()
" 2>/dev/null
}

# Show error message
ui_error() {
    local message="$1"
    ui_show_message "error" "Error" "$message"
}

# Show warning message
ui_warning() {
    local message="$1"
    ui_show_message "warning" "Warning" "$message"
}

# Show info message
ui_info() {
    local message="$1"
    ui_show_message "info" "Information" "$message"
}

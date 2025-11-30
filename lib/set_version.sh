#!/bin/bash

# Source the version selector library
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/version_selector.sh"

set_version() {
    ui_log step "Configuring LanguageTool version"

    if ui_confirm "Would you like to select a specific LanguageTool version?" "n"; then
        # Use the GUI version selector from version_selector.sh
        set_version_gui
    else
        export LT_VER="latest"
        update_shell_rc "LT_VER" "latest"
        ui_log info "Using latest LanguageTool version"
    fi
}

#!/bin/bash

# Source the version selector library
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/version_selector.sh"

set_version() {
    local lt_sp_ver

    log_step "Configuring LanguageTool version"
    read -rp "Would you like to select a specific LanguageTool version? [y/n](n): " lt_sp_ver

    case "${lt_sp_ver,,}" in
        "y" | "yes")
            # Use the GUI version selector from version_selector.sh
            set_version_gui
            ;;
        "" | "n" | "no")
            export LT_VER="latest"
            update_shell_rc "LT_VER" "latest"
            log_info "Using latest LanguageTool version"
            ;;
        *)
            log_warn "Only y[es] or n[o] is accepted as valid arguments."
            set_version
            ;;
    esac
}

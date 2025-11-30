#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/log_step.sh"

failed_clone() {
    ui_log error "Failed to git clone $1"
    exit 1
}

install_cli() {
    local updated=false

    ui_log step "Installing Langtool CLI"
    ui_log info "Target directory: $2"

    if [ -d "$2" ]; then
        ui_log info "Previous installation found, updating..."

        if ! rm -rf "$2" >/dev/null 2>&1; then
            sudo rm -rf "$2"
        fi

        updated=true
    fi

    git -c advice.detachedHead=0 -c core.autocrlf=false clone --branch "$3" \
            --depth 1 "$1" "$2" >/dev/null 2>&1 || failed_clone "$1"

    ui_log success "Repository cloned successfully"
    export LT_CLI_UPDATED="$updated"
}

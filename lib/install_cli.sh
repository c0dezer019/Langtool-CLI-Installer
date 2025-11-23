#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/log_step.sh"

failed_clone() {
    log_error "Failed to git clone $1"
    exit 1
}

install_cli() {
    local updated=false

    log_step "Installing Langtool CLI"
    log_info "Target directory: $2"

    if [ -d "$2" ]; then
        log_info "Previous installation found, updating..."

        if ! rm -rf "$2" >/dev/null 2>&1; then
            sudo rm -rf "$2"
        fi

        updated=true
    fi

    git -c advice.detachedHead=0 -c core.autocrlf=false clone --branch "$3" \
            --depth 1 "$1" "$2" >/dev/null 2>&1 || failed_clone "$1"

    log_success "Repository cloned successfully"
    export LT_CLI_UPDATED="$updated"
}

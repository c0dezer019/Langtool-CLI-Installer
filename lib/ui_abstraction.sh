#!/bin/bash

# Prevent multiple sourcing
[ -n "$_UI_ABSTRACTION_LOADED" ] && return
readonly _UI_ABSTRACTION_LOADED=1

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/log_step.sh"

# UI backend (yad, tui, or cli)
UI_BACKEND="${UI_BACKEND:-auto}"

# Validate YAD backend availability
validate_yad_backend() {
    command -v yad &>/dev/null || return 1
    [ -n "$DISPLAY" ] || return 1
    # Don't check yad --version as it may fail with GTK warnings
    # but still be functional. Just check command exists and DISPLAY is set.
    return 0
}

# Validate TUI backend availability (whiptail or dialog)
validate_tui_backend() {
    command -v whiptail &>/dev/null && return 0
    command -v dialog &>/dev/null && return 0
    return 1
}

# Auto-detect best available UI backend
detect_ui_backend() {
    # Check for explicit disable flags
    if [ -n "$FORCE_CLI" ] || [ -n "$NO_GUI" ]; then
        if [ -n "$NO_GUI" ] && validate_tui_backend; then
            echo "tui"
        else
            echo "cli"
        fi
        return
    fi

    # Auto-detect priority: YAD > TUI > CLI
    if validate_yad_backend; then
        echo "yad"
    elif validate_tui_backend; then
        echo "tui"
    else
        echo "cli"
    fi
}

# Source the appropriate backend implementation
source_backend() {
    local backend="$1"

    case "$backend" in
        yad)
            # shellcheck disable=SC1091
            source "$SCRIPT_DIR/ui_yad.sh"
            ;;
        tui)
            # shellcheck disable=SC1091
            source "$SCRIPT_DIR/ui_tui.sh"
            ;;
        cli)
            # shellcheck disable=SC1091
            source "$SCRIPT_DIR/ui_cli.sh"
            ;;
        *)
            echo "Error: Invalid UI backend: $backend" >&2
            echo "Valid backends: yad, tui, cli" >&2
            exit 1
            ;;
    esac
}

# Initialize UI subsystem
ui_init() {
    local requested_backend="${UI_BACKEND}"
    local detected_backend

    if [ "$requested_backend" = "auto" ]; then
        detected_backend=$(detect_ui_backend)
    else
        detected_backend="$requested_backend"
    fi

    # Validate requested backend and fallback if needed
    case "$detected_backend" in
        yad)
            if ! validate_yad_backend; then
                log_warn "YAD requested but unavailable, falling back to TUI"
                detected_backend="tui"
            fi
            ;;
        tui)
            if ! validate_tui_backend; then
                log_warn "TUI requested but unavailable, falling back to CLI"
                detected_backend="cli"
            fi
            ;;
        cli)
            # Always available
            ;;
        *)
            log_error "Invalid UI backend: $detected_backend"
            detected_backend="cli"
            ;;
    esac

    # Additional fallback check for TUI
    if [ "$detected_backend" = "tui" ] && ! validate_tui_backend; then
        log_warn "TUI unavailable, falling back to CLI"
        detected_backend="cli"
    fi

    export UI_BACKEND="$detected_backend"
    source_backend "$detected_backend"

    if [ -n "$LANGTOOL_DEBUG" ]; then
        log_info "Using UI backend: $UI_BACKEND"
    fi
}

# Initialize UI on source
ui_init

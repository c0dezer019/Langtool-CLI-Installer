#!/bin/bash

# Prevent multiple sourcing
[ -n "$_UI_CLI_LOADED" ] && return
readonly _UI_CLI_LOADED=1

# CLI Backend Implementation
# Uses existing log_step.sh functions and read -rp for prompts

# Display a message to the user
ui_show_message() {
    local title="$1"
    local message="$2"
    log_info "$message"
}

# Display an error to the user
ui_show_error() {
    local title="$1"
    local message="$2"
    log_error "$message"
}

# Display a warning to the user
ui_show_warning() {
    local title="$1"
    local message="$2"
    log_warn "$message"
}

# Display a success message
ui_show_success() {
    local title="$1"
    local message="$2"
    log_success "$message"
}

# Prompt for text input
ui_prompt_text() {
    local prompt="$1"
    local default="$2"
    local result

    read -rp "$prompt ($default): " result
    echo "${result:-$default}"
}

# Prompt for directory path
ui_prompt_dir() {
    local prompt="$1"
    local default="$2"
    local result

    read -rp "$prompt ($default): " result
    echo "${result:-$default}"
}

# Prompt for yes/no confirmation
ui_confirm() {
    local prompt="$1"
    local default="$2"
    local result

    while true; do
        read -rp "$prompt [y/n] ($default): " result
        result="${result:-$default}"
        result="${result,,}"  # Convert to lowercase

        case "$result" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) log_warn "Please answer 'y' or 'n'" ;;
        esac
    done
}

# Prompt for choice from list
ui_prompt_choice() {
    local prompt="$1"
    local -a choices=("${@:2}")
    local choice

    echo "$prompt"
    PS3="Enter selection number: "
    select choice in "${choices[@]}"; do
        if [ -n "$choice" ]; then
            echo "$choice"
            return 0
        else
            log_warn "Invalid selection. Please try again."
        fi
    done
}

# Start progress indication
ui_progress_start() {
    local title="$1"
    local message="$2"
    log_step "$message"
}

# Update progress
ui_progress_update() {
    local percentage="$1"
    local message="$2"

    if [ -n "$message" ]; then
        printf '\r  [%3d%%] %s' "$percentage" "$message"
    else
        printf '\r  [%3d%%]' "$percentage"
    fi
}

# End progress indication
ui_progress_end() {
    local success="$1"
    local message="$2"

    printf '\n'

    if [ "$success" = "true" ]; then
        log_success "${message:-Complete}"
    else
        log_error "${message:-Failed}"
    fi
}

# Log a message (wrapper for existing log functions)
ui_log() {
    local level="$1"
    local message="$2"

    case "$level" in
        step) log_step "$message" ;;
        section) log_section "$message" ;;
        info) log_info "$message" ;;
        success) log_success "$message" ;;
        warn) log_warn "$message" ;;
        error) log_error "$message" ;;
        dim) log_dim "$message" ;;
        *) echo "$message" ;;
    esac
}

#!/bin/bash

# Prevent multiple sourcing
[ -n "$_LOG_STEP_LOADED" ] && return
readonly _LOG_STEP_LOADED=1

# Color codes
readonly COLOR_RESET='\e[0m'
readonly COLOR_BOLD='\e[1m'
readonly COLOR_DIM='\e[2m'
readonly COLOR_GREEN='\e[32m'
readonly COLOR_BLUE='\e[34m'
readonly COLOR_YELLOW='\e[33m'
readonly COLOR_RED='\e[31m'
readonly COLOR_CYAN='\e[36m'

# Main step indicator (green arrow)
log_step() {
    local msg="$1"
    printf '\n%b%b▶%b %s\n' "$COLOR_BOLD" "$COLOR_GREEN" "$COLOR_RESET" "$msg"
}

# Section divider for major installation phases
log_section() {
    local msg="$1"
    printf '\n%b%b━━━ %s ━━━%b\n' "$COLOR_BOLD" "$COLOR_CYAN" "$msg" "$COLOR_RESET"
}

# Info message (indented, blue)
log_info() {
    local msg="$1"
    printf '  %bℹ%b %s\n' "$COLOR_BLUE" "$COLOR_RESET" "$msg"
}

# Success message (indented, green checkmark)
log_success() {
    local msg="$1"
    printf '  %b✓%b %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$msg"
}

# Warning message (yellow)
log_warn() {
    local msg="$1"
    printf '  %b⚠%b %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$msg"
}

# Error message (red, to stderr)
log_error() {
    local msg="$1"
    printf '  %b✗%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$msg" >&2
}

# Subdued/dim message for additional context
log_dim() {
    local msg="$1"
    printf '  %b%s%b\n' "$COLOR_DIM" "$msg" "$COLOR_RESET"
}
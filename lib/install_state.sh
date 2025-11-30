#!/bin/bash

# Prevent multiple sourcing
[ -n "$_INSTALL_STATE_LOADED" ] && return
readonly _INSTALL_STATE_LOADED=1

# State file path (uses process ID for uniqueness)
STATE_FILE="${STATE_FILE:-/tmp/langtool_install_state.$$}"

# Initialize state file
init_state() {
    if [ ! -f "$STATE_FILE" ]; then
        touch "$STATE_FILE"
        # Set up cleanup trap
        trap 'clear_state' EXIT INT TERM
    fi
}

# Save a key-value pair to state
save_state() {
    local key="$1"
    local value="$2"

    init_state

    # Remove existing key if present
    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "/^${key}=/d" "$STATE_FILE"
    fi

    # Append new value
    echo "${key}=${value}" >> "$STATE_FILE"
}

# Load a value from state
load_state() {
    local key="$1"

    if [ -f "$STATE_FILE" ]; then
        grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2-
    fi
}

# Export all state variables to environment
export_all_state() {
    if [ -f "$STATE_FILE" ]; then
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^# ]] && continue
            export "$key=$value"
        done < "$STATE_FILE"
    fi
}

# Get all state as a formatted string
get_all_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    fi
}

# Clear state file
clear_state() {
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
    fi
}

# Check if state file exists
state_exists() {
    [ -f "$STATE_FILE" ]
}

# Get a single state value (alias for load_state, for Python clarity)
get_state_value() {
    load_state "$1"
}

# List all state keys
list_state_keys() {
    if [ -f "$STATE_FILE" ]; then
        cut -d= -f1 "$STATE_FILE" 2>/dev/null | grep -v '^#' | grep -v '^$'
    fi
}

# Print state file path (for Python to access)
get_state_file_path() {
    echo "$STATE_FILE"
}

#!/bin/bash

# Prevent multiple sourcing
[ -n "$_UI_TUI_LOADED" ] && return
readonly _UI_TUI_LOADED=1

# TUI Backend Implementation
# Uses whiptail or dialog for text-based UI

# Detect which TUI tool to use
detect_tui_tool() {
    if command -v whiptail &>/dev/null; then
        echo "whiptail"
    elif command -v dialog &>/dev/null; then
        echo "dialog"
    else
        echo "none"
    fi
}

TUI_TOOL=$(detect_tui_tool)

# Display a message to the user
ui_show_message() {
    local title="$1"
    local message="$2"

    if [ "$TUI_TOOL" = "whiptail" ] || [ "$TUI_TOOL" = "dialog" ]; then
        $TUI_TOOL --title "$title" --msgbox "$message" 10 60
    else
        log_info "$message"
    fi
}

# Display an error to the user
ui_show_error() {
    local title="$1"
    local message="$2"

    if [ "$TUI_TOOL" = "whiptail" ] || [ "$TUI_TOOL" = "dialog" ]; then
        $TUI_TOOL --title "$title" --msgbox "ERROR: $message" 10 60
    else
        log_error "$message"
    fi
}

# Display a warning to the user
ui_show_warning() {
    local title="$1"
    local message="$2"

    if [ "$TUI_TOOL" = "whiptail" ] || [ "$TUI_TOOL" = "dialog" ]; then
        $TUI_TOOL --title "$title" --msgbox "WARNING: $message" 10 60
    else
        log_warn "$message"
    fi
}

# Display a success message
ui_show_success() {
    local title="$1"
    local message="$2"

    if [ "$TUI_TOOL" = "whiptail" ] || [ "$TUI_TOOL" = "dialog" ]; then
        $TUI_TOOL --title "$title" --msgbox "$message" 10 60
    else
        log_success "$message"
    fi
}

# Prompt for text input
ui_prompt_text() {
    local prompt="$1"
    local default="$2"
    local result

    if [ "$TUI_TOOL" = "whiptail" ] || [ "$TUI_TOOL" = "dialog" ]; then
        result=$($TUI_TOOL --title "Input" --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
        if [ $? -eq 0 ]; then
            echo "${result:-$default}"
        else
            echo "$default"
        fi
    else
        read -rp "$prompt ($default): " result
        echo "${result:-$default}"
    fi
}

# Prompt for directory path
ui_prompt_dir() {
    local prompt="$1"
    local default="$2"
    local result

    if [ "$TUI_TOOL" = "whiptail" ] || [ "$TUI_TOOL" = "dialog" ]; then
        # whiptail/dialog don't have directory chooser, use inputbox
        result=$($TUI_TOOL --title "Directory Selection" --inputbox "$prompt" 10 60 "$default" 3>&1 1>&2 2>&3)
        if [ $? -eq 0 ]; then
            echo "${result:-$default}"
        else
            echo "$default"
        fi
    else
        read -rp "$prompt ($default): " result
        echo "${result:-$default}"
    fi
}

# Prompt for yes/no confirmation
ui_confirm() {
    local prompt="$1"
    local default="$2"

    if [ "$TUI_TOOL" = "whiptail" ] || [ "$TUI_TOOL" = "dialog" ]; then
        if [ "$default" = "y" ] || [ "$default" = "yes" ]; then
            $TUI_TOOL --title "Confirmation" --defaultno --yesno "$prompt" 10 60
        else
            $TUI_TOOL --title "Confirmation" --yesno "$prompt" 10 60
        fi
        return $?
    else
        local result
        while true; do
            read -rp "$prompt [y/n] ($default): " result
            result="${result:-$default}"
            result="${result,,}"

            case "$result" in
                y|yes) return 0 ;;
                n|no) return 1 ;;
                *) echo "Please answer 'y' or 'n'" ;;
            esac
        done
    fi
}

# Prompt for choice from list
ui_prompt_choice() {
    local prompt="$1"
    shift
    local -a choices=("$@")
    local menu_items=()
    local result

    if [ "$TUI_TOOL" = "whiptail" ] || [ "$TUI_TOOL" = "dialog" ]; then
        # Build menu items array (tag description pairs)
        local i=1
        for choice in "${choices[@]}"; do
            menu_items+=("$choice" "Option $i")
            ((i++))
        done

        # Use menu dialog
        if [ "$TUI_TOOL" = "whiptail" ]; then
            result=$($TUI_TOOL --title "Selection" --notags --menu "$prompt" 20 60 12 "${menu_items[@]}" 3>&1 1>&2 2>&3)
        else
            result=$($TUI_TOOL --title "Selection" --noitem --menu "$prompt" 20 60 12 "${menu_items[@]}" 3>&1 1>&2 2>&3)
        fi

        if [ $? -eq 0 ] && [ -n "$result" ]; then
            echo "$result"
        else
            # User cancelled, return first choice as default
            echo "${choices[0]}"
        fi
    else
        # Fallback to select
        echo "$prompt" >&2
        PS3="Enter selection number: "
        select choice in "${choices[@]}"; do
            if [ -n "$choice" ]; then
                echo "$choice"
                return 0
            else
                echo "Invalid selection. Please try again." >&2
            fi
        done
    fi
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

    # TUI doesn't support real-time progress well, just show percentage
    if [ "$percentage" != "pulse" ]; then
        printf '\r  [%3d%%] %s' "$percentage" "${message:-In progress...}"
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

# Log a message
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

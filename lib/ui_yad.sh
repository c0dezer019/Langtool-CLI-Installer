#!/bin/bash

# Prevent multiple sourcing
[ -n "$_UI_YAD_LOADED" ] && return
readonly _UI_YAD_LOADED=1

# YAD Backend Implementation
# Uses YAD (Yet Another Dialog) for GUI

# Global variables for progress tracking
YAD_PROGRESS_PID=""
YAD_LOG_PID=""
PROGRESS_PIPE=""
LOG_PIPE=""

# Cleanup function for YAD processes and pipes
cleanup_yad() {
    [ -n "$YAD_PROGRESS_PID" ] && kill "$YAD_PROGRESS_PID" 2>/dev/null
    [ -n "$YAD_LOG_PID" ] && kill "$YAD_LOG_PID" 2>/dev/null
    [ -n "$PROGRESS_PIPE" ] && rm -f "$PROGRESS_PIPE"
    [ -n "$LOG_PIPE" ] && rm -f "$LOG_PIPE"
    return 0
}

trap cleanup_yad EXIT INT TERM

# Display a message to the user
ui_show_message() {
    local title="$1"
    local message="$2"

    yad --info \
        --title="$title" \
        --text="$message" \
        --button="gtk-ok:0" \
        --width=400 \
        --center \
        --image="dialog-information" 2>/dev/null
}

# Display an error to the user
ui_show_error() {
    local title="$1"
    local message="$2"

    yad --error \
        --title="$title" \
        --text="<b>Error:</b>\n\n$message" \
        --button="gtk-ok:0" \
        --width=400 \
        --center 2>/dev/null
}

# Display a warning to the user
ui_show_warning() {
    local title="$1"
    local message="$2"

    yad --warning \
        --title="$title" \
        --text="<b>Warning:</b>\n\n$message" \
        --button="gtk-ok:0" \
        --width=400 \
        --center 2>/dev/null
}

# Display a success message
ui_show_success() {
    local title="$1"
    local message="$2"

    yad --info \
        --title="$title" \
        --text="$message" \
        --button="gtk-ok:0" \
        --width=400 \
        --center \
        --image="dialog-information" 2>/dev/null
}

# Prompt for text input
ui_prompt_text() {
    local prompt="$1"
    local default="$2"
    local result

    if result=$(yad --entry \
        --title="Input" \
        --text="$prompt" \
        --entry-text="$default" \
        --button="gtk-cancel:1" \
        --button="gtk-ok:0" \
        --width=400 \
        --center 2>/dev/null); then
        echo "${result:-$default}"
    else
        echo "$default"
    fi
}

# Prompt for directory path
ui_prompt_dir() {
    local prompt="$1"
    local default="$2"
    local result

    if result=$(yad --file \
        --directory \
        --title="$prompt" \
        --filename="$default" \
        --button="gtk-cancel:1" \
        --button="gtk-ok:0" \
        --width=600 \
        --center 2>/dev/null) && [ -n "$result" ]; then
        # Remove trailing slash if present
        result="${result%/}"
        echo "$result"
    else
        echo "$default"
    fi
}

# Prompt for yes/no confirmation
ui_confirm() {
    local prompt="$1"
    local default="$2"

    yad --question \
        --title="Confirmation" \
        --text="$prompt" \
        --button="gtk-no:1" \
        --button="gtk-yes:0" \
        --width=400 \
        --center 2>/dev/null

    return $?
}

# Prompt for choice from list
ui_prompt_choice() {
    local prompt="$1"
    shift
    local -a choices=("$@")
    local list_items=()
    local result
    local first=true

    # Build list items (TRUE/FALSE, value, description)
    for choice in "${choices[@]}"; do
        if $first; then
            list_items+=("TRUE" "$choice" "")
            first=false
        else
            list_items+=("FALSE" "$choice" "")
        fi
    done

    if result=$(yad --list \
        --title="Selection" \
        --text="$prompt" \
        --column="Select:RD" \
        --column="Option" \
        --column="Description:HD" \
        --radiolist \
        --print-column=2 \
        --height=400 \
        --width=500 \
        --center \
        --button="gtk-cancel:1" \
        --button="gtk-ok:0" \
        "${list_items[@]}" 2>/dev/null) && [ -n "$result" ]; then
        # Remove trailing pipe if present
        echo "${result%|}"
    else
        # Return first choice as default
        echo "${choices[0]}"
    fi
}

# Start progress indication
ui_progress_start() {
    local title="$1"
    local message="$2"

    # Create named pipe for progress
    PROGRESS_PIPE="/tmp/langtool_progress_$$"
    mkfifo "$PROGRESS_PIPE" 2>/dev/null

    # Start YAD progress dialog
    yad --progress \
        --title="$title" \
        --text="$message" \
        --percentage=0 \
        --auto-close \
        --auto-kill \
        --width=500 \
        --center \
        --button="gtk-cancel:1" < "$PROGRESS_PIPE" 2>/dev/null &

    YAD_PROGRESS_PID=$!

    # Also log to terminal
    log_step "$message"
}

# Update progress
ui_progress_update() {
    local percentage="$1"
    local message="$2"

    if [ -n "$PROGRESS_PIPE" ] && [ -p "$PROGRESS_PIPE" ]; then
        if [ "$percentage" = "pulse" ]; then
            echo "#$message" > "$PROGRESS_PIPE" 2>/dev/null
        else
            echo "$percentage" > "$PROGRESS_PIPE" 2>/dev/null
            [ -n "$message" ] && echo "#$message" > "$PROGRESS_PIPE" 2>/dev/null
        fi
    fi
}

# End progress indication
ui_progress_end() {
    local success="$1"
    local message="$2"

    if [ -n "$PROGRESS_PIPE" ] && [ -p "$PROGRESS_PIPE" ]; then
        echo "100" > "$PROGRESS_PIPE" 2>/dev/null
        [ -n "$message" ] && echo "#$message" > "$PROGRESS_PIPE" 2>/dev/null
        sleep 0.5
        rm -f "$PROGRESS_PIPE"
    fi

    if [ "$success" = "true" ]; then
        log_success "${message:-Complete}"
    else
        log_error "${message:-Failed}"
    fi

    YAD_PROGRESS_PID=""
    PROGRESS_PIPE=""
}

# Log a message (for YAD, also output to terminal)
ui_log() {
    local level="$1"
    local message="$2"

    # Write to log pipe if active
    if [ -n "$LOG_PIPE" ] && [ -p "$LOG_PIPE" ]; then
        echo "[$(date '+%H:%M:%S')] $message" >> "$LOG_PIPE" 2>/dev/null
    fi

    # Also log to terminal using standard functions
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

# Start log viewer (for installation process)
ui_log_viewer_start() {
    local title="${1:-Installation Log}"

    # Create named pipe for log
    LOG_PIPE="/tmp/langtool_log_$$"
    mkfifo "$LOG_PIPE" 2>/dev/null

    # Start YAD log viewer
    yad --text-info \
        --title="$title" \
        --tail \
        --listen \
        --width=700 \
        --height=400 \
        --center \
        --button="gtk-close:0" < "$LOG_PIPE" 2>/dev/null &

    YAD_LOG_PID=$!
}

# Stop log viewer
ui_log_viewer_stop() {
    if [ -n "$YAD_LOG_PID" ]; then
        kill "$YAD_LOG_PID" 2>/dev/null
        YAD_LOG_PID=""
    fi

    if [ -n "$LOG_PIPE" ] && [ -p "$LOG_PIPE" ]; then
        rm -f "$LOG_PIPE"
        LOG_PIPE=""
    fi
}

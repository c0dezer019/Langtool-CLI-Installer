#!/bin/bash

# Prevent multiple sourcing
[ -n "$_GIT_PROGRESS_LOADED" ] && return
readonly _GIT_PROGRESS_LOADED=1

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/log_step.sh"

# Parse git progress output for percentage
parse_git_percentage() {
    local line="$1"
    local percentage="pulse"

    # Try multiple git progress patterns
    if [[ "$line" =~ ([0-9]+)%[[:space:]]*\([0-9]+/[0-9]+\) ]]; then
        percentage=${BASH_REMATCH[1]}
    elif [[ "$line" =~ Receiving[[:space:]]objects:[[:space:]]*([0-9]+)% ]]; then
        percentage=${BASH_REMATCH[1]}
    elif [[ "$line" =~ Resolving[[:space:]]deltas:[[:space:]]*([0-9]+)% ]]; then
        percentage=${BASH_REMATCH[1]}
    elif [[ "$line" =~ ([0-9]+)% ]]; then
        percentage=${BASH_REMATCH[1]}
    fi

    echo "$percentage"
}

# Clone git repository with progress tracking
# Args: repo_url target_dir branch [progress_callback]
clone_with_progress() {
    local repo="$1"
    local target="$2"
    local branch="$3"
    local progress_callback="${4:-}"
    local line
    local percentage
    local last_percentage=0

    # Start progress if callback provided
    if [ -n "$progress_callback" ] && declare -F "$progress_callback" >/dev/null 2>&1; then
        $progress_callback "start" "0" "Initializing git clone..."
    fi

    # Create target directory if needed
    local target_parent
    target_parent="$(dirname "$target")"
    if [ ! -d "$target_parent" ]; then
        mkdir -p "$target_parent" 2>/dev/null || sudo mkdir -p "$target_parent"
    fi

    # Run git clone with progress output
    git -c advice.detachedHead=0 -c core.autocrlf=false clone \
        --progress --branch "$branch" --depth 1 "$repo" "$target" 2>&1 | \
        while IFS= read -r line; do
            # Parse percentage from line
            percentage=$(parse_git_percentage "$line")

            # Call progress callback if percentage changed
            if [ -n "$progress_callback" ] && declare -F "$progress_callback" >/dev/null 2>&1; then
                if [ "$percentage" != "$last_percentage" ]; then
                    $progress_callback "update" "$percentage" "$line"
                    last_percentage="$percentage"
                fi
            fi

            # Also log to stderr for debugging if LANGTOOL_DEBUG is set
            [ -n "$LANGTOOL_DEBUG" ] && echo "$line" >&2
        done

    # Check if clone succeeded
    local exit_code=$?

    # End progress if callback provided
    if [ -n "$progress_callback" ] && declare -F "$progress_callback" >/dev/null 2>&1; then
        if [ $exit_code -eq 0 ]; then
            $progress_callback "end" "100" "Clone complete"
        else
            $progress_callback "error" "0" "Clone failed"
        fi
    fi

    return $exit_code
}

# Default progress callback for CLI mode
default_progress_callback() {
    local action="$1"
    local percentage="$2"
    local message="$3"

    case "$action" in
        start)
            ui_progress_start "Git Clone" "$message"
            ;;
        update)
            if [ "$percentage" != "pulse" ]; then
                ui_progress_update "$percentage" "$message"
            fi
            ;;
        end)
            ui_progress_end "true" "$message"
            ;;
        error)
            ui_progress_end "false" "$message"
            ;;
    esac
}

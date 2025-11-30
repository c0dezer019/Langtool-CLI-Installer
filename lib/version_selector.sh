#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/log_step.sh"

# Fetch available LanguageTool snapshot versions
fetch_versions() {
    local versions
    log_info "Fetching available LanguageTool versions..." >&2
    versions=$(curl -s "https://internal1.languagetool.org/snapshots/" |
        grep -oP 'LanguageTool-\K[0-9]{8}(?=-snapshot\.zip)' |
        grep -v 'wikipedia\|predeploy' |
        sort -r |
        uniq |
        head -20)

    if [[ -z "$versions" ]]; then
        echo "latest"
    else
        echo "$versions"
    fi
}

# Detect which UI tool is available (priority order: whiptail > dialog > select)
detect_ui_tool() {
    if command -v whiptail &>/dev/null; then
        echo "whiptail"
    elif command -v dialog &>/dev/null; then
        echo "dialog"
    else
        echo "select"
    fi
}

# Select version using whiptail or dialog
select_version_dialog_like() {
    local tool=$1
    local versions
    local version
    local menu_items=()

    # Fetch versions and convert to array
    versions=()
    while IFS= read -r ver; do
        versions+=("$ver")
    done < <(fetch_versions)

    if [[ ${#versions[@]} -eq 0 ]]; then
        "$tool" --msgbox "Failed to fetch versions. Using 'latest' as default." 8 50
        echo "latest"
        return
    fi

    # Build menu items array (tag description pairs)
    for ver in "${versions[@]}"; do
        menu_items+=("$ver" "Snapshot $ver")
    done

    # Use dialog/whiptail menu (redirect stderr to stdout for capture)
    # Use dialog/whiptail menu (redirect stderr to stdout for capture)
    if [[ "$tool" == "whiptail" ]]; then
        version=$("$tool" --title "LT Version Selection" \
            --notags \
            --menu "Select a snapshot version:" \
            20 30 12 \
            "${menu_items[@]}" \
            3>&1 1>&2 2>&3)
    else
        version=$("$tool" --title "LT Version Selection" \
            --noitem \
            --menu "Select a snapshot version:" \
            20 30 12 \
            "${menu_items[@]}" \
            3>&1 1>&2 2>&3)
    fi

    # Handle user cancellation or selection
    if [[ $? -eq 0 && -n "$version" ]]; then
        echo "$version"
    else
        # User cancelled or closed dialog - use latest
        echo "latest"
    fi
}

# Select version using bash select
select_version_select() {
    local versions
    local version

    # Fetch versions and convert to array
    versions=()
    while IFS= read -r ver; do
        versions+=("$ver")
    done < <(fetch_versions)

    if [[ ${#versions[@]} -eq 0 ]]; then
        log_warn "Failed to fetch versions. Using 'latest' as default."
        echo "latest"
        return
    fi

    log_info "Select a LanguageTool snapshot version:" >&2
    versions+=("latest") # Add 'latest' option

    PS3="Enter selection number (or press Ctrl+C to use latest): "
    select version in "${versions[@]}"; do
        if [[ -n "$version" ]]; then
            echo "$version"
            break
        else
            log_warn "Invalid selection. Please try again."
        fi
    done
}

# Main entry point
set_version_gui() {
    local lt_ver
    local ui_tool

    ui_tool=$(detect_ui_tool)

    case "$ui_tool" in
    whiptail | dialog)
        lt_ver=$(select_version_dialog_like "$ui_tool")
        "$ui_tool" --msgbox "Using LanguageTool version: $lt_ver" 8 50
        clear
        ;;
    select)
        lt_ver=$(select_version_select)
        ;;
    esac

    log_info "Using LanguageTool version: $lt_ver"
    export LT_VER="$lt_ver"
    update_shell_rc "LT_VER" "$lt_ver"
}

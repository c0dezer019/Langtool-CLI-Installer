#!/usr/bin/env bash

set -e
[ -n "$LANGTOOL_DEBUG" ] && set -x

# Force GUI mode
export UI_BACKEND="${UI_BACKEND:-yad}"

# shellcheck disable=SC1091
source "./lib/ui_abstraction.sh"
# shellcheck disable=SC1091
source "./lib/install_state.sh"
# shellcheck disable=SC1091
source "./lib/version_selector.sh"
# shellcheck disable=SC1091
source "./lib/update_shell_rc.sh"
# shellcheck disable=SC1091
source "./lib/git_progress.sh"

# Check if we're actually in GUI mode
if [ "$UI_BACKEND" != "yad" ]; then
    ui_show_warning "GUI Mode Unavailable" "YAD is not available. Falling back to standard installer."
    exec ./install.sh
    exit $?
fi

# Initialize state
init_state

# Step 1: Welcome & Prerequisites
show_welcome_step() {
    local git_status ssh_status result

    # Check prerequisites
    if command -v git &>/dev/null; then
        git_status="✅ $(git --version)"
    else
        git_status="❌ Not installed"
    fi

    if [ -n "${USE_SSH}" ]; then
        if command -v ssh &>/dev/null; then
            if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
                ssh_status="✅ Authenticated"
            else
                ssh_status="⚠️ Available but not authenticated"
            fi
        else
            ssh_status="❌ Not installed"
        fi
    else
        ssh_status="ℹ️ Not required (using HTTPS)"
    fi

    result=$(yad --form \
        --title="Langtool-CLI Installer - Welcome" \
        --text="<b>Welcome to Langtool-CLI Installer</b>\n\nThis wizard will guide you through installing langtool-cli.\n\n<b>Prerequisites Check:</b>" \
        --field="<b>Git</b>:LBL" "$git_status" \
        --field="<b>SSH</b>:LBL" "$ssh_status" \
        --field="":LBL "" \
        --field="<i>Click Next to continue or Cancel to exit.</i>:LBL" "" \
        --button="gtk-cancel:1" \
        --button="gtk-go-forward:0" \
        --width=600 \
        --height=300 \
        --center \
        --image="dialog-information" \
        --image-on-top \
        2>/dev/null)

    return $?
}

# Step 2: Configuration
show_config_step() {
    local default_cli_dir="$HOME/.local/share/Langtool-CLI"
    local default_lt_dir="$HOME/.local/share/LanguageTool"
    local result cli_dir lt_dir

    # Load saved state if exists
    if state_exists; then
        default_cli_dir=$(load_state "LT_CLI_DIR" || echo "$default_cli_dir")
        default_lt_dir=$(load_state "LT_INSTALL_DIR" || echo "$default_lt_dir")
    fi

    result=$(yad --form \
        --title="Langtool-CLI Installer - Configuration" \
        --text="<b>Configure Installation Paths</b>\n\nChoose where to install components:" \
        --field="CLI Installation Directory:DIR" "$default_cli_dir" \
        --field="LanguageTool Directory:DIR" "$default_lt_dir" \
        --field="":LBL "" \
        --field="<i>Use default paths or browse to select custom locations.</i>:LBL" "" \
        --button="gtk-go-back:2" \
        --button="gtk-cancel:1" \
        --button="gtk-go-forward:0" \
        --width=650 \
        --height=280 \
        --center \
        --separator="|" \
        2>/dev/null)

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        cli_dir=$(echo "$result" | cut -d'|' -f1)
        lt_dir=$(echo "$result" | cut -d'|' -f2)

        # Remove trailing slashes
        cli_dir="${cli_dir%/}"
        lt_dir="${lt_dir%/}"

        save_state "LT_CLI_DIR" "$cli_dir"
        save_state "LT_INSTALL_DIR" "$lt_dir"
        export LT_CLI_DIR="$cli_dir"
        export LT_INSTALL_DIR="$lt_dir"
    fi

    return $exit_code
}

# Step 3: Version Selection
show_version_step() {
    local versions result list_items first

    # Show loading dialog while fetching
    yad --progress \
        --pulsate \
        --text="Fetching available LanguageTool versions..." \
        --auto-close \
        --no-buttons \
        --width=400 \
        --height=100 \
        --center \
        2>/dev/null &
    local loading_pid=$!

    # Fetch versions
    versions=$(fetch_versions)

    # Close loading dialog
    kill $loading_pid 2>/dev/null

    # Build list items
    list_items=()
    first=true
    while IFS= read -r ver; do
        if $first; then
            list_items+=("TRUE" "$ver" "LanguageTool $ver")
            first=false
        else
            list_items+=("FALSE" "$ver" "LanguageTool $ver")
        fi
    done <<< "$versions"

    result=$(yad --list \
        --title="Langtool-CLI Installer - Version Selection" \
        --text="<b>Select LanguageTool Version</b>\n\nChoose the version to install:" \
        --column="Select:RD" \
        --column="Version" \
        --column="Description" \
        --radiolist \
        --print-column=2 \
        --height=500 \
        --width=650 \
        --center \
        --button="gtk-go-back:2" \
        --button="gtk-cancel:1" \
        --button="gtk-go-forward:0" \
        "${list_items[@]}" \
        2>/dev/null)

    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        # Remove trailing pipe
        result="${result%|}"
        save_state "LT_VER" "$result"
        export LT_VER="$result"
    fi

    return $exit_code
}

# Step 4: Confirmation
show_confirmation_step() {
    local summary cli_dir lt_dir lt_ver

    cli_dir=$(load_state "LT_CLI_DIR")
    lt_dir=$(load_state "LT_INSTALL_DIR")
    lt_ver=$(load_state "LT_VER")

    summary="<b>Installation Summary</b>\n\n"
    summary+="Please review your selections before proceeding:\n\n"
    summary+="<b>CLI Directory:</b>\n  $cli_dir\n\n"
    summary+="<b>LanguageTool Directory:</b>\n  $lt_dir\n\n"
    summary+="<b>Version:</b>\n  $lt_ver\n\n"
    summary+="<b>Git Mode:</b>\n  "

    if [ -n "${USE_SSH}" ]; then
        summary+='SSH \(git@github.com\)'
        summary+='\n'
    else
        summary+='HTTPS \(https://github.com/\)'
        summary+='\n'
    fi

    summary+="\n<i>Click Install to begin installation.</i>"

    yad --text-info \
        --title="Langtool-CLI Installer - Confirmation" \
        --text="$summary" \
        --no-markup=false \
        --wrap \
        --width=650 \
        --height=400 \
        --center \
        --button="gtk-go-back:2" \
        --button="gtk-cancel:1" \
        --button="Install!gtk-yes:0" \
        2>/dev/null

    return $?
}

# Step 5: Installation
run_installation_step() {
    local progress_pipe log_pipe cli_dir lt_dir lt_ver github

    # Load state
    cli_dir=$(load_state "LT_CLI_DIR")
    lt_dir=$(load_state "LT_INSTALL_DIR")
    lt_ver=$(load_state "LT_VER")

    # Export to environment
    export LT_CLI_DIR="$cli_dir"
    export LT_INSTALL_DIR="$lt_dir"
    export LT_VER="$lt_ver"

    # Create named pipes
    progress_pipe="/tmp/lt_install_progress_$$"
    log_pipe="/tmp/lt_install_log_$$"
    mkfifo "$progress_pipe" 2>/dev/null || true
    mkfifo "$log_pipe" 2>/dev/null || true

    # Start progress dialog
    yad --multi-progress \
        --title="Langtool-CLI Installer - Installing" \
        --text="Installing Langtool-CLI..." \
        --bar="Overall Progress:NORM" \
        --bar="Current Task:NORM" \
        --auto-close \
        --width=600 \
        --height=200 \
        --center \
        < "$progress_pipe" 2>/dev/null &
    local progress_pid=$!

    # Start log viewer
    yad --text-info \
        --title="Installation Log" \
        --tail \
        --listen \
        --width=700 \
        --height=400 \
        --center \
        --button="gtk-close:0" \
        < "$log_pipe" 2>/dev/null &
    local log_pid=$!

    # Run installation in background
    (
        # Helper function to log
        log_to_pipe() {
            echo "[$(date '+%H:%M:%S')] $1" >> "$log_pipe"
        }

        # Step 1: Create directories
        echo "1:10" > "$progress_pipe"
        echo "2:# Creating directories..." > "$progress_pipe"
        log_to_pipe "Creating installation directories..."

        mkdir -p "$cli_dir" 2>&1 | tee -a "$log_pipe" || {
            log_to_pipe "Creating $cli_dir requires elevated privileges, attempting with sudo..."
            sudo mkdir -p "$cli_dir" 2>&1 | tee -a "$log_pipe"
        }

        mkdir -p "$lt_dir" 2>&1 | tee -a "$log_pipe"

        # Step 2: Clone repository
        echo "1:30" > "$progress_pipe"
        echo "2:# Cloning repository..." > "$progress_pipe"
        log_to_pipe "Cloning Langtool-CLI repository..."

        if [ -n "${USE_SSH}" ]; then
            github="git@github.com:"
        else
            github="https://github.com/"
        fi

        # Check if previous installation exists
        if [ -d "$cli_dir/.git" ]; then
            log_to_pipe "Previous installation found, updating..."
            rm -rf "$cli_dir" 2>&1 | tee -a "$log_pipe" || sudo rm -rf "$cli_dir" 2>&1 | tee -a "$log_pipe"
        fi

        git -c advice.detachedHead=0 -c core.autocrlf=false clone \
            --progress --branch "${LANGTOOL_GIT_TAG:-base}" --depth 1 \
            "${github}c0dezer019/Langtool-CLI.git" "$cli_dir" 2>&1 | \
            while IFS= read -r line; do
                log_to_pipe "$line"
                if [[ "$line" =~ ([0-9]+)% ]]; then
                    pct=${BASH_REMATCH[1]}
                    echo "2:$pct" > "$progress_pipe"
                fi
            done

        # Step 3: Update shell RC
        echo "1:60" > "$progress_pipe"
        echo "2:# Updating shell configuration..." > "$progress_pipe"
        log_to_pipe "Updating shell configuration..."

        update_shell_rc "LT_CLI_DIR" "$cli_dir" 2>&1 | tee -a "$log_pipe"
        update_shell_rc "LT_INSTALL_DIR" "$lt_dir" 2>&1 | tee -a "$log_pipe"
        update_shell_rc "LT_VER" "$lt_ver" 2>&1 | tee -a "$log_pipe"

        # Step 4: Create symlinks
        echo "1:80" > "$progress_pipe"
        echo "2:# Creating symlinks..." > "$progress_pipe"
        log_to_pipe "Creating CLI symlinks..."

        mkdir -p "$cli_dir/bin" 2>&1 | tee -a "$log_pipe"
        ln -sf "$cli_dir/langtool" "$cli_dir/bin/langtool" 2>&1 | tee -a "$log_pipe"
        ln -sf "$cli_dir/lib/uninstall.sh" "$cli_dir/bin/uninstall" 2>&1 | tee -a "$log_pipe"

        update_shell_rc "PATH" "$cli_dir/bin" prepend_path 2>&1 | tee -a "$log_pipe"

        # Step 5: Complete
        echo "1:100" > "$progress_pipe"
        echo "2:100" > "$progress_pipe"
        log_to_pipe "Installation complete!"

        sleep 1
    ) &

    local install_pid=$!

    # Wait for installation to complete
    wait $install_pid
    local install_exit=$?

    # Clean up YAD dialogs
    kill $progress_pid 2>/dev/null || true
    kill $log_pid 2>/dev/null || true

    # Clean up pipes
    rm -f "$progress_pipe" "$log_pipe"

    # Show completion dialog
    if [ $install_exit -eq 0 ]; then
        yad --info \
            --title="Installation Complete" \
            --text="<b>Langtool-CLI installed successfully!</b>\n\nPlease restart your shell to use the CLI commands." \
            --button="gtk-ok:0" \
            --width=450 \
            --height=150 \
            --center \
            --image="dialog-information" 2>/dev/null
    else
        yad --error \
            --title="Installation Failed" \
            --text="<b>Installation encountered errors.</b>\n\nPlease check the log for details." \
            --button="gtk-ok:0" \
            --width=450 \
            --height=150 \
            --center 2>/dev/null
    fi

    return $install_exit
}

# Handle cancel confirmation
handle_cancel() {
    if yad --question \
        --title="Cancel Installation?" \
        --text="Are you sure you want to cancel the installation?" \
        --button="No:1" \
        --button="Yes:0" \
        --width=350 \
        --height=100 \
        --center 2>/dev/null; then
        clear_state
        exit 0
    fi
}

# Main wizard flow
run_wizard() {
    local current_step=1

    while true; do
        case $current_step in
            1)
                show_welcome_step
                exit_code=$?
                ;;
            2)
                show_config_step
                exit_code=$?
                ;;
            3)
                show_version_step
                exit_code=$?
                ;;
            4)
                show_confirmation_step
                exit_code=$?
                ;;
            5)
                run_installation_step
                exit_code=$?
                clear_state
                exit $exit_code
                ;;
        esac

        case $exit_code in
            0)
                # Next button
                current_step=$((current_step + 1))
                ;;
            2)
                # Back button
                current_step=$((current_step - 1))
                [ $current_step -lt 1 ] && current_step=1
                ;;
            *)
                # Cancel or error
                handle_cancel
                ;;
        esac

        save_state "STEP" "$current_step"
    done
}

# Run the wizard
run_wizard

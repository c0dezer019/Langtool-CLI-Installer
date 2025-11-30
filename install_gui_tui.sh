#!/usr/bin/env bash

# TUI installer using whiptail for interactive installation

[ -n "$LANGTOOL_DEBUG" ] && set -x

# Force TUI mode
export UI_BACKEND="${UI_BACKEND:-tui}"

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

# Initialize UI
ui_init

# Initialize state
init_state

# Cleanup on exit
trap 'clear_state' EXIT INT TERM

# Main wizard using TUI (whiptail)
run_wizard_tui() {
    local default_cli_dir="$HOME/.local/share/Langtool-CLI"
    local default_lt_dir="$HOME/.local/share/LanguageTool"
    local git_status ssh_status

    # Load saved state if exists
    if state_exists; then
        default_cli_dir=$(load_state "LT_CLI_DIR" || echo "$default_cli_dir")
        default_lt_dir=$(load_state "LT_INSTALL_DIR" || echo "$default_lt_dir")
    fi

    # Check prerequisites
    if command -v git &>/dev/null; then
        git_status="✓ Installed"
    else
        git_status="✗ Not installed"
    fi

    if [ -n "${USE_SSH}" ]; then
        if command -v ssh &>/dev/null; then
            ssh_status="✓ Installed"
        else
            ssh_status="✗ Not installed"
        fi
    else
        ssh_status="ℹ Not required (HTTPS)"
    fi

    # Step 1: Welcome
    ui_show_message "Welcome" \
        "Welcome to Langtool-CLI Installer\n\nThis wizard will guide you through installation.\n\nPrerequisites:\nGit: $git_status\nSSH: $ssh_status"

    # Step 2: Configuration (path selection)
    local cli_dir lt_dir

    cli_dir=$(ui_prompt_dir "CLI Installation Directory:" "$default_cli_dir")
    [ -z "$cli_dir" ] && cli_dir="$default_cli_dir"

    lt_dir=$(ui_prompt_dir "LanguageTool Directory:" "$default_lt_dir")
    [ -z "$lt_dir" ] && lt_dir="$default_lt_dir"

    # Remove trailing slashes
    cli_dir="${cli_dir%/}"
    lt_dir="${lt_dir%/}"

    save_state "LT_CLI_DIR" "$cli_dir"
    save_state "LT_INSTALL_DIR" "$lt_dir"

    # Step 3: Confirmation
    ui_confirm "Installation Summary\n\nCLI Dir: $cli_dir\nLT Dir: $lt_dir\n\nProceed with installation?" "y" || {
        clear_state
        exit 1
    }

    # Proceed with installation
    run_installation_step
    exit $?
}

# Installation execution
run_installation_step() {
    local cli_dir lt_dir lt_ver github

    # Load state
    cli_dir=$(load_state "LT_CLI_DIR")
    lt_dir=$(load_state "LT_INSTALL_DIR")
    lt_ver=$(load_state "LT_VER" || echo "latest")

    # Export to environment
    export LT_CLI_DIR="$cli_dir"
    export LT_INSTALL_DIR="$lt_dir"
    export LT_VER="$lt_ver"

    # Show installation progress
    ui_progress_start "Installation" "Installing Langtool-CLI..."

    # Run installation
    (
        # Create directories
        ui_progress_update 10 "Creating directories..."
        mkdir -p "$cli_dir" 2>&1 || {
            sudo mkdir -p "$cli_dir" 2>&1
        }
        mkdir -p "$lt_dir" 2>&1

        # Clone repository
        ui_progress_update 40 "Cloning repository..."

        if [ -n "${USE_SSH}" ]; then
            github="git@github.com:"
        else
            github="https://github.com/"
        fi

        if [ -d "$cli_dir/.git" ]; then
            ui_progress_update 35 "Updating existing installation..."
            rm -rf "$cli_dir" 2>&1 || sudo rm -rf "$cli_dir" 2>&1
        fi

        git -c advice.detachedHead=0 -c core.autocrlf=false clone \
            --progress --branch "${LANGTOOL_GIT_TAG:-base}" --depth 1 \
            "${github}c0dezer019/Langtool-CLI.git" "$cli_dir" 2>&1

        # Update shell RC
        ui_progress_update 70 "Updating configuration..."
        update_shell_rc "LT_CLI_DIR" "$cli_dir" 2>&1
        update_shell_rc "LT_INSTALL_DIR" "$lt_dir" 2>&1
        update_shell_rc "LT_VER" "$lt_ver" 2>&1

        # Create symlinks
        ui_progress_update 85 "Creating symlinks..."
        mkdir -p "$cli_dir/bin" 2>&1
        ln -sf "$cli_dir/langtool" "$cli_dir/bin/langtool" 2>&1
        ln -sf "$cli_dir/lib/uninstall.sh" "$cli_dir/bin/uninstall" 2>&1
        update_shell_rc "PATH" "$cli_dir/bin" prepend_path 2>&1

        # Complete
        ui_progress_update 100 "Installation complete!"
        sleep 1
    )

    local install_exit=$?

    if [ $install_exit -eq 0 ]; then
        ui_show_success "Installation Complete" \
            "Installation successful!\n\nPlease restart your shell or run:\n  source ~/.bashrc\n\nto use the CLI."
    else
        ui_show_error "Installation Failed" \
            "Installation encountered errors.\n\nPlease check the output above and try again."
    fi

    clear_state
    return $install_exit
}

# Run the wizard
run_wizard_tui

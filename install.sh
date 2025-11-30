#!/usr/bin/env bash

set -e
[ -n "$LANGTOOL_DEBUG" ] && set -x

# shellcheck disable=SC1091
source "./lib/log_step.sh"
# shellcheck disable=SC1091
source "./lib/ui_abstraction.sh"
# shellcheck disable=SC1091
source "./lib/install_cli.sh"
# shellcheck disable=SC1091
source "./lib/update_shell_rc.sh"
# shellcheck disable=SC1091
source "./lib/set_version.sh"
# shellcheck disable=SC1091
source "./lib/git_progress.sh"

home_dir=""
cli_install_dir=""

ui_log section "Langtool-CLI Installer"

if [ -z "$HOME" ]; then
    if command -v whoami >/dev/null 2>&1; then
        home_dir="/home/$(whoami)"
        export HOME=$home_dir
    elif [ -n "$USER" ]; then
        home_dir="/home/${USER}"
        export HOME=$home_dir
    else
        ui_log error "Unable to determine the user, please manually set HOME before continuing."
        exit 1
    fi

    ui_log warn "HOME variable not set. Temporarily set to: $HOME"
    ui_log dim "To set permanently: usermod -d /home/[user] [user]"
fi

ui_log section "Configuration"

if [ -z "$LT_CLI_DIR" ]; then
    ui_log step "Resolving Langtool CLI installation directory"
    cli_install_dir=$(ui_prompt_dir "Where would you like langtool-cli to be installed?" "${HOME}/.local/share/Langtool-CLI")

    export LT_CLI_DIR="$cli_install_dir"
    update_shell_rc "LT_CLI_DIR" "$cli_install_dir"

    ui_log info "Installation directory: $LT_CLI_DIR"
    if ! mkdir -p "$LT_CLI_DIR" 2>/dev/null; then
        ui_log warn "Creating $LT_CLI_DIR requires elevated privileges, attempting with sudo..."
        sudo mkdir -p "$LT_CLI_DIR"
    fi
else
    ui_log step "Using pre-configured Langtool CLI directory"
    ui_log info "Installation directory: $LT_CLI_DIR"
    update_shell_rc "LT_CLI_DIR" "$LT_CLI_DIR"
fi

if [ -z "$LT_INSTALL_DIR" ]; then
    ui_log step "Resolving LanguageTool installation directory"
    install_dir=$(ui_prompt_dir "Where is LanguageTool installed?" "${HOME}/.local/share/LanguageTool")

    export LT_INSTALL_DIR="$install_dir"
    update_shell_rc "LT_INSTALL_DIR" "$install_dir"
    mkdir -p "$install_dir"
    ui_log info "LanguageTool directory: $LT_INSTALL_DIR"
else
    mkdir -p "$LT_INSTALL_DIR"
fi

if [ -z "${LT_VER}" ]; then
    set_version
else
    update_shell_rc "LT_VER" "$LT_VER"
fi

ui_log section "Prerequisites"

ui_log step "Checking for git"
if ! command -v git 1>/dev/null 2>&1; then
    ui_log error "Git is not installed, can't continue."
    exit 1
fi
ui_log success "Git found"

if [ -n "${USE_SSH}" ]; then
    ui_log step "Checking for ssh"
    if ! command -v ssh 1>/dev/null 2>&1; then
        ui_log error "SSH is not installed and cannot continue."
        exit 1
    fi

    ssh -T git@github.com 1>/dev/null 2>&1 || EXIT_CODE=$?
    if [[ ${EXIT_CODE} != 1 ]]; then
        ui_log error "GitHub SSH authentication failed."
        ui_log info "You need to have an SSH key set up to use SSH mode."
        ui_log dim "Generate a key: ssh-keygen"
        ui_log dim "For help: https://docs.github.com/en/repositories/creating-and-managing-repositories/troubleshooting-cloning-errors#check-your-ssh-access"
        exit 1
    fi
    ui_log success "SSH authentication verified"
fi

ui_log section "Installation"

if [ -n "${USE_SSH}" ]; then
    GITHUB="git@github.com"
else
    GITHUB="https://github.com/"
fi

install_cli ${GITHUB}c0dezer019/Langtool-CLI.git "$LT_CLI_DIR" "${LANGTOOL_GIT_TAG:-base}"

if [ -n "$LT_CLI_DIR" ]; then
    lt_cli_bin="$LT_CLI_DIR/bin"
    path_contains_bin=0
    IFS=':' read -r -a path_entries <<<"${PATH:-}"

    for entry in "${path_entries[@]}"; do
        if [ "$entry" = "$lt_cli_bin" ]; then
            path_contains_bin=1
            break
        fi
    done
    if [ $path_contains_bin -eq 0 ]; then
        export PATH="$lt_cli_bin:$PATH"
    fi

    ui_log step "Creating CLI symlinks"

    if [ ! -d "$LT_CLI_DIR/bin" ]; then
        if [ ! -w "$LT_CLI_DIR" ]; then
            sudo mkdir "$LT_CLI_DIR/bin"
        else
            mkdir "$LT_CLI_DIR/bin"
        fi
    fi

    ln -sf "$LT_CLI_DIR/langtool" "$LT_CLI_DIR/bin/langtool"
    ln -sf "$LT_CLI_DIR/lib/uninstall.sh" "$LT_CLI_DIR/bin/uninstall"

    update_shell_rc "PATH" "$LT_CLI_DIR/bin" prepend_path
    ui_log success "Symlinks created in $lt_cli_bin"

    ui_log section "Complete"

    if [ "$LT_CLI_UPDATED" ]; then
        ui_log success "Langtool-CLI updated successfully!\n"
    else
        ui_log success "Installation complete!"
        ui_log info "Please restart your shell to access the CLI\n"
    fi

fi

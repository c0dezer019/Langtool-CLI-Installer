#!/usr/bin/env bash

set -e
[ -n "$LANGTOOL_DEBUG" ] && set -x

# shellcheck disable=SC1091
source "./lib/install_cli.sh"
# shellcheck disable=SC1091
source "./lib/update_shell_rc.sh"
# shellcheck disable=SC1091
source "./lib/set_version.sh"
# shellcheck disable=SC1091
source "./lib/log_step.sh"

home_dir=""
cli_install_dir=""

log_section "Langtool-CLI Installer"

if [ -z "$HOME" ]; then
    if command -v whoami >/dev/null 2>&1; then
        home_dir="/home/$(whoami)"
        export HOME=$home_dir
    elif [ -n "$USER" ]; then
        home_dir="/home/${USER}"
        export HOME=$home_dir
    else
        log_error "Unable to determine the user, please manually set HOME before continuing."
        exit 1
    fi

    log_warn "HOME variable not set. Temporarily set to: $HOME"
    log_dim "To set permanently: usermod -d /home/[user] [user]"
fi

log_section "Configuration"

if [ -z "$LT_CLI_DIR" ]; then
    log_step "Resolving Langtool CLI installation directory"
    read -rp "Where would you like langtool-cli to be installed? (${HOME}/.local/share/Langtool-CLI): " cli_install_dir

    if [ -n "$cli_install_dir" ]; then
        export LT_CLI_DIR="$cli_install_dir"
        update_shell_rc "LT_CLI_DIR" "$cli_install_dir"
    else
        cli_install_dir="$HOME/.local/share/Langtool-CLI"
        export LT_CLI_DIR="$cli_install_dir"
        update_shell_rc "LT_CLI_DIR" "$cli_install_dir"
    fi

    log_info "Installation directory: $LT_CLI_DIR"
    if ! mkdir -p "$LT_CLI_DIR" 2>/dev/null; then
        log_warn "Creating $LT_CLI_DIR requires elevated privileges, attempting with sudo..."
        sudo mkdir -p "$LT_CLI_DIR"
    fi
else
    log_step "Using pre-configured Langtool CLI directory"
    log_info "Installation directory: $LT_CLI_DIR"
    update_shell_rc "LT_CLI_DIR" "$LT_CLI_DIR"
fi

if [ -z "$LT_INSTALL_DIR" ]; then
    log_step "Resolving LanguageTool installation directory"
    read -rp "Where is LanguageTool installed? (${HOME}/.local/share/LanguageTool): " install_dir

    if [ -n "$install_dir" ]; then
        export LT_INSTALL_DIR="$install_dir"
        update_shell_rc "LT_INSTALL_DIR" "$install_dir"
        mkdir -p "$install_dir"
    else
        export LT_INSTALL_DIR="$HOME/.local/share/LanguageTool"
        update_shell_rc "LT_INSTALL_DIR" "$HOME/.local/share/LanguageTool"
        mkdir -p "$install_dir"
    fi
    log_info "LanguageTool directory: $LT_INSTALL_DIR"
else
    mkdir -p "$LT_INSTALL_DIR"
fi

if [ -z "${LT_VER}" ]; then
    set_version
else
    update_shell_rc "LT_VER" "$LT_VER"
fi

log_section "Prerequisites"

log_step "Checking for git"
if ! command -v git 1>/dev/null 2>&1; then
    log_error "Git is not installed, can't continue."
    exit 1
fi
log_success "Git found"

if [ -n "${USE_SSH}" ]; then
    log_step "Checking for ssh"
    if ! command -v ssh 1>/dev/null 2>&1; then
        log_error "SSH is not installed and cannot continue."
        exit 1
    fi

    ssh -T git@github.com 1>/dev/null 2>&1 || EXIT_CODE=$?
    if [[ ${EXIT_CODE} != 1 ]]; then
        log_error "GitHub SSH authentication failed."
        log_info "You need to have an SSH key set up to use SSH mode."
        log_dim "Generate a key: ssh-keygen"
        log_dim "For help: https://docs.github.com/en/repositories/creating-and-managing-repositories/troubleshooting-cloning-errors#check-your-ssh-access"
        exit 1
    fi
    log_success "SSH authentication verified"
fi

log_section "Installation"

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

    log_step "Creating CLI symlinks"

    if [ ! -d "$LT_CLI_DIR/bin" ]; then
        if [ ! -w "$LT_CLI_DIR" ]; then
            sudo mkdir "$LT_CLI_DIR/bin"
        else
            mkdir "$LT_CLI_DIR/bin"
        fi
    fi

    ln -sf "$LT_CLI_DIR/lib/langtool" "$LT_CLI_DIR/bin/langtool"
    ln -sf "$LT_CLI_DIR/lib/uninstall" "$LT_CLI_DIR/bin/uninstall"

    update_shell_rc "PATH" "$LT_CLI_DIR/bin" prepend_path
    log_success "Symlinks created in $lt_cli_bin"

    log_section "Complete"

    if [ "$LT_CLI_UPDATED" ]; then
        log_success "Langtool-CLI updated successfully!\n"
    else
        log_success "Installation complete!"
        log_info "Please restart your shell to access the CLI\n"
    fi

fi

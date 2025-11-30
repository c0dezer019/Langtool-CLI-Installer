#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/log_step.sh"

determine_shell_rc() {
    local shell_path shell_name

    shell_path="${SHELL:-/bin/sh}"
    shell_name="$(basename "$shell_path")"

    case "$shell_name" in
    bash)
        printf '%s\n' "$HOME/.bashrc"
        ;;
    zsh)
        printf '%s\n' "$HOME/.zshrc"
        ;;
    ksh)
        printf '%s\n' "$HOME/.kshrc"
        ;;
    fish)
        printf '%s\n' "$HOME/.config/fish/config.fish"
        ;;
    *)
        printf '%s\n' "$HOME/.profile"
        ;;
    esac
}

update_shell_rc() {
    local key="$1"
    local value="$2"
    local mode="${3:-}"
    local shell_path shell_name shell_rc tmp_file escaped_value section_t line pattern

    shell_path="${SHELL:-/bin/sh}"
    shell_name="$(basename "$shell_path")"
    shell_rc="$(determine_shell_rc)"

    ui_log step "Updating shell rc: $shell_rc"

    mkdir -p "$(dirname "$shell_rc")"
    touch "$shell_rc"

    section_t="# Langtool-CLI Config"

    escaped_value=${value//\\/\\\\}
    escaped_value=${escaped_value//"/\\"/}

    if [ "$mode" = "prepend_path" ]; then
        if [ "$shell_name" = "fish" ]; then
            line="set -gx $key \"$escaped_value\" \$PATH"
            pattern="^[[:space:]]*set[[:space:]]+-gx[[:space:]]+$key([[:space:]]+|$)"
        else
            line="export $key=\"$escaped_value:\$PATH\""
            pattern="^[[:space:]]*export[[:space:]]+$key="
        fi
    else
        if [ "$shell_name" = "fish" ]; then
            line="set -gx $key \"$escaped_value\""
            pattern="^[[:space:]]*set[[:space:]]+-gx[[:space:]]+$key([[:space:]]+|$)"
        else
            line="export $key=\"$escaped_value\""
            pattern="^[[:space:]]*export[[:space:]]+$key="
        fi
    fi

    if grep -qF "$section_t" "$shell_rc"; then
        tmp_file="${shell_rc}.tmp"
        awk -v start="$section_t" -v newline="$line" -v pat="$pattern" '
                        $0 == start {
                                in_block=1
                                print
                                next
                        }
                        {
                                if (in_block && $0 ~ pat) {
                                        if (!updated) {
                                                print newline
                                                updated=1
                                        }
                                        next
                                }
                                print
                        }
                        END {
                                if (in_block) {
                                        if (!updated) {
                                                print newline
                                        }
                                }
                        }
                ' "$shell_rc" >"$tmp_file"
        mv "$tmp_file" "$shell_rc"
    else
        if [ -s "$shell_rc" ]; then
            printf '\n' >>"$shell_rc"
        fi
        {
            printf '%s\n' "$section_t"
            printf '%s\n' "$line"
        } >>"$shell_rc"
    fi

    printf 'Updated shell configuration at %s\n' "$shell_rc"
}

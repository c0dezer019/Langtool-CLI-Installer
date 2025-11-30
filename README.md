# Langtool-CLI Installer

A modern, user-friendly installer for [langtool-cli](https://github.com/c0dezer019/langtool-cli) - a command-line interface for LanguageTool grammar checking.

## Features

- **Multiple Installation Modes**: GTK wizard (GUI), TUI (text-based), or CLI (command-line)
- **Automatic Backend Detection**: Uses the best available UI automatically
- **Smooth Single-Window Experience**: GTK wizard with seamless page transitions
- **Real-time Progress Tracking**: Watch installation progress with live updates
- **Cross-Shell Support**: Works with bash, zsh, fish, and ksh
- **Smart Validation**: Comprehensive checks before installation begins
- **State Persistence**: Navigate back and forth without losing progress

## Quick Start

### GUI Installation (Recommended)

```bash
./install_gui.sh
```

This launches the GTK wizard if available, otherwise falls back to TUI or CLI mode.

### CLI Installation

```bash
./install.sh
```

Traditional command-line installation with interactive prompts.

## Prerequisites

### For GUI Installation (GTK Wizard)

The GTK wizard provides the best user experience with a modern single-window interface.

**Required packages** (Debian/Ubuntu):
```bash
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0
```

**Required packages** (Fedora/RHEL):
```bash
sudo dnf install python3-gobject gtk3
```

**Required packages** (Arch):
```bash
sudo pacman -S python-gobject gtk3
```

If these packages are not installed, the installer will automatically fall back to TUI or CLI mode.

### For TUI Installation

Requires one of:
- `whiptail` (usually pre-installed)
- `dialog`

### For All Installation Modes

- `git` (required)
- `ssh` (optional, only if using SSH clone mode)

## Installation Modes

### GTK Wizard (GUI Mode)

The GTK wizard provides a modern, single-window installation experience:

- **Welcome Page**: Prerequisites check with color-coded status
- **Configuration**: Native file choosers for selecting directories
- **Version Selection**: Fetches available versions from languagetool.org
- **Confirmation**: Review all selections before proceeding
- **Installation**: Real-time progress with detailed logging

**Features:**
- Smooth slide transitions between pages
- Real-time git clone progress parsing
- Inline validation with helpful error messages
- Keyboard shortcuts (Escape = Cancel, Enter = Next)
- No window flickering or repositioning

**Launch:**
```bash
./install_gui.sh
```

### TUI Mode (Text-Based UI)

Uses whiptail or dialog for a text-based interface. Automatically selected if GTK is not available.

**Force TUI mode:**
```bash
UI_BACKEND=tui ./install_gui.sh
```

### CLI Mode (Command-Line)

Traditional command-line interface with text prompts. Always available as fallback.

**Force CLI mode:**
```bash
./install.sh
```
or
```bash
UI_BACKEND=cli ./install_gui.sh
```

## Configuration

### Environment Variables

Configure installation behavior with environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `LT_CLI_DIR` | CLI installation directory | `~/.local/share/Langtool-CLI` |
| `LT_INSTALL_DIR` | LanguageTool data directory | `~/.local/share/LanguageTool` |
| `LT_VER` | LanguageTool version | `latest` |
| `USE_SSH` | Use SSH instead of HTTPS for git clone | not set (uses HTTPS) |
| `LANGTOOL_GIT_TAG` | Git branch/tag to install | `base` |
| `LANGTOOL_DEBUG` | Enable debug mode | not set |
| `UI_BACKEND` | Force specific UI backend | `auto` (auto-detect) |

### Examples

**Custom installation directories:**
```bash
LT_CLI_DIR=/opt/langtool ./install_gui.sh
```

**Use SSH for git clone:**
```bash
USE_SSH=1 ./install_gui.sh
```

**Install specific version:**
```bash
LT_VER=6.8 ./install.sh
```

**Install specific git branch:**
```bash
LANGTOOL_GIT_TAG=v1.0.0 ./install_gui.sh
```

**Non-interactive installation:**
```bash
LT_CLI_DIR=/custom/path LT_INSTALL_DIR=/custom/lt LT_VER=latest ./install.sh
```

## How It Works

1. **Prerequisites Check**: Verifies git (and SSH if needed) are installed
2. **Directory Creation**: Creates installation directories (uses sudo if needed)
3. **Repository Clone**: Clones langtool-cli from GitHub
4. **Shell Configuration**: Updates your shell RC file with environment variables
5. **Symlink Creation**: Creates convenient command symlinks
6. **PATH Update**: Adds bin directory to your PATH

After installation, restart your terminal or run:
```bash
source ~/.bashrc  # or ~/.zshrc, ~/.config/fish/config.fish, etc.
```

Then use the CLI:
```bash
langtool --help
```

## Architecture

The installer uses a modular architecture with a UI abstraction layer:

```
install_gui.sh
  ↓
lib/ui_abstraction.sh (detects best UI backend)
  ↓
  ├─→ lib/ui_gtk.sh → lib/install_gtk_wizard.py (GTK wizard)
  ├─→ lib/ui_tui.sh (whiptail/dialog interface)
  └─→ lib/ui_cli.sh (command-line interface)
      ↓
  Shared bash libraries:
  ├─→ lib/install_state.sh (state management)
  ├─→ lib/version_selector.sh (version fetching)
  ├─→ lib/update_shell_rc.sh (shell configuration)
  └─→ lib/git_progress.sh (git operations)
```

## Troubleshooting

### GTK Wizard Not Available

**Symptom**: Installer falls back to TUI/CLI mode

**Solution**: Install PyGObject:
```bash
# Debian/Ubuntu
sudo apt install python3-gi python3-gi-cairo gir1.2-gtk-3.0

# Fedora/RHEL
sudo dnf install python3-gobject gtk3

# Arch
sudo pacman -S python-gobject gtk3
```

### Git Clone Fails

**Symptom**: "Failed to clone repository" error

**Solutions**:
- Check internet connection
- Try HTTPS mode (default) instead of SSH
- Verify GitHub is accessible from your network

### Permission Denied Creating Directories

**Symptom**: Installation fails when creating directories

**Solution**: The installer will automatically prompt for sudo. Ensure you have sudo access.

Alternatively, choose directories you have write access to (e.g., inside your home directory).

### SSH Clone Fails

**Symptom**: "Permission denied" when using SSH mode

**Solution**:
- Ensure your SSH key is added to GitHub
- Test SSH access: `ssh -T git@github.com`
- Or use HTTPS mode instead (unset `USE_SSH`)

## Development

### Testing

Run syntax checks:
```bash
# Python syntax
python3 -m py_compile lib/install_gtk_wizard.py

# Bash syntax
shellcheck install_gui.sh lib/*.sh
```

Test different modes:
```bash
# Test auto-detection
./install_gui.sh

# Test specific backends
UI_BACKEND=gtk ./install_gui.sh
UI_BACKEND=tui ./install_gui.sh
UI_BACKEND=cli ./install_gui.sh

# Test with debug output
LANGTOOL_DEBUG=1 ./install_gui.sh
```

### File Structure

```
install_gui.sh              # GUI installer entry point
install.sh                  # CLI installer entry point
lib/
  ├── install_gtk_wizard.py # GTK wizard implementation (Python)
  ├── ui_abstraction.sh     # Backend detection
  ├── ui_gtk.sh            # GTK wrapper
  ├── ui_tui.sh            # TUI implementation
  ├── ui_cli.sh            # CLI implementation
  ├── install_state.sh     # State management
  ├── version_selector.sh  # Version fetching
  ├── update_shell_rc.sh   # Shell configuration
  └── git_progress.sh      # Git operations
```

## Contributing

See `CLAUDE.md` for detailed architecture documentation and development guidelines.

## License

This installer is provided as-is for installing langtool-cli.

#!/usr/bin/env python3
"""
GTK Single-Window Installation Wizard for Langtool-CLI
Provides smooth page transitions and integrated progress tracking.
"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GLib, Pango
import os
import sys
import subprocess
import tempfile
import threading
import re

class InstallWizard(Gtk.Window):
    """Main installer wizard window with GtkStack for smooth page transitions."""

    def __init__(self):
        super().__init__(title="Langtool-CLI Installer")

        # Window configuration
        self.set_default_size(600, 450)
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_resizable(False)

        # Page management
        self.current_page = 0
        self.pages = ["welcome", "config", "version", "confirm", "install"]
        self.page_titles = [
            "Welcome",
            "Configuration",
            "Version Selection",
            "Confirmation",
            "Installation"
        ]

        # State file path (get from environment or use temp)
        self.state_file = os.environ.get('STATE_FILE',
                                         f"/tmp/langtool_install_state.{os.getpid()}")
        self.state = {}

        # Widget references for validation and state management
        self.cli_dir_chooser = None
        self.lt_dir_chooser = None
        self.use_ssh_switch = None
        self.ssh_status_label = None
        self.ssh_result_label = None
        self.ssh_available = False
        self.ssh_authenticated = False
        self.error_infobar = None
        self.error_label = None
        self.version_spinner = None
        self.version_listbox = None
        self.version_stack = None
        self.versions_fetched = False
        self.confirm_textview = None
        self.confirm_buffer = None
        self.progressbar = None
        self.status_label = None
        self.log_textview = None
        self.log_buffer = None
        self.install_success = False

        # Build UI
        self.setup_ui()

        # Connect signals
        self.connect("destroy", self.on_window_close)
        self.connect("key-press-event", self.on_key_press)

        # Load existing state if available
        self.load_state_from_file()

        # Apply saved state to widgets
        self.apply_saved_state()

    def setup_ui(self):
        """Build the complete widget hierarchy."""

        # Main container
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(main_box)

        # Header bar
        self.headerbar = Gtk.HeaderBar()
        self.headerbar.set_show_close_button(True)
        self.headerbar.set_title("Langtool-CLI Installer")
        self.headerbar.set_subtitle(f"Step 1 of {len(self.pages)}: {self.page_titles[0]}")
        self.set_titlebar(self.headerbar)

        # Stack for pages
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(250)  # 250ms smooth transitions

        # Add pages (all real implementations now!)
        self.stack.add_named(self.create_welcome_page(), "welcome")  # Real implementation
        self.stack.add_named(self.create_config_page(), "config")  # Real implementation
        self.stack.add_named(self.create_version_page(), "version")  # Real implementation
        self.stack.add_named(self.create_confirm_page(), "confirm")  # Real implementation
        self.stack.add_named(self.create_install_page(), "install")  # Real implementation

        main_box.pack_start(self.stack, True, True, 0)

        # Action bar (buttons)
        action_bar = Gtk.ActionBar()

        # Cancel button (far left)
        self.cancel_button = Gtk.Button(label="Cancel")
        self.cancel_button.connect("clicked", self.on_cancel_clicked)
        action_bar.pack_start(self.cancel_button)

        # Next button (right side)
        self.next_button = Gtk.Button(label="Next →")
        self.next_button.set_size_request(100, -1)  # Minimum width of 100px
        self.next_button.connect("clicked", self.on_next_clicked)
        self.next_button.get_style_context().add_class("suggested-action")
        action_bar.pack_end(self.next_button)

        # Back button (right side, left of Next)
        self.back_button = Gtk.Button(label="← Back")
        self.back_button.set_size_request(100, -1)  # Minimum width of 100px
        self.back_button.connect("clicked", self.on_back_clicked)
        self.back_button.set_sensitive(False)  # Disabled on first page
        action_bar.pack_end(self.back_button)

        main_box.pack_end(action_bar, False, False, 0)

        # Show all widgets
        self.show_all()

    def create_welcome_page(self):
        """Create welcome page with prerequisites check."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(24)
        box.set_margin_end(24)

        # Welcome title
        title = Gtk.Label()
        title.set_markup('<span size="x-large" weight="bold">Welcome to Langtool-CLI Installer</span>')
        title.set_halign(Gtk.Align.CENTER)
        box.pack_start(title, False, False, 12)

        # Description
        description = Gtk.Label()
        description.set_markup(
            "This wizard will guide you through installing <b>langtool-cli</b>,\n"
            "a command-line interface for LanguageTool grammar checking."
        )
        description.set_halign(Gtk.Align.CENTER)
        description.set_justify(Gtk.Justification.CENTER)
        box.pack_start(description, False, False, 0)

        # Separator
        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        box.pack_start(separator, False, False, 12)

        # Check SSH first to set auto-enable state
        ssh_check_result = self.check_ssh()

        # SSH toggle control (compact, above prerequisites)
        ssh_toggle_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        ssh_toggle_box.set_margin_bottom(8)

        ssh_toggle_label = Gtk.Label(label="Git Clone Method:", xalign=0)
        ssh_toggle_label.set_tooltip_text(
            "Toggle to switch between SSH and HTTPS for cloning\n"
            "SSH requires SSH key configured with GitHub"
        )
        ssh_toggle_box.pack_start(ssh_toggle_label, False, False, 0)

        # Add small spacer
        spacer_box = Gtk.Box()
        ssh_toggle_box.pack_start(spacer_box, True, True, 0)

        # Status label (shows SSH/HTTPS)
        self.ssh_status_label = Gtk.Label()
        # Now check environment AFTER check_ssh() has potentially set it
        ssh_enabled = os.environ.get('USE_SSH') == '1'
        if ssh_enabled:
            self.ssh_status_label.set_markup('<span foreground="#4CAF50" size="small" weight="bold">SSH</span>')
        else:
            self.ssh_status_label.set_markup('<span foreground="#888888" size="small">HTTPS</span>')
        self.ssh_status_label.set_width_chars(6)
        self.ssh_status_label.set_xalign(1)
        ssh_toggle_box.pack_start(self.ssh_status_label, False, False, 0)

        # Toggle switch (smaller)
        self.use_ssh_switch = Gtk.Switch()
        self.use_ssh_switch.set_valign(Gtk.Align.CENTER)
        self.use_ssh_switch.set_tooltip_text("Toggle between SSH and HTTPS")
        self.use_ssh_switch.set_active(ssh_enabled)  # This should now be ON if auto-enabled

        # Disable toggle if SSH is not available
        if not self.ssh_available:
            self.use_ssh_switch.set_sensitive(False)
            self.use_ssh_switch.set_tooltip_text("SSH is not installed on this system")

        ssh_toggle_box.pack_start(self.use_ssh_switch, False, False, 0)

        box.pack_start(ssh_toggle_box, False, False, 0)

        # Prerequisites frame
        prereq_label = Gtk.Label()
        prereq_label.set_markup("<b>Prerequisites Check</b>")
        prereq_label.set_halign(Gtk.Align.START)
        box.pack_start(prereq_label, False, False, 0)

        prereq_frame = Gtk.Frame()
        prereq_frame.set_shadow_type(Gtk.ShadowType.IN)

        prereq_grid = Gtk.Grid()
        prereq_grid.set_row_spacing(12)
        prereq_grid.set_column_spacing(12)
        prereq_grid.set_margin_top(12)
        prereq_grid.set_margin_bottom(12)
        prereq_grid.set_margin_start(12)
        prereq_grid.set_margin_end(12)

        # Check git
        git_label = Gtk.Label(label="Git:", xalign=0)
        git_label.set_width_chars(10)
        git_status = self.check_git()
        git_result = Gtk.Label(xalign=0)
        git_result.set_markup(git_status)
        git_result.set_selectable(True)

        prereq_grid.attach(git_label, 0, 0, 1, 1)
        prereq_grid.attach(git_result, 1, 0, 1, 1)

        # Display SSH status (already checked above)
        ssh_label = Gtk.Label(label="SSH:", xalign=0)
        ssh_label.set_width_chars(10)
        self.ssh_result_label = Gtk.Label(xalign=0)
        self.ssh_result_label.set_markup(ssh_check_result)
        self.ssh_result_label.set_selectable(True)
        # Enable clickable links
        self.ssh_result_label.set_use_markup(True)

        prereq_grid.attach(ssh_label, 0, 1, 1, 1)
        prereq_grid.attach(self.ssh_result_label, 1, 1, 1, 1)

        prereq_frame.add(prereq_grid)
        box.pack_start(prereq_frame, False, False, 0)

        # Update labels and SSH status when switch changes
        def on_ssh_switch_toggled(switch, _):
            if switch.get_active():
                self.ssh_status_label.set_markup('<span foreground="#4CAF50" size="small" weight="bold">SSH</span>')
                os.environ['USE_SSH'] = '1'
                # Update SSH status in prerequisites
                if self.ssh_result_label:
                    self.ssh_result_label.set_markup('<span foreground="#4CAF50">✓ Enabled (SSH mode)</span>')
            else:
                self.ssh_status_label.set_markup('<span foreground="#888888" size="small">HTTPS</span>')
                if 'USE_SSH' in os.environ:
                    del os.environ['USE_SSH']
                # Update SSH status in prerequisites
                if self.ssh_result_label:
                    # Show "Disabled" when toggle is off
                    if self.ssh_authenticated:
                        # SSH is available and authenticated, but user disabled it
                        self.ssh_result_label.set_markup('<span foreground="#888888">○ Disabled (using HTTPS)</span>')
                    elif self.ssh_available:
                        # SSH is available but not authenticated
                        self.ssh_result_label.set_markup('<span foreground="#888888">○ Disabled (using HTTPS)</span>')
                    else:
                        # SSH is not available
                        self.ssh_result_label.set_markup('<span foreground="#888888">✗ Unavailable - <a href="https://docs.github.com/en/authentication/connecting-to-github-with-ssh">Setup Guide</a></span>')

        self.use_ssh_switch.connect("notify::active", on_ssh_switch_toggled)

        # Info box
        info_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        info_box.set_margin_top(12)

        info_icon = Gtk.Image.new_from_icon_name("dialog-information", Gtk.IconSize.BUTTON)
        info_box.pack_start(info_icon, False, False, 0)

        info_text = Gtk.Label()
        info_text.set_markup(
            '<span size="small">Toggle <b>Git Clone Method</b> to switch between SSH and HTTPS.\n'
            'Click <b>Next</b> when ready to begin installation.</span>'
        )
        info_text.set_halign(Gtk.Align.START)
        info_text.set_line_wrap(True)
        info_box.pack_start(info_text, False, False, 0)

        box.pack_start(info_box, False, False, 0)

        # Spacer to push content up
        spacer = Gtk.Label()
        box.pack_start(spacer, True, True, 0)

        return box

    def check_git(self):
        """Check if git is installed and return status markup."""
        try:
            result = subprocess.run(
                ['git', '--version'],
                capture_output=True,
                text=True,
                timeout=2
            )

            if result.returncode == 0:
                version = result.stdout.strip()
                return f'<span foreground="#4CAF50">✓</span> {version}'
            else:
                return '<span foreground="#F44336">✗ Not found</span>'

        except FileNotFoundError:
            return '<span foreground="#F44336">✗ Not installed</span>'
        except Exception as e:
            return f'<span foreground="#FF9800">⚠ Error: {str(e)}</span>'

    def check_ssh(self):
        """Check if SSH is available and configured. Auto-enables SSH if authenticated."""
        try:
            # Check if ssh command exists
            result = subprocess.run(
                ['command', '-v', 'ssh'],
                capture_output=True,
                text=True,
                shell=True,
                timeout=2
            )

            if result.returncode != 0:
                self.ssh_available = False
                self.ssh_authenticated = False
                return '<span foreground="#888888">✗ Unavailable - <a href="https://docs.github.com/en/authentication/connecting-to-github-with-ssh">Setup Guide</a></span>'

            self.ssh_available = True

            # Try to check SSH authentication to GitHub
            # This is a quick test - won't actually connect
            result = subprocess.run(
                ['ssh', '-T', 'git@github.com'],
                capture_output=True,
                text=True,
                timeout=5
            )

            # SSH to GitHub returns exit code 1 on successful auth with message
            # "Hi username! You've successfully authenticated..."
            if 'successfully authenticated' in result.stderr.lower():
                self.ssh_authenticated = True
                # Auto-enable SSH if not explicitly set (smart default)
                if 'USE_SSH' not in os.environ:
                    os.environ['USE_SSH'] = '1'
                    return '<span foreground="#4CAF50">✓ Authenticated (SSH auto-enabled)</span>'
                else:
                    return '<span foreground="#4CAF50">✓ Authenticated</span>'
            elif 'permission denied' in result.stderr.lower():
                self.ssh_authenticated = False
                return '<span foreground="#FF9800">⚠ Authentication required</span>'
            else:
                self.ssh_authenticated = False
                return '<span foreground="#2196F3">○ Available</span>'

        except subprocess.TimeoutExpired:
            self.ssh_authenticated = False
            return '<span foreground="#FF9800">⚠ Connection timeout</span>'
        except Exception as e:
            self.ssh_authenticated = False
            return f'<span foreground="#888888">○ {str(e)[:30]}</span>'

    def create_config_page(self):
        """Create configuration page with directory choosers."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(24)
        box.set_margin_end(24)

        # Error infobar (hidden by default)
        self.error_infobar = Gtk.InfoBar()
        self.error_infobar.set_message_type(Gtk.MessageType.ERROR)
        self.error_infobar.set_show_close_button(True)
        self.error_infobar.connect("response", lambda w, r: w.set_revealed(False))

        content = self.error_infobar.get_content_area()
        self.error_label = Gtk.Label()
        self.error_label.set_line_wrap(True)
        content.add(self.error_label)

        self.error_infobar.set_revealed(False)
        box.pack_start(self.error_infobar, False, False, 0)

        # Grid for form fields
        grid = Gtk.Grid()
        grid.set_row_spacing(12)
        grid.set_column_spacing(12)
        grid.set_halign(Gtk.Align.CENTER)
        grid.set_valign(Gtk.Align.CENTER)

        # CLI Directory chooser
        label1 = Gtk.Label(label="CLI Installation Directory:", xalign=0)
        label1.set_tooltip_text(
            "Directory where langtool-cli will be installed\n"
            "Default: ~/.local/share/Langtool-CLI"
        )
        self.cli_dir_chooser = Gtk.FileChooserButton(
            title="Select CLI Directory",
            action=Gtk.FileChooserAction.SELECT_FOLDER
        )
        self.cli_dir_chooser.set_tooltip_text("Click to browse and select a directory")

        # Set default path - ensure parent exists
        default_cli_dir = os.path.expanduser("~/.local/share/Langtool-CLI")
        parent_dir = os.path.dirname(default_cli_dir)

        # Create parent directory if it doesn't exist
        if not os.path.exists(parent_dir):
            try:
                os.makedirs(parent_dir, exist_ok=True)
            except:
                pass

        if os.path.exists(parent_dir):
            self.cli_dir_chooser.set_filename(default_cli_dir)
        else:
            self.cli_dir_chooser.set_current_folder(os.path.expanduser("~"))

        self.cli_dir_chooser.set_width_chars(40)

        # LanguageTool Directory chooser
        label2 = Gtk.Label(label="LanguageTool Directory:", xalign=0)
        label2.set_tooltip_text(
            "Directory where LanguageTool data will be stored\n"
            "Default: ~/.local/share/LanguageTool"
        )
        self.lt_dir_chooser = Gtk.FileChooserButton(
            title="Select LanguageTool Directory",
            action=Gtk.FileChooserAction.SELECT_FOLDER
        )
        self.lt_dir_chooser.set_tooltip_text("Click to browse and select a directory")

        # Set default path - ensure parent exists
        default_lt_dir = os.path.expanduser("~/.local/share/LanguageTool")
        parent_dir = os.path.dirname(default_lt_dir)

        # Create parent directory if it doesn't exist
        if not os.path.exists(parent_dir):
            try:
                os.makedirs(parent_dir, exist_ok=True)
            except:
                pass

        if os.path.exists(parent_dir):
            self.lt_dir_chooser.set_filename(default_lt_dir)
        else:
            self.lt_dir_chooser.set_current_folder(os.path.expanduser("~"))

        self.lt_dir_chooser.set_width_chars(40)

        # Add to grid
        grid.attach(label1, 0, 0, 1, 1)
        grid.attach(self.cli_dir_chooser, 1, 0, 1, 1)
        grid.attach(label2, 0, 1, 1, 1)
        grid.attach(self.lt_dir_chooser, 1, 1, 1, 1)

        box.pack_start(grid, True, False, 0)

        return box

    def create_version_page(self):
        """Create version selection page with async fetch."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(24)
        box.set_margin_end(24)

        # Title label
        title = Gtk.Label()
        title.set_markup("<b>Select LanguageTool Version</b>")
        title.set_halign(Gtk.Align.START)
        box.pack_start(title, False, False, 0)

        # Stack to switch between spinner and list
        self.version_stack = Gtk.Stack()
        self.version_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.version_stack.set_transition_duration(300)

        # Loading view (spinner)
        loading_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        loading_box.set_valign(Gtk.Align.CENTER)
        loading_box.set_halign(Gtk.Align.CENTER)

        self.version_spinner = Gtk.Spinner()
        self.version_spinner.set_size_request(48, 48)
        loading_box.pack_start(self.version_spinner, False, False, 0)

        loading_label = Gtk.Label(label="Fetching available versions...")
        loading_label.get_style_context().add_class("dim-label")
        loading_box.pack_start(loading_label, False, False, 0)

        self.version_stack.add_named(loading_box, "loading")

        # List view (versions)
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_size_request(400, 300)

        self.version_listbox = Gtk.ListBox()
        self.version_listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.version_listbox.set_activate_on_single_click(True)
        scrolled.add(self.version_listbox)

        self.version_stack.add_named(scrolled, "list")

        box.pack_start(self.version_stack, True, True, 0)

        return box

    def create_confirm_page(self):
        """Create confirmation page with installation summary."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(24)
        box.set_margin_end(24)

        # Title label
        title = Gtk.Label()
        title.set_markup("<big><b>Confirm Installation</b></big>")
        title.set_halign(Gtk.Align.START)
        box.pack_start(title, False, False, 0)

        # Info label
        info = Gtk.Label(label="Please review your selections before proceeding:")
        info.set_halign(Gtk.Align.START)
        info.get_style_context().add_class("dim-label")
        box.pack_start(info, False, False, 0)

        # Scrolled window for summary text
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_shadow_type(Gtk.ShadowType.IN)
        scrolled.set_size_request(500, 250)

        # TextView for summary (read-only)
        self.confirm_textview = Gtk.TextView()
        self.confirm_textview.set_editable(False)
        self.confirm_textview.set_cursor_visible(False)
        self.confirm_textview.set_wrap_mode(Gtk.WrapMode.WORD)
        self.confirm_textview.set_left_margin(12)
        self.confirm_textview.set_right_margin(12)
        self.confirm_textview.set_top_margin(12)
        self.confirm_textview.set_bottom_margin(12)

        # Use monospace font for alignment
        font_desc = Pango.FontDescription("Monospace 10")
        self.confirm_textview.override_font(font_desc)

        self.confirm_buffer = self.confirm_textview.get_buffer()
        scrolled.add(self.confirm_textview)

        box.pack_start(scrolled, True, True, 0)

        # Warning label
        warning = Gtk.Label()
        warning.set_markup('<span foreground="#F57C00">Click <b>Install</b> to begin the installation process.</span>')
        warning.set_halign(Gtk.Align.START)
        box.pack_start(warning, False, False, 0)

        return box

    def create_install_page(self):
        """Create installation page with real-time progress."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        box.set_margin_top(24)
        box.set_margin_bottom(24)
        box.set_margin_start(24)
        box.set_margin_end(24)

        # Title label
        title = Gtk.Label()
        title.set_markup("<big><b>Installing Langtool-CLI</b></big>")
        title.set_halign(Gtk.Align.START)
        box.pack_start(title, False, False, 0)

        # Progress bar
        self.progressbar = Gtk.ProgressBar()
        self.progressbar.set_show_text(True)
        self.progressbar.set_text("0%")
        box.pack_start(self.progressbar, False, False, 0)

        # Status label
        self.status_label = Gtk.Label(label="Ready to install...")
        self.status_label.set_halign(Gtk.Align.START)
        self.status_label.set_line_wrap(True)
        box.pack_start(self.status_label, False, False, 0)

        # Separator
        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        box.pack_start(separator, False, False, 6)

        # Log viewer (scrollable)
        log_label = Gtk.Label(label="Installation Log:")
        log_label.set_halign(Gtk.Align.START)
        log_label.get_style_context().add_class("dim-label")
        box.pack_start(log_label, False, False, 0)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_shadow_type(Gtk.ShadowType.IN)
        scrolled.set_size_request(500, 200)

        self.log_textview = Gtk.TextView()
        self.log_textview.set_editable(False)
        self.log_textview.set_cursor_visible(False)
        self.log_textview.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.log_textview.set_left_margin(8)
        self.log_textview.set_right_margin(8)
        self.log_textview.set_top_margin(8)
        self.log_textview.set_bottom_margin(8)

        font_desc = Pango.FontDescription("Monospace 9")
        self.log_textview.override_font(font_desc)

        self.log_buffer = self.log_textview.get_buffer()
        scrolled.add(self.log_textview)

        box.pack_start(scrolled, True, True, 0)

        return box

    def update_navigation(self):
        """Update button states and header based on current page."""

        # Update header subtitle
        self.headerbar.set_subtitle(
            f"Step {self.current_page + 1} of {len(self.pages)}: {self.page_titles[self.current_page]}"
        )

        # Update Back button
        self.back_button.set_sensitive(self.current_page > 0)

        # Update Next button label
        if self.current_page == len(self.pages) - 2:  # Confirmation page
            self.next_button.set_label("Install")
        elif self.current_page == len(self.pages) - 1:  # Installation page
            self.next_button.set_label("Finish")
        else:
            self.next_button.set_label("Next →")

    def validate_current_page(self):
        """
        Validate current page before allowing navigation forward.
        Returns True if validation passes, False otherwise.
        """
        page_name = self.pages[self.current_page]

        if page_name == "config":
            return self.validate_config_page()

        # Other pages pass by default (for now)
        return True

    def validate_config_page(self):
        """Validate configuration page inputs."""
        cli_dir = self.cli_dir_chooser.get_filename()
        lt_dir = self.lt_dir_chooser.get_filename()

        # Check if directories are selected
        if not cli_dir or not lt_dir:
            self.show_error("Please select both installation directories.\n\n"
                          "Use the browse buttons to choose where to install.")
            return False

        # Check if paths are absolute
        if not os.path.isabs(cli_dir) or not os.path.isabs(lt_dir):
            self.show_error("Directory paths must be absolute paths.\n\n"
                          f"CLI Directory: {cli_dir}\n"
                          f"LT Directory: {lt_dir}")
            return False

        # Check if same directory
        if cli_dir == lt_dir:
            self.show_error("CLI and LanguageTool directories must be different.\n\n"
                          "Please choose separate directories for each component.")
            return False

        # Check if one is subdirectory of the other
        if cli_dir.startswith(lt_dir + os.sep) or lt_dir.startswith(cli_dir + os.sep):
            self.show_error("One directory cannot be a subdirectory of the other.\n\n"
                          "Please choose independent directories.")
            return False

        # Check if parent directories exist
        cli_parent = os.path.dirname(cli_dir)
        lt_parent = os.path.dirname(lt_dir)

        if not os.path.exists(cli_parent):
            self.show_error(f"Parent directory does not exist:\n{cli_parent}\n\n"
                          "Please choose a location within an existing directory.")
            return False

        if not os.path.exists(lt_parent):
            self.show_error(f"Parent directory does not exist:\n{lt_parent}\n\n"
                          "Please choose a location within an existing directory.")
            return False

        # Check write permissions (show warning but allow)
        warnings = []
        if not os.access(cli_parent, os.W_OK):
            warnings.append(f"• {cli_parent}")

        if not os.access(lt_parent, os.W_OK):
            warnings.append(f"• {lt_parent}")

        if warnings:
            self.show_warning(
                "The following directories may require elevated permissions:\n\n" +
                "\n".join(warnings) +
                "\n\nYou may be prompted for sudo password during installation."
            )
        else:
            # Hide any previous errors/warnings
            if self.error_infobar:
                self.error_infobar.set_revealed(False)

        return True

    def show_error(self, message):
        """Show error message on current page."""
        if self.error_infobar and self.error_label:
            self.error_label.set_text(message)
            self.error_infobar.set_message_type(Gtk.MessageType.ERROR)
            self.error_infobar.set_revealed(True)

    def show_warning(self, message):
        """Show warning message on current page."""
        if self.error_infobar and self.error_label:
            self.error_label.set_text(message)
            self.error_infobar.set_message_type(Gtk.MessageType.WARNING)
            self.error_infobar.set_revealed(True)

    def save_current_page_state(self):
        """Save state for current page."""
        page_name = self.pages[self.current_page]

        if page_name == "welcome":
            self.save_welcome_state()
        elif page_name == "config":
            self.save_config_state()
        elif page_name == "version":
            self.save_version_state()

    def save_welcome_state(self):
        """Save welcome page state to file."""
        use_ssh = "1" if self.use_ssh_switch.get_active() else "0"
        self.save_state_value("USE_SSH", use_ssh)

    def save_config_state(self):
        """Save configuration page state to file."""
        cli_dir = self.cli_dir_chooser.get_filename()
        lt_dir = self.lt_dir_chooser.get_filename()

        if cli_dir:
            self.save_state_value("LT_CLI_DIR", cli_dir)
        if lt_dir:
            self.save_state_value("LT_INSTALL_DIR", lt_dir)

    def save_state_value(self, key, value):
        """Save a key-value pair to state file (bash-compatible format)."""
        self.state[key] = value

        # Write to file in bash-compatible format
        try:
            # Read existing state
            existing = {}
            if os.path.exists(self.state_file):
                with open(self.state_file, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if '=' in line and not line.startswith('#'):
                            k, v = line.split('=', 1)
                            existing[k] = v

            # Update with new value
            existing[key] = value

            # Write back
            with open(self.state_file, 'w') as f:
                for k, v in existing.items():
                    f.write(f"{k}={v}\n")
        except Exception as e:
            print(f"Warning: Could not save state: {e}", file=sys.stderr)

    def load_state_from_file(self):
        """Load state from file and apply to widgets."""
        if not os.path.exists(self.state_file):
            return

        try:
            with open(self.state_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if '=' in line and not line.startswith('#'):
                        key, value = line.split('=', 1)
                        self.state[key] = value
        except Exception as e:
            print(f"Warning: Could not load state: {e}", file=sys.stderr)

    def apply_saved_state(self):
        """Apply saved state to widgets (called after widgets are created)."""
        # Apply CLI directory if saved
        if "LT_CLI_DIR" in self.state and self.cli_dir_chooser:
            cli_dir = self.state["LT_CLI_DIR"]
            if os.path.exists(os.path.dirname(cli_dir)):
                self.cli_dir_chooser.set_filename(cli_dir)

        # Apply LT directory if saved
        if "LT_INSTALL_DIR" in self.state and self.lt_dir_chooser:
            lt_dir = self.state["LT_INSTALL_DIR"]
            if os.path.exists(os.path.dirname(lt_dir)):
                self.lt_dir_chooser.set_filename(lt_dir)

        # Apply SSH toggle if saved
        if "USE_SSH" in self.state and self.use_ssh_switch:
            use_ssh = self.state["USE_SSH"] == "1"
            self.use_ssh_switch.set_active(use_ssh)

    def fetch_versions_async(self):
        """Fetch available LanguageTool versions asynchronously."""
        # Show spinner
        self.version_spinner.start()
        self.version_stack.set_visible_child_name("loading")

        # Run fetch in background thread
        thread = threading.Thread(target=self._fetch_versions_worker, daemon=True)
        thread.start()

    def _fetch_versions_worker(self):
        """Worker thread to fetch versions from bash script."""
        try:
            # Get script directory
            script_dir = os.path.dirname(os.path.abspath(__file__))

            # Call bash version_selector.sh fetch_versions function
            result = subprocess.run(
                ['bash', '-c', f'source "{script_dir}/version_selector.sh"; fetch_versions'],
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0 and result.stdout.strip():
                versions = result.stdout.strip().split('\n')
                # Filter out empty/invalid versions
                versions = [v for v in versions if v and v != "latest"]
                # Remove the first numerical version since it's the same as "latest"
                if versions:
                    versions = versions[1:]
                # Add "latest" at the beginning
                versions = ["latest"] + versions
            else:
                # Fallback to just "latest" if fetch fails
                versions = ["latest"]

        except Exception as e:
            print(f"Error fetching versions: {e}", file=sys.stderr)
            versions = ["latest"]

        # Update UI from main thread
        GLib.idle_add(self._populate_version_list, versions)

    def _populate_version_list(self, versions):
        """Populate version list (called from main thread)."""
        # Clear existing items
        for child in self.version_listbox.get_children():
            self.version_listbox.remove(child)

        # Add version items
        for version in versions:
            row = Gtk.ListBoxRow()

            # Create box with radio button appearance
            hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            hbox.set_margin_start(12)
            hbox.set_margin_end(12)
            hbox.set_margin_top(8)
            hbox.set_margin_bottom(8)

            # Version label
            label = Gtk.Label(label=version, xalign=0)
            hbox.pack_start(label, True, True, 0)

            # Badge for "latest"
            if version == "latest":
                badge = Gtk.Label()
                badge.set_markup('<span size="small" weight="bold" foreground="#2196F3">RECOMMENDED</span>')
                hbox.pack_end(badge, False, False, 0)

            row.add(hbox)
            row.version = version  # Store version in row for later retrieval
            self.version_listbox.add(row)

        self.version_listbox.show_all()

        # Select first item (latest) by default
        first_row = self.version_listbox.get_row_at_index(0)
        if first_row:
            self.version_listbox.select_row(first_row)

        # Apply saved selection if exists
        if "LT_VER" in self.state:
            saved_version = self.state["LT_VER"]
            for row in self.version_listbox.get_children():
                if hasattr(row, 'version') and row.version == saved_version:
                    self.version_listbox.select_row(row)
                    break

        # Stop spinner and switch to list
        self.version_spinner.stop()
        self.version_stack.set_visible_child_name("list")
        self.versions_fetched = True

    def save_version_state(self):
        """Save selected version to state."""
        selected_row = self.version_listbox.get_selected_row()
        if selected_row and hasattr(selected_row, 'version'):
            version = selected_row.version
            self.save_state_value("LT_VER", version)

    def get_selected_version(self):
        """Get currently selected version."""
        selected_row = self.version_listbox.get_selected_row()
        if selected_row and hasattr(selected_row, 'version'):
            return selected_row.version
        return "latest"

    def update_confirmation_summary(self):
        """Update the confirmation page summary with current selections."""
        if not self.confirm_buffer:
            return

        # Gather all selections
        cli_dir = self.cli_dir_chooser.get_filename() if self.cli_dir_chooser else "Not set"
        lt_dir = self.lt_dir_chooser.get_filename() if self.lt_dir_chooser else "Not set"
        version = self.get_selected_version()

        # Check environment for git mode
        use_ssh = os.environ.get('USE_SSH', '')
        git_mode = "SSH" if use_ssh else "HTTPS"

        # Get git tag/branch if set
        git_tag = os.environ.get('LANGTOOL_GIT_TAG', 'base')

        # Expand paths for display
        cli_dir = os.path.expanduser(cli_dir) if cli_dir else "Not set"
        lt_dir = os.path.expanduser(lt_dir) if lt_dir else "Not set"

        # Build summary text
        summary = []
        summary.append("=" * 60)
        summary.append("INSTALLATION SUMMARY")
        summary.append("=" * 60)
        summary.append("")
        summary.append("Installation Directories:")
        summary.append(f"  CLI Directory:        {cli_dir}")
        summary.append(f"  LanguageTool Directory: {lt_dir}")
        summary.append("")
        summary.append("LanguageTool Configuration:")
        summary.append(f"  Version:              {version}")
        summary.append("")
        summary.append("Git Configuration:")
        summary.append(f"  Clone Method:         {git_mode}")
        summary.append(f"  Branch/Tag:           {git_tag}")
        summary.append("")
        summary.append("Installation Steps:")
        summary.append("  1. Create installation directories")
        summary.append("  2. Clone langtool-cli repository")
        summary.append("  3. Update shell configuration files")
        summary.append("  4. Create command symlinks")
        summary.append("  5. Add to PATH")
        summary.append("")
        summary.append("=" * 60)
        summary.append("")
        summary.append("Press 'Install' to begin the installation.")
        summary.append("Press 'Back' to modify your selections.")

        # Set text in buffer
        self.confirm_buffer.set_text("\n".join(summary))

    def start_installation(self):
        """Start the installation process."""
        # Disable navigation during installation
        self.back_button.set_sensitive(False)
        self.cancel_button.set_sensitive(False)
        self.next_button.set_sensitive(False)

        # Reset progress
        self.update_progress(0.0, "Starting installation...")
        self.append_log("=" * 60)
        self.append_log("Installation started")
        self.append_log("=" * 60)

        # Run installation in background thread
        thread = threading.Thread(target=self._install_worker, daemon=True)
        thread.start()

    def _install_worker(self):
        """Worker thread to perform installation."""
        try:
            # Get configuration
            cli_dir = self.cli_dir_chooser.get_filename()
            lt_dir = self.lt_dir_chooser.get_filename()
            version = self.get_selected_version()

            # Step 1: Create directories (0% -> 20%)
            self.update_progress(0.0, "Creating directories...")
            self.append_log("\n[1/5] Creating directories...")

            if not self.create_directory(cli_dir):
                raise Exception(f"Failed to create CLI directory: {cli_dir}")
            self.append_log(f"  ✓ Created {cli_dir}")

            if not self.create_directory(lt_dir):
                raise Exception(f"Failed to create LanguageTool directory: {lt_dir}")
            self.append_log(f"  ✓ Created {lt_dir}")

            self.update_progress(0.2, "Directories created")

            # Step 2: Clone repository (20% -> 70%)
            self.update_progress(0.2, "Cloning repository...")
            self.append_log("\n[2/5] Cloning langtool-cli repository...")

            if not self.clone_repository(cli_dir):
                raise Exception("Failed to clone repository")

            self.update_progress(0.7, "Repository cloned")

            # Step 3: Update shell RC (70% -> 85%)
            self.update_progress(0.7, "Updating shell configuration...")
            self.append_log("\n[3/5] Updating shell configuration...")

            if not self.update_shell_rc(cli_dir, lt_dir, version):
                raise Exception("Failed to update shell configuration")
            self.append_log("  ✓ Shell configuration updated")

            self.update_progress(0.85, "Shell configuration updated")

            # Step 4: Create symlinks (85% -> 95%)
            self.update_progress(0.85, "Creating symlinks...")
            self.append_log("\n[4/5] Creating command symlinks...")

            if not self.create_symlinks(cli_dir):
                raise Exception("Failed to create symlinks")
            self.append_log("  ✓ Symlinks created")

            self.update_progress(0.95, "Symlinks created")

            # Step 5: Update PATH (95% -> 100%)
            self.update_progress(0.95, "Updating PATH...")
            self.append_log("\n[5/5] Adding to PATH...")

            if not self.update_path(cli_dir):
                raise Exception("Failed to update PATH")
            self.append_log("  ✓ PATH updated")

            self.update_progress(1.0, "Installation complete!")

            # Success
            self.append_log("\n" + "=" * 60)
            self.append_log("Installation completed successfully!")
            self.append_log("=" * 60)
            self.install_success = True

            # Show completion dialog
            GLib.idle_add(self.show_completion_dialog)

        except Exception as e:
            # Error
            error_msg = str(e)
            self.append_log(f"\n" + "=" * 60)
            self.append_log(f"✗ ERROR: {error_msg}")
            self.append_log("=" * 60)
            self.append_log("\nInstallation failed. Please check the error above.")
            self.append_log("You can go back and try again, or cancel the installation.")

            self.update_progress(0.0, f"Installation failed")
            self.install_success = False
            GLib.idle_add(self.show_error_dialog, error_msg)

    def create_directory(self, path):
        """Create directory, using sudo if needed."""
        try:
            # If directory already exists, that's fine
            if os.path.exists(path) and os.path.isdir(path):
                self.append_log(f"  ✓ Directory already exists: {path}")
                return True

            os.makedirs(path, exist_ok=True)
            return True
        except PermissionError:
            # Try with sudo
            self.append_log(f"  Permission denied, requesting sudo access...")
            try:
                result = subprocess.run(
                    ['sudo', 'mkdir', '-p', path],
                    capture_output=True,
                    text=True,
                    timeout=60  # Give user time to enter password
                )
                if result.returncode == 0:
                    self.append_log(f"  ✓ Created with sudo: {path}")
                    return True
                else:
                    self.append_log(f"  ✗ Sudo failed: {result.stderr}")
                    return False
            except subprocess.TimeoutExpired:
                self.append_log(f"  ✗ Sudo timeout (no password entered?)")
                return False
        except Exception as e:
            self.append_log(f"  ✗ Error: {str(e)}")
            return False

    def clone_repository(self, cli_dir):
        """Clone git repository with real-time progress."""
        try:
            # Determine git URL
            if os.environ.get('USE_SSH'):
                git_url = "git@github.com:c0dezer019/Langtool-CLI.git"
            else:
                git_url = "https://github.com/c0dezer019/Langtool-CLI.git"

            git_tag = os.environ.get('LANGTOOL_GIT_TAG', 'base')

            # Check if directory already exists
            if os.path.exists(cli_dir):
                if os.path.isdir(cli_dir) and os.listdir(cli_dir):
                    self.append_log(f"  Directory exists and is not empty: {cli_dir}")
                    self.append_log(f"  Removing existing installation...")

                    import shutil
                    try:
                        shutil.rmtree(cli_dir)
                        self.append_log(f"  ✓ Removed existing directory")
                    except PermissionError:
                        self.append_log(f"  Permission denied, using sudo...")
                        result = subprocess.run(
                            ['sudo', 'rm', '-rf', cli_dir],
                            timeout=60
                        )
                        if result.returncode == 0:
                            self.append_log(f"  ✓ Removed with sudo")
                        else:
                            raise Exception("Failed to remove existing directory")

            # Clone with progress tracking
            self.append_log(f"  Cloning from {git_url} (branch: {git_tag})...")

            process = subprocess.Popen(
                ['git', '-c', 'advice.detachedHead=0', '-c', 'core.autocrlf=false',
                 'clone', '--progress', '--branch', git_tag, '--depth', '1',
                 git_url, cli_dir],
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1
            )

            # Parse git output for progress
            for line in iter(process.stdout.readline, ''):
                if not line:
                    break

                # Look for percentage in git output
                match = re.search(r'(\d+)%', line)
                if match:
                    percentage = int(match.group(1))
                    # Scale to 20-70% range
                    fraction = 0.2 + (percentage / 100.0 * 0.5)
                    self.update_progress(fraction, f"Cloning: {percentage}%")

                # Log significant messages
                if 'Receiving objects' in line or 'Resolving deltas' in line:
                    self.append_log(f"  {line.strip()}")

            process.wait()

            if process.returncode == 0:
                self.append_log("  ✓ Repository cloned successfully")
                return True
            else:
                self.append_log(f"  ✗ Git clone failed with exit code {process.returncode}")
                return False

        except Exception as e:
            self.append_log(f"  ✗ Clone error: {str(e)}")
            return False

    def update_shell_rc(self, cli_dir, lt_dir, version):
        """Update shell RC files."""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))

            # Call bash update_shell_rc function
            commands = [
                f'source "{script_dir}/update_shell_rc.sh"',
                f'update_shell_rc "LT_CLI_DIR" "{cli_dir}"',
                f'update_shell_rc "LT_INSTALL_DIR" "{lt_dir}"',
                f'update_shell_rc "LT_VER" "{version}"'
            ]

            result = subprocess.run(
                ['bash', '-c', '; '.join(commands)],
                capture_output=True,
                text=True
            )

            return result.returncode == 0

        except Exception as e:
            self.append_log(f"  Error: {str(e)}")
            return False

    def create_symlinks(self, cli_dir):
        """Create command symlinks."""
        try:
            bin_dir = os.path.join(cli_dir, 'bin')
            os.makedirs(bin_dir, exist_ok=True)

            # Create symlinks
            langtool_src = os.path.join(cli_dir, 'langtool')
            langtool_link = os.path.join(bin_dir, 'langtool')

            if os.path.exists(langtool_link):
                os.remove(langtool_link)
            os.symlink(langtool_src, langtool_link)

            uninstall_src = os.path.join(cli_dir, 'lib', 'uninstall.sh')
            uninstall_link = os.path.join(bin_dir, 'uninstall')

            if os.path.exists(uninstall_link):
                os.remove(uninstall_link)
            os.symlink(uninstall_src, uninstall_link)

            return True

        except Exception as e:
            self.append_log(f"  Error: {str(e)}")
            return False

    def update_path(self, cli_dir):
        """Update PATH in shell RC."""
        try:
            script_dir = os.path.dirname(os.path.abspath(__file__))
            bin_dir = os.path.join(cli_dir, 'bin')

            result = subprocess.run(
                ['bash', '-c', f'source "{script_dir}/update_shell_rc.sh"; update_shell_rc "PATH" "{bin_dir}" prepend_path'],
                capture_output=True,
                text=True
            )

            return result.returncode == 0

        except Exception as e:
            self.append_log(f"  Error: {str(e)}")
            return False

    def update_progress(self, fraction, text):
        """Update progress bar (thread-safe)."""
        GLib.idle_add(self._update_progress_ui, fraction, text)

    def _update_progress_ui(self, fraction, text):
        """Update progress bar on main thread."""
        if self.progressbar:
            self.progressbar.set_fraction(fraction)
            self.progressbar.set_text(f"{int(fraction * 100)}%")
        if self.status_label:
            self.status_label.set_text(text)
        return False

    def append_log(self, text):
        """Append text to log viewer (thread-safe)."""
        GLib.idle_add(self._append_log_ui, text)

    def _append_log_ui(self, text):
        """Append to log on main thread."""
        if self.log_buffer:
            end_iter = self.log_buffer.get_end_iter()
            self.log_buffer.insert(end_iter, text + "\n")

            # Auto-scroll to bottom
            if self.log_textview:
                mark = self.log_buffer.create_mark(None, end_iter, False)
                self.log_textview.scroll_mark_onscreen(mark)
                self.log_buffer.delete_mark(mark)
        return False

    def show_completion_dialog(self):
        """Show installation success dialog."""
        # Determine shell RC file
        shell = os.environ.get('SHELL', '/bin/bash')
        if 'zsh' in shell:
            rc_file = '~/.zshrc'
        elif 'fish' in shell:
            rc_file = '~/.config/fish/config.fish'
        elif 'ksh' in shell:
            rc_file = '~/.kshrc'
        else:
            rc_file = '~/.bashrc'

        dialog = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text="Installation Complete!"
        )
        dialog.format_secondary_text(
            f"Langtool-CLI has been successfully installed.\n\n"
            f"To start using the CLI:\n"
            f"  • Restart your terminal, or\n"
            f"  • Run: source {rc_file}\n\n"
            f"Then you can use the 'langtool' command."
        )

        dialog.run()
        dialog.destroy()

        # Enable Finish button
        self.next_button.set_sensitive(True)
        self.next_button.set_label("Finish")
        self.cancel_button.set_label("Close")

    def show_error_dialog(self, error_message):
        """Show installation error dialog."""
        dialog = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text="Installation Failed"
        )
        dialog.format_secondary_text(
            f"An error occurred during installation:\n\n{error_message}\n\n"
            "Please check the installation log for details."
        )

        dialog.run()
        dialog.destroy()

        # Re-enable navigation
        self.back_button.set_sensitive(True)
        self.cancel_button.set_sensitive(True)

    def go_next(self):
        """Navigate to the next page."""

        # Validate current page
        if not self.validate_current_page():
            return

        # Save current state
        self.save_current_page_state()

        # Check if we're on the last page
        if self.current_page == len(self.pages) - 1:
            # Finish button was clicked - exit
            Gtk.main_quit()
            return

        # Move to next page
        self.current_page += 1
        self.stack.set_visible_child_name(self.pages[self.current_page])
        self.update_navigation()

        # Trigger page-specific actions
        self.on_page_shown()

    def go_back(self):
        """Navigate to the previous page."""

        if self.current_page > 0:
            self.current_page -= 1
            self.stack.set_visible_child_name(self.pages[self.current_page])
            self.update_navigation()
            self.on_page_shown()

    def on_page_shown(self):
        """Called when a page is shown. Override for page-specific logic."""
        page_name = self.pages[self.current_page]

        if page_name == "version" and not self.versions_fetched:
            # Fetch versions when version page is shown for the first time
            self.fetch_versions_async()
        elif page_name == "confirm":
            # Update confirmation summary when page is shown
            self.update_confirmation_summary()
        elif page_name == "install":
            # Start installation when page is shown
            self.start_installation()

    def on_next_clicked(self, button):
        """Handle Next/Install/Finish button click."""
        self.go_next()

    def on_back_clicked(self, button):
        """Handle Back button click."""
        self.go_back()

    def on_cancel_clicked(self, button):
        """Handle Cancel button click."""
        self.confirm_and_quit()

    def confirm_and_quit(self):
        """Confirm and quit the wizard."""
        # Don't ask for confirmation if on welcome page or after successful install
        if self.current_page == 0 or self.install_success:
            self.cleanup_and_quit()
            return

        dialog = Gtk.MessageDialog(
            transient_for=self,
            modal=True,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.YES_NO,
            text="Cancel Installation?"
        )
        dialog.format_secondary_text(
            "Are you sure you want to cancel the installation?\n"
            "Your progress will be lost."
        )

        response = dialog.run()
        dialog.destroy()

        if response == Gtk.ResponseType.YES:
            self.cleanup_and_quit()

    def on_window_close(self, widget):
        """Handle window close event."""
        self.confirm_and_quit()

    def cleanup_and_quit(self):
        """Clean up and quit the application."""
        # Clean up state file
        try:
            if os.path.exists(self.state_file):
                os.remove(self.state_file)
        except Exception as e:
            print(f"Warning: Could not remove state file: {e}", file=sys.stderr)

        Gtk.main_quit()

    def on_key_press(self, widget, event):
        """Handle keyboard shortcuts."""
        # Get key name
        keyname = Gtk.gdk.keyval_name(event.keyval)

        # Escape key = Cancel
        if keyname == "Escape":
            if self.cancel_button.get_sensitive():
                self.confirm_and_quit()
            return True

        # Enter/Return key = Next (if not on installation page)
        if keyname in ("Return", "KP_Enter"):
            page_name = self.pages[self.current_page]
            if page_name != "install" and self.next_button.get_sensitive():
                self.go_next()
            return True

        return False


def main():
    """Entry point for the GTK wizard."""

    # Check for DISPLAY
    if not os.environ.get('DISPLAY'):
        print("Error: No DISPLAY environment variable set", file=sys.stderr)
        print("GTK wizard requires a graphical environment", file=sys.stderr)
        sys.exit(1)

    # Launch wizard
    wizard = InstallWizard()
    Gtk.main()

    return 0


if __name__ == "__main__":
    sys.exit(main())

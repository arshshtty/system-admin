#!/usr/bin/env python3

"""
System Admin Toolkit - Interactive TUI

A friendly terminal interface for managing servers with the system-admin toolkit.
Makes complex operations accessible while teaching users the underlying CLI commands.

Usage:
    ./admin.py
    python3 admin.py

Requirements:
    pip install textual rich
"""

import sys
import subprocess
import os
from pathlib import Path
from typing import Optional, List, Dict, Any

try:
    from textual.app import App, ComposeResult
    from textual.containers import Container, Vertical, Horizontal, ScrollableContainer
    from textual.widgets import (
        Header, Footer, Button, Static, Label,
        Checkbox, Input, Select, OptionList, RadioSet, RadioButton
    )
    from textual.screen import Screen
    from textual import events
    from textual.binding import Binding
    from rich.text import Text
    from rich.panel import Panel
    from rich.syntax import Syntax
except ImportError:
    print("Error: Required dependencies not found.")
    print("Please install them with: pip install textual rich")
    sys.exit(1)

# Script paths
REPO_ROOT = Path(__file__).parent
SCRIPTS_DIR = REPO_ROOT / "scripts"


class WelcomeScreen(Screen):
    """Main menu screen"""

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("?", "help", "Help"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Container(
            Static("""
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║          🛠️  System Admin Toolkit                         ║
║                                                           ║
║          Your friendly server management interface        ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
            """, id="welcome-banner"),
            Static("\n📋 What would you like to do?\n", id="menu-title"),
            Vertical(
                Button("📊  Monitor Server Health", id="btn-monitor", variant="primary"),
                Button("🧹  Clean Docker Resources", id="btn-docker", variant="success"),
                Button("💾  Backup & Restore", id="btn-backup", variant="default"),
                Button("🚀  Bootstrap New Server", id="btn-bootstrap", variant="default"),
                Button("📚  Browse All Scripts", id="btn-browse", variant="default"),
                Button("❓  Help & Documentation", id="btn-help", variant="default"),
                Button("🚪  Exit", id="btn-exit", variant="error"),
                id="menu-buttons"
            ),
            Static("\n💡 Tip: Press '?' for keyboard shortcuts", id="tip"),
            id="welcome-container"
        )
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button clicks"""
        button_id = event.button.id

        if button_id == "btn-monitor":
            self.app.push_screen(MonitoringScreen())
        elif button_id == "btn-docker":
            self.app.push_screen(DockerCleanupScreen())
        elif button_id == "btn-backup":
            self.app.push_screen(BackupScreen())
        elif button_id == "btn-bootstrap":
            self.app.push_screen(BootstrapScreen())
        elif button_id == "btn-browse":
            self.app.push_screen(BrowseScriptsScreen())
        elif button_id == "btn-help":
            self.app.push_screen(HelpScreen())
        elif button_id == "btn-exit":
            self.app.exit()


class MonitoringScreen(Screen):
    """Health monitoring screen"""

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Container(
            Static("📊 Server Health Monitoring\n", id="screen-title"),
            Static("View real-time health metrics from your servers.\n"),
            Vertical(
                Button("🚀 Start Monitoring Dashboard (Web UI)", id="start-dashboard", variant="primary"),
                Button("🔍 Run Single Health Check", id="run-once", variant="success"),
                Button("📁 Configure Servers (edit inventory)", id="config-servers", variant="default"),
                Button("🔙 Back to Main Menu", id="back", variant="default"),
                id="monitor-buttons"
            ),
            Static("\n", id="command-preview"),
            id="monitor-container"
        )
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle monitoring actions"""
        button_id = event.button.id

        if button_id == "start-dashboard":
            cmd = f"{SCRIPTS_DIR}/monitoring/start-monitoring.sh"
            self.show_command_and_execute(
                "Starting Monitoring Dashboard",
                cmd,
                "This will start the web dashboard at http://localhost:5000"
            )
        elif button_id == "run-once":
            cmd = f"python3 {SCRIPTS_DIR}/monitoring/health-check.py --once --verbose"
            self.show_command_and_execute(
                "Running Health Check",
                cmd,
                "Checking all servers from inventory file"
            )
        elif button_id == "config-servers":
            config_file = REPO_ROOT / "inventory" / "servers.yaml"
            self.app.push_screen(InfoScreen(
                "Server Configuration",
                f"Edit your server inventory at:\n\n{config_file}\n\nExample:\n```yaml\nservers:\n  production:\n    - name: web-server\n      ip: 192.168.1.100\n      ssh_user: admin\n```"
            ))
        elif button_id == "back":
            self.app.pop_screen()

    def show_command_and_execute(self, title: str, command: str, description: str):
        """Show command preview and execute"""
        self.app.push_screen(CommandExecuteScreen(title, command, description))


class DockerCleanupScreen(Screen):
    """Docker cleanup configuration screen"""

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def __init__(self):
        super().__init__()
        self.cleanup_options = {
            "containers": True,
            "images": True,
            "volumes": True,
            "networks": False,
            "dry_run": True,
        }
        self.keep_days = 30

    def compose(self) -> ComposeResult:
        yield Header()
        yield ScrollableContainer(
            Static("🧹 Docker Cleanup Configuration\n", id="screen-title"),
            Static("Clean up unused Docker resources safely.\n"),

            Static("\n📦 What should we clean?\n", classes="section-title"),
            Checkbox("Stopped containers", value=True, id="chk-containers"),
            Checkbox("Unused images", value=True, id="chk-images"),
            Checkbox("Unused volumes (⚠️  deletes data!)", value=True, id="chk-volumes"),
            Checkbox("Unused networks", value=False, id="chk-networks"),

            Static("\n⏰ Retention Policy\n", classes="section-title"),
            Horizontal(
                Static("Keep resources from last "),
                Input(value="30", id="input-days", placeholder="30"),
                Static(" days"),
                id="retention-input"
            ),

            Static("\n🛡️  Safety Options\n", classes="section-title"),
            Checkbox("Dry run first (recommended)", value=True, id="chk-dryrun"),

            Static("\n"),
            Horizontal(
                Button("🧹 Run Cleanup", id="run-cleanup", variant="primary"),
                Button("📊 Show Statistics Only", id="show-stats", variant="success"),
                Button("🔙 Back", id="back", variant="default"),
                id="action-buttons"
            ),

            Static("\n💡 Command Preview:\n", classes="section-title"),
            Static("", id="command-preview"),
        )
        yield Footer()

    def on_checkbox_changed(self, event: Checkbox.Changed) -> None:
        """Update options when checkboxes change"""
        checkbox_id = event.checkbox.id

        if checkbox_id == "chk-containers":
            self.cleanup_options["containers"] = event.value
        elif checkbox_id == "chk-images":
            self.cleanup_options["images"] = event.value
        elif checkbox_id == "chk-volumes":
            self.cleanup_options["volumes"] = event.value
        elif checkbox_id == "chk-networks":
            self.cleanup_options["networks"] = event.value
        elif checkbox_id == "chk-dryrun":
            self.cleanup_options["dry_run"] = event.value

        self.update_preview()

    def on_input_changed(self, event: Input.Changed) -> None:
        """Update keep_days when input changes"""
        if event.input.id == "input-days":
            try:
                self.keep_days = int(event.value) if event.value else 30
            except ValueError:
                self.keep_days = 30
        self.update_preview()

    def update_preview(self):
        """Update the command preview"""
        script_path = f"{SCRIPTS_DIR}/docker/docker-cleanup.sh"
        args = []

        # Build command based on options
        if all([self.cleanup_options.get(k) for k in ["containers", "images", "volumes", "networks"]]):
            args.append("--all")
        else:
            if self.cleanup_options.get("containers"):
                args.append("--containers")
            if self.cleanup_options.get("images"):
                args.append("--images")
            if self.cleanup_options.get("volumes"):
                args.append("--volumes")
            if self.cleanup_options.get("networks"):
                args.append("--networks")

        args.append(f"--keep-days {self.keep_days}")

        if self.cleanup_options.get("dry_run"):
            args.append("--dry-run")

        command = f"{script_path} {' '.join(args)}"

        preview = self.query_one("#command-preview", Static)
        preview.update(f"$ {command}")

    def on_mount(self) -> None:
        """Update preview when screen loads"""
        self.update_preview()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button clicks"""
        button_id = event.button.id

        if button_id == "run-cleanup":
            # Build command
            script_path = f"{SCRIPTS_DIR}/docker/docker-cleanup.sh"
            args = []

            if all([self.cleanup_options.get(k) for k in ["containers", "images", "volumes", "networks"]]):
                args.append("--all")
            else:
                if self.cleanup_options.get("containers"):
                    args.append("--containers")
                if self.cleanup_options.get("images"):
                    args.append("--images")
                if self.cleanup_options.get("volumes"):
                    args.append("--volumes")
                if self.cleanup_options.get("networks"):
                    args.append("--networks")

            args.append(f"--keep-days {self.keep_days}")

            if self.cleanup_options.get("dry_run"):
                args.append("--dry-run")

            command = f"{script_path} {' '.join(args)}"

            self.app.push_screen(CommandExecuteScreen(
                "Docker Cleanup",
                command,
                "Cleaning Docker resources... (this may take a moment)"
            ))

        elif button_id == "show-stats":
            command = f"{SCRIPTS_DIR}/docker/docker-cleanup.sh"
            self.app.push_screen(CommandExecuteScreen(
                "Docker Statistics",
                command,
                "Showing current Docker resource usage"
            ))

        elif button_id == "back":
            self.app.pop_screen()


class BackupScreen(Screen):
    """Backup and restore screen"""

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Container(
            Static("💾 Backup & Restore\n", id="screen-title"),
            Static("Manage backups of files, databases, and Docker volumes.\n"),

            Static("\n📦 Quick Actions\n", classes="section-title"),
            Vertical(
                Button("💾 Backup Everything", id="backup-all", variant="primary"),
                Button("📁 Backup Files Only", id="backup-files", variant="success"),
                Button("🗄️  Backup Databases", id="backup-db", variant="success"),
                Button("🐳 Backup Docker Volumes", id="backup-docker", variant="success"),
                Button("📋 List Available Backups", id="list-backups", variant="default"),
                Button("♻️  Restore from Backup", id="restore", variant="warning"),
                Button("🔙 Back", id="back", variant="default"),
                id="backup-buttons"
            ),
        )
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle backup actions"""
        button_id = event.button.id
        script = f"{SCRIPTS_DIR}/backup/backup-manager.sh"

        if button_id == "backup-all":
            command = f"{script} --type all --dry-run"
            self.app.push_screen(CommandExecuteScreen(
                "Full Backup (Dry Run)",
                command,
                "Preview what will be backed up. Remove --dry-run to execute."
            ))
        elif button_id == "backup-files":
            command = f"{script} --type files --dry-run"
            self.app.push_screen(CommandExecuteScreen(
                "Files Backup (Dry Run)",
                command,
                "Preview file backup"
            ))
        elif button_id == "backup-db":
            command = f"{script} --type database --dry-run"
            self.app.push_screen(CommandExecuteScreen(
                "Database Backup (Dry Run)",
                command,
                "Preview database backup"
            ))
        elif button_id == "backup-docker":
            command = f"{script} --type docker --dry-run"
            self.app.push_screen(CommandExecuteScreen(
                "Docker Volumes Backup (Dry Run)",
                command,
                "Preview Docker volumes backup"
            ))
        elif button_id == "list-backups":
            command = f"{script} --list"
            self.app.push_screen(CommandExecuteScreen(
                "Available Backups",
                command,
                "Listing all available backups"
            ))
        elif button_id == "restore":
            self.app.push_screen(InfoScreen(
                "Restore Backup",
                f"To restore a backup:\n\n1. List available backups:\n   $ {script} --list\n\n2. Restore a specific backup:\n   $ {script} --restore <backup-file> <destination>\n\nPlease run this from the command line for safety."
            ))
        elif button_id == "back":
            self.app.pop_screen()


class BootstrapScreen(Screen):
    """Server bootstrap screen"""

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Container(
            Static("🚀 Bootstrap New Server\n", id="screen-title"),
            Static("Set up a fresh server with essential tools and configurations.\n"),

            Static("\n🎯 Installation Options\n", classes="section-title"),
            Vertical(
                Button("⚡ Install Everything (Recommended)", id="install-all", variant="primary"),
                Button("📦 Core Tools Only", id="install-core", variant="success"),
                Button("🐳 Docker + Compose", id="install-docker", variant="default"),
                Button("🐚 Zsh + Oh-My-Zsh", id="install-shell", variant="default"),
                Button("💻 Modern CLI Tools", id="install-modern", variant="default"),
                Button("📄 Dotfiles Setup", id="install-dotfiles", variant="default"),
                Button("📖 View Full Documentation", id="view-docs", variant="default"),
                Button("🔙 Back", id="back", variant="default"),
                id="bootstrap-buttons"
            ),
        )
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle bootstrap actions"""
        button_id = event.button.id
        script = f"{SCRIPTS_DIR}/bootstrap/install-essentials.sh"

        if button_id == "install-all":
            command = f"{script} --all"
            self.app.push_screen(CommandExecuteScreen(
                "Bootstrap Server - Full Install",
                command,
                "Installing all tools and configurations. This may take 10-20 minutes."
            ))
        elif button_id == "install-core":
            command = f"{script} --core"
            self.app.push_screen(CommandExecuteScreen(
                "Bootstrap Server - Core Tools",
                command,
                "Installing core development tools"
            ))
        elif button_id == "install-docker":
            command = f"{script} --docker"
            self.app.push_screen(CommandExecuteScreen(
                "Bootstrap Server - Docker",
                command,
                "Installing Docker Engine and Docker Compose"
            ))
        elif button_id == "install-shell":
            command = f"{script} --shell"
            self.app.push_screen(CommandExecuteScreen(
                "Bootstrap Server - Shell",
                command,
                "Installing Zsh and Oh-My-Zsh with plugins"
            ))
        elif button_id == "install-modern":
            command = f"{script} --modern-cli"
            self.app.push_screen(CommandExecuteScreen(
                "Bootstrap Server - Modern CLI",
                command,
                "Installing modern CLI tools (bat, exa, fd, ripgrep, etc.)"
            ))
        elif button_id == "install-dotfiles":
            command = f"{script} --dotfiles"
            self.app.push_screen(CommandExecuteScreen(
                "Bootstrap Server - Dotfiles",
                command,
                "Setting up dotfiles (.vimrc, .zshrc, .tmux.conf, etc.)"
            ))
        elif button_id == "view-docs":
            self.app.push_screen(InfoScreen(
                "Bootstrap Documentation",
                f"Installation script: {script}\n\nWhat gets installed:\n\n--all: Everything (recommended for new servers)\n--core: git, curl, vim, tmux, htop, ncdu, jq\n--docker: Docker Engine + Compose (rootless)\n--shell: Zsh + oh-my-zsh with plugins\n--languages: Node.js (nvm), Python tooling\n--modern-cli: bat, exa, fd, ripgrep, lazydocker, lazygit\n--dotfiles: Pre-configured dotfiles from repo\n\nFor more details, see README.md"
            ))
        elif button_id == "back":
            self.app.pop_screen()


class BrowseScriptsScreen(Screen):
    """Browse all available scripts"""

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield ScrollableContainer(
            Static("📚 All Available Scripts\n", id="screen-title"),
            Static("Browse and learn about all scripts in the toolkit.\n"),

            Static("\n🔍 Monitoring\n", classes="section-title"),
            Static(f"  • health-check.py - Multi-server health monitoring\n    {SCRIPTS_DIR}/monitoring/health-check.py --help\n"),
            Static(f"  • web-dashboard.py - Web UI for health metrics\n    {SCRIPTS_DIR}/monitoring/web-dashboard.py\n"),
            Static(f"  • start-monitoring.sh - Quick start monitoring\n    {SCRIPTS_DIR}/monitoring/start-monitoring.sh\n"),

            Static("\n🐳 Docker\n", classes="section-title"),
            Static(f"  • docker-cleanup.sh - Clean Docker resources\n    {SCRIPTS_DIR}/docker/docker-cleanup.sh --help\n"),

            Static("\n💾 Backup\n", classes="section-title"),
            Static(f"  • backup-manager.sh - Comprehensive backup tool\n    {SCRIPTS_DIR}/backup/backup-manager.sh --help\n"),

            Static("\n🚀 Bootstrap\n", classes="section-title"),
            Static(f"  • install-essentials.sh - Server setup automation\n    {SCRIPTS_DIR}/bootstrap/install-essentials.sh --help\n"),

            Static("\n🔒 Security\n", classes="section-title"),
            Static(f"  • security-audit.sh - Security baseline audit\n    {SCRIPTS_DIR}/security/security-audit.sh --help\n"),
            Static(f"  • ssl-manager.sh - SSL certificate management\n    {SCRIPTS_DIR}/security/ssl-manager.sh --help\n"),
            Static(f"  • auto-updates.sh - Automated security updates\n    {SCRIPTS_DIR}/security/auto-updates.sh --help\n"),

            Static("\n📊 More Tools\n", classes="section-title"),
            Static(f"  • network-diagnostics.sh - Network troubleshooting\n    {SCRIPTS_DIR}/network/network-diagnostics.sh --help\n"),
            Static(f"  • setup-log-aggregation.sh - Log management\n    {SCRIPTS_DIR}/logging/setup-log-aggregation.sh --help\n"),

            Static("\n"),
            Button("🔙 Back to Main Menu", id="back", variant="default"),
        )
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.app.pop_screen()


class HelpScreen(Screen):
    """Help and documentation screen"""

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield ScrollableContainer(
            Static("❓ Help & Documentation\n", id="screen-title"),

            Static("\n🎯 About This Tool\n", classes="section-title"),
            Static(
                "The System Admin Toolkit TUI provides a friendly interface to powerful\n"
                "server management scripts. It's designed to be educational - showing you\n"
                "the underlying commands so you can learn and eventually use them directly.\n"
            ),

            Static("\n⌨️  Keyboard Shortcuts\n", classes="section-title"),
            Static(
                "  • Tab / Shift+Tab - Navigate between elements\n"
                "  • Enter - Select / Activate\n"
                "  • Escape - Go back\n"
                "  • Ctrl+C - Exit application\n"
                "  • ? - Show help (from main menu)\n"
            ),

            Static("\n💡 Tips\n", classes="section-title"),
            Static(
                "  • Always use dry-run mode first for destructive operations\n"
                "  • Check the command preview before executing\n"
                "  • Scripts can also be run directly from the command line\n"
                "  • Configuration files are in inventory/ and configs/ directories\n"
            ),

            Static("\n📚 Documentation\n", classes="section-title"),
            Static(
                f"  • Main README: {REPO_ROOT}/README.md\n"
                f"  • AI Assistant Guide: {REPO_ROOT}/CLAUDE.md\n"
                f"  • Example configs: {REPO_ROOT}/configs/examples/\n"
                f"  • Server inventory: {REPO_ROOT}/inventory/example.yaml\n"
            ),

            Static("\n🐛 Troubleshooting\n", classes="section-title"),
            Static(
                "  • If a script fails, check its --help output\n"
                "  • Verify dependencies are installed\n"
                "  • Check file permissions (scripts need execute permission)\n"
                "  • Review logs in /var/log/ for errors\n"
            ),

            Static("\n"),
            Button("🔙 Back to Main Menu", id="back", variant="default"),
        )
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.app.pop_screen()


class CommandExecuteScreen(Screen):
    """Screen for executing commands and showing output"""

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def __init__(self, title: str, command: str, description: str):
        super().__init__()
        self.title = title
        self.command = command
        self.description = description
        self.output = ""

    def compose(self) -> ComposeResult:
        yield Header()
        yield ScrollableContainer(
            Static(f"⚡ {self.title}\n", id="screen-title"),
            Static(f"{self.description}\n"),

            Static("\n📝 Command:\n", classes="section-title"),
            Static(f"$ {self.command}\n", id="command-display"),

            Static("\n📤 Output:\n", classes="section-title"),
            Static("Executing...", id="output-display"),

            Static("\n"),
            Horizontal(
                Button("▶️  Execute", id="execute", variant="primary"),
                Button("📋 Copy Command", id="copy", variant="success"),
                Button("🔙 Back", id="back", variant="default"),
                id="exec-buttons"
            ),
        )
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button clicks"""
        button_id = event.button.id

        if button_id == "execute":
            self.execute_command()
        elif button_id == "copy":
            # In a real terminal, this would copy to clipboard
            # For now, just show a message
            output_widget = self.query_one("#output-display", Static)
            output_widget.update("Command copied to clipboard (conceptually)!\n\n" + self.command)
        elif button_id == "back":
            self.app.pop_screen()

    def execute_command(self):
        """Execute the command and display output"""
        output_widget = self.query_one("#output-display", Static)
        output_widget.update("Executing...\n")

        try:
            # Execute the command
            result = subprocess.run(
                self.command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )

            # Combine stdout and stderr
            output = ""
            if result.stdout:
                output += result.stdout
            if result.stderr:
                output += "\n" + result.stderr

            if result.returncode == 0:
                output = f"✅ Command completed successfully!\n\n{output}"
            else:
                output = f"❌ Command failed with exit code {result.returncode}\n\n{output}"

            output_widget.update(output)

        except subprocess.TimeoutExpired:
            output_widget.update("❌ Command timed out after 5 minutes")
        except Exception as e:
            output_widget.update(f"❌ Error executing command: {str(e)}")


class InfoScreen(Screen):
    """Simple information display screen"""

    BINDINGS = [
        Binding("escape", "app.pop_screen", "Back"),
    ]

    def __init__(self, title: str, content: str):
        super().__init__()
        self.title = title
        self.content = content

    def compose(self) -> ComposeResult:
        yield Header()
        yield ScrollableContainer(
            Static(f"ℹ️  {self.title}\n", id="screen-title"),
            Static(self.content),
            Static("\n"),
            Button("🔙 Back", id="back", variant="default"),
        )
        yield Footer()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "back":
            self.app.pop_screen()


class AdminToolkitApp(App):
    """Main application class"""

    CSS = """
    Screen {
        background: $surface;
    }

    #welcome-banner {
        color: $accent;
        text-align: center;
        margin: 1;
    }

    #menu-title, #screen-title {
        text-align: center;
        text-style: bold;
        color: $accent;
        margin: 1;
    }

    #welcome-container {
        align: center middle;
        width: 100%;
        height: 100%;
    }

    #menu-buttons {
        width: 60;
        align: center middle;
        margin: 1;
    }

    Button {
        width: 100%;
        margin: 1;
    }

    #tip {
        text-align: center;
        color: $text-muted;
        margin-top: 2;
    }

    .section-title {
        text-style: bold;
        color: $accent;
        margin-top: 1;
    }

    #command-preview, #command-display {
        background: $panel;
        color: $text;
        padding: 1;
        border: solid $accent;
        margin: 1;
    }

    #output-display {
        background: $panel;
        color: $text;
        padding: 1;
        border: solid $primary;
        margin: 1;
        min-height: 20;
    }

    Container, ScrollableContainer {
        padding: 1;
    }

    Checkbox {
        margin: 1;
    }

    #retention-input {
        margin: 1;
    }

    #action-buttons, #exec-buttons {
        align: center middle;
        margin: 1;
    }
    """

    BINDINGS = [
        Binding("q", "quit", "Quit", show=True),
        Binding("ctrl+c", "quit", "Quit", show=False),
    ]

    def on_mount(self) -> None:
        """Set up the application"""
        self.title = "System Admin Toolkit"
        self.sub_title = "Interactive Server Management"
        self.push_screen(WelcomeScreen())

    def action_quit(self) -> None:
        """Quit the application"""
        self.exit()


def main():
    """Main entry point"""
    # Check if we're in the right directory
    if not SCRIPTS_DIR.exists():
        print(f"Error: Scripts directory not found at {SCRIPTS_DIR}")
        print("Please run this from the system-admin repository root.")
        sys.exit(1)

    app = AdminToolkitApp()
    app.run()


if __name__ == "__main__":
    main()

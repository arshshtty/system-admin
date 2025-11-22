# System Admin Toolkit - TUI Guide

## 🎯 What is this?

The System Admin Toolkit TUI (Terminal User Interface) is a friendly, interactive interface that makes it easy to use all the powerful scripts in this repository. It's perfect for:

- **Newcomers** who want to explore available tools
- **Infrequent users** who don't remember all the command options
- **Anyone** who prefers a visual, guided interface
- **Learning** - it shows you the underlying commands so you can graduate to direct CLI usage

## 🚀 Quick Start

### Installation

1. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

   Or install just the TUI dependencies:
   ```bash
   pip install textual rich
   ```

2. **Launch the TUI:**
   ```bash
   ./admin.py
   ```

   Or:
   ```bash
   python3 admin.py
   ```

That's it! The interface will guide you through everything.

## 📚 Features

### Main Menu

When you launch the TUI, you'll see a menu with these options:

```
📊  Monitor Server Health    - View metrics from all your servers
🧹  Clean Docker Resources   - Safe Docker cleanup with options
💾  Backup & Restore         - Manage backups and restores
🚀  Bootstrap New Server     - Set up fresh servers quickly
📚  Browse All Scripts       - Explore all available tools
❓  Help & Documentation     - Learn more about the toolkit
```

### Educational Design

The TUI is designed to teach you the CLI:

1. **See the command** - Before executing, you see the exact command
2. **Understand options** - Interactive forms show what each option does
3. **Safe by default** - Dry-run mode is enabled by default for destructive operations
4. **Graduate to CLI** - Copy commands to use them directly later

### Example Workflows

#### Docker Cleanup

1. Select "Clean Docker Resources"
2. Choose what to clean (containers, images, volumes, networks)
3. Set retention policy (keep last N days)
4. Enable dry-run to preview
5. See the command that will be executed
6. Run cleanup and view results

The TUI builds a command like:
```bash
./scripts/docker/docker-cleanup.sh --containers --images --volumes --keep-days 30 --dry-run
```

#### Health Monitoring

1. Select "Monitor Server Health"
2. Choose "Start Monitoring Dashboard" for web UI
3. Or "Run Single Health Check" for a one-time check
4. Configure servers in `inventory/servers.yaml`
5. View results in your browser

#### Backup Management

1. Select "Backup & Restore"
2. Choose what to backup (all/files/databases/docker)
3. Preview the backup with dry-run
4. Execute the actual backup
5. List and restore backups later

## ⌨️ Keyboard Shortcuts

- **Tab / Shift+Tab** - Navigate between elements
- **Enter** - Select / Activate button
- **Space** - Toggle checkboxes
- **Escape** - Go back to previous screen
- **Ctrl+C** or **q** - Quit application
- **?** - Show help (from main menu)

## 🎨 Screenshots (Conceptual)

### Main Menu
```
╔═══════════════════════════════════════════════════════════╗
║          🛠️  System Admin Toolkit                         ║
║          Your friendly server management interface        ║
╚═══════════════════════════════════════════════════════════╝

📋 What would you like to do?

  📊  Monitor Server Health
  🧹  Clean Docker Resources
  💾  Backup & Restore
  🚀  Bootstrap New Server
  📚  Browse All Scripts
  ❓  Help & Documentation
  🚪  Exit
```

### Docker Cleanup Configuration
```
🧹 Docker Cleanup Configuration

📦 What should we clean?

  [✓] Stopped containers
  [✓] Unused images
  [✓] Unused volumes (⚠️  deletes data!)
  [ ] Unused networks

⏰ Retention Policy
  Keep resources from last [30] days

🛡️  Safety Options
  [✓] Dry run first (recommended)

  [Run Cleanup]  [Show Statistics]  [Back]

💡 Command Preview:
  $ ./scripts/docker/docker-cleanup.sh --containers --images --volumes --keep-days 30 --dry-run
```

## 🔧 Advanced Usage

### Running Scripts Directly

Once you're comfortable, you can run the scripts directly:

```bash
# Docker cleanup
./scripts/docker/docker-cleanup.sh --all --dry-run

# Health monitoring
python3 ./scripts/monitoring/health-check.py --once --verbose

# Backup
./scripts/backup/backup-manager.sh --type all

# Bootstrap
./scripts/bootstrap/install-essentials.sh --all
```

The TUI shows you these commands, so you learn as you use it!

### Configuration Files

The TUI uses these configuration files:

- `inventory/servers.yaml` - Server definitions for monitoring
- `configs/examples/` - Example configurations
- `~/.ssh/config` - SSH configuration for server access

Edit these files to customize behavior.

## 💡 Tips & Best Practices

1. **Always use dry-run first** for destructive operations (cleanup, backup)
2. **Review the command preview** before executing
3. **Check the output** after execution to ensure success
4. **Configure your servers** in `inventory/servers.yaml` before monitoring
5. **Use SSH keys** for passwordless authentication to servers
6. **Copy useful commands** to save in your notes or scripts

## 🐛 Troubleshooting

### TUI won't start
```bash
# Check dependencies
pip install textual rich

# Verify Python version (3.8+)
python3 --version

# Check you're in the repo root
pwd  # Should end in /system-admin
```

### Scripts fail to execute
```bash
# Check script permissions
chmod +x scripts/**/*.sh

# Verify script paths
ls -la scripts/docker/docker-cleanup.sh

# Run script directly to see errors
./scripts/docker/docker-cleanup.sh --help
```

### SSH connection issues (monitoring)
```bash
# Test SSH connection manually
ssh user@server-ip

# Set up SSH keys
ssh-keygen
ssh-copy-id user@server-ip

# Check inventory file
cat inventory/servers.yaml
```

## 🆚 TUI vs Direct CLI

### Use the TUI when:
- You're learning the toolkit
- You don't remember all the options
- You want a visual, guided experience
- You're doing one-off interactive tasks

### Use direct CLI when:
- You know the commands well
- You're automating with scripts
- You're running from cron/systemd
- You need maximum speed and efficiency

**Both are valid!** The TUI is here to help, not replace the CLI.

## 📖 Further Reading

- Main README: `README.md` - Project overview and CLI documentation
- AI Guide: `CLAUDE.md` - Detailed context for development
- Script Documentation: Run any script with `--help` flag

## 🤝 Contributing

Found a bug in the TUI? Have an idea for improvement?

1. Check existing issues on GitHub
2. Submit a bug report or feature request
3. Better yet, submit a pull request!

The TUI is designed to be simple and maintainable. New features should:
- Be genuinely useful for interactive workflows
- Show the underlying CLI command
- Follow the educational philosophy
- Not duplicate what CLI does better

---

**Enjoy the toolkit! Remember: the goal is to learn the CLI, not hide it. Use the TUI as a learning tool and stepping stone.** 🚀

# System Admin Toolkit

A comprehensive collection of scripts, configurations, and tools for managing home servers, bare metal machines, and VPS instances.

## Overview

This repository provides ready-to-use automation scripts for:
- **Server bootstrapping** - Get new servers production-ready in minutes with essential tools
- **Development environment setup** - Docker, Zsh, modern CLI tools, Node.js, Python, and more
- **Health monitoring** - Real-time multi-server monitoring with beautiful web dashboard
- **Backup automation** - Files, databases, Docker volumes with retention policies
- **Docker management** - Intelligent cleanup with dry-run mode and scheduling
- **Multi-server management** - YAML-based inventory and batch operations
- **Infrastructure as Code** - Version-controlled configurations and dotfiles

## Quick Start

### Clone the Repository

```bash
git clone https://github.com/arshshtty/system-admin.git
cd system-admin
```

### Install Essential Tools

The fastest way to set up a new server with all essential development tools:

```bash
# Install everything (recommended for first-time setup)
./scripts/bootstrap/install-essentials.sh

# Or install specific components
./scripts/bootstrap/install-essentials.sh --core --docker --shell
```

This will install:
- **Core tools**: git, vim, tmux, htop, ncdu, jq, etc.
- **Docker**: Docker Engine + Compose (with rootless setup)
- **Shell**: Zsh + oh-my-zsh with plugins (autosuggestions, syntax-highlighting, fzf)
- **Languages**: Node.js (via nvm), Python3, pip, pipx, uv
- **Modern CLI tools**: bat, exa, fd, ripgrep, lazydocker, lazygit
- **Dotfiles**: Pre-configured .zshrc, .vimrc, .gitconfig, .tmux.conf

### Available Options

```bash
./scripts/bootstrap/install-essentials.sh [options]

Options:
  --all           Install everything (default)
  --core          Only core tools (git, curl, vim, etc.)
  --docker        Docker Engine + Compose (rootless)
  --shell         Zsh + oh-my-zsh + plugins
  --languages     Node.js, Python tooling
  --modern-cli    Modern CLI tools (bat, exa, fd, etc.)
  --dotfiles      Setup dotfiles
  --help          Show help message
```

## Repository Structure

```
system-admin/
├── scripts/
│   ├── bootstrap/          # Initial server setup scripts
│   │   └── install-essentials.sh
│   ├── monitoring/         # Health checks and monitoring
│   ├── backup/            # Backup and recovery scripts
│   ├── security/          # Security hardening tools
│   ├── docker/            # Docker management scripts
│   └── utils/             # Utility scripts
├── configs/
│   ├── templates/         # Configuration templates
│   └── examples/          # Example configurations
├── dotfiles/              # Dotfiles for development
│   ├── .zshrc
│   ├── .vimrc
│   ├── .gitconfig
│   └── .tmux.conf
├── ansible/               # Ansible playbooks (future)
├── terraform/             # Infrastructure as Code (future)
├── runbooks/              # Operational runbooks
├── inventory/             # Server inventory files
└── docs/                  # Documentation
```

## Detailed Guide

### Post-Installation Steps

After running the installation script:

1. **Logout and login again** (or run `exec zsh`) to apply shell changes
2. **Configure Git** with your details:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```
3. **Enable Docker rootless mode**:
   ```bash
   systemctl --user enable --now docker
   ```
4. **Verify installations**:
   ```bash
   docker --version
   node --version
   python3 --version
   ```

### Dotfiles

The repository includes starter dotfiles with sensible defaults:

#### .zshrc Features
- oh-my-zsh with curated plugins
- zsh-autosuggestions (suggest commands as you type)
- zsh-syntax-highlighting (highlight commands)
- fzf integration (fuzzy finder for files and history)
- Useful aliases for git, docker, and system management
- Modern CLI tool integration (exa, bat, fd)
- Custom functions (mkcd, extract, docker-cleanup, etc.)

#### .vimrc Features
- Syntax highlighting and line numbers
- Smart indentation for multiple languages
- Useful key mappings (space as leader key)
- Split window navigation with Ctrl+hjkl
- System clipboard integration
- Persistent undo history
- File explorer with netrw

#### .gitconfig Features
- Comprehensive git aliases for common workflows
- Better log formatting and colors
- Automatic branch setup and pruning
- Merge and rebase helpers

#### .tmux.conf Features
- Ctrl+a as prefix (more ergonomic than Ctrl+b)
- Mouse support enabled
- Vim-style pane navigation
- Better status bar with date/time
- Copy mode with vi keybindings

### Customization

Each dotfile supports local customization without modifying the originals:

- `.zshrc.local` - Machine-specific zsh configuration
- `.vimrc.local` - Machine-specific vim configuration
- `.gitconfig.local` - Machine-specific git configuration (included automatically)

Create these files to add your custom settings.

## Useful Aliases and Functions

After installation, you'll have access to these convenient aliases:

### File Operations
```bash
ls      # Uses exa with colors and icons
ll      # Long listing
la      # Show all files including hidden
lt      # Tree view
cat     # Uses bat with syntax highlighting
```

### Git Shortcuts
```bash
gs      # git status
ga      # git add
gc      # git commit
gp      # git push
gl      # git log (pretty format)
gco     # git checkout
```

### Docker
```bash
d       # docker
dc      # docker compose
dps     # docker ps
di      # docker images
lzd     # lazydocker (TUI for Docker)
```

### System Management
```bash
update  # Update all packages
cleanup # Remove unused packages
ports   # Show listening ports
myip    # Show public IP address
```

### Custom Functions
```bash
mkcd <dir>          # Create directory and cd into it
extract <file>      # Extract any archive format
ff <name>           # Find files by name (uses fd if available)
search <text>       # Search for text in files (uses ripgrep if available)
docker-cleanup      # Clean up Docker resources
dush [n]            # Show largest directories (top n, default 10)
```

## Core Tools

### 1. Backup Automation (`scripts/backup/backup-manager.sh`)

Comprehensive backup solution supporting multiple targets and data types.

**Features:**
- Backup files, databases (MySQL/PostgreSQL), and Docker volumes
- Multiple destinations: local, remote (rsync), S3-compatible storage
- Retention policies (daily, weekly, monthly)
- Checksum verification (SHA256)
- Dry-run mode
- Restore and verification capabilities

**Quick Start:**
```bash
# Run full backup
./scripts/backup/backup-manager.sh

# Dry run to see what would be backed up
./scripts/backup/backup-manager.sh --dry-run

# Backup only databases
./scripts/backup/backup-manager.sh --type database

# List available backups
./scripts/backup/backup-manager.sh --list

# Restore a backup
./scripts/backup/backup-manager.sh --restore /path/to/backup.tar.gz

# Verify backup integrity
./scripts/backup/backup-manager.sh --verify /path/to/backup.tar.gz
```

**Configuration:**
Edit the script to customize:
- Backup sources (directories, databases, volumes)
- Remote destinations (rsync hosts, S3 buckets)
- Retention policies
- Notification methods (ntfy.sh, email, etc.)

**Automation:**
Add to crontab for automated backups:
```bash
# Daily backup at 2 AM
0 2 * * * /path/to/system-admin/scripts/backup/backup-manager.sh
```

### 2. Docker Cleanup (`scripts/docker/docker-cleanup.sh`)

Intelligent Docker resource cleanup with safety features.

**Features:**
- Clean stopped containers, unused images, volumes, and networks
- Dry-run mode to preview changes
- Configurable retention (keep recent items)
- Disk space reporting
- Safe confirmation prompts
- Schedule automatic cleanup

**Quick Start:**
```bash
# Show current Docker disk usage (no cleanup)
./scripts/docker/docker-cleanup.sh

# Clean everything
./scripts/docker/docker-cleanup.sh --all

# Dry run to see what would be cleaned
./scripts/docker/docker-cleanup.sh --all --dry-run

# Clean only stopped containers
./scripts/docker/docker-cleanup.sh --containers

# Clean only dangling images
./scripts/docker/docker-cleanup.sh --dangling

# Clean images older than 30 days
./scripts/docker/docker-cleanup.sh --images --keep-days 30

# Force cleanup without confirmations
./scripts/docker/docker-cleanup.sh --all --force

# Setup automatic weekly cleanup
./scripts/docker/docker-cleanup.sh --schedule
```

**Options:**
```
--all               Clean everything (containers, images, volumes, networks)
--containers        Clean only stopped containers
--images            Clean only unused images
--volumes           Clean only unused volumes
--networks          Clean only unused networks
--dangling          Clean only dangling images
--dry-run           Show what would be cleaned without doing it
--force             Skip confirmation prompts
--keep-days N       Keep images/containers from last N days (default: 7)
--schedule          Set up automatic cleanup (cron)
```

### 3. Health Monitoring System (`scripts/monitoring/`)

Real-time multi-server health monitoring with beautiful web UI.

**Features:**
- Monitor multiple servers via SSH
- Metrics: CPU, memory, disk, uptime, load average
- Docker container status tracking
- Service status monitoring (systemd)
- Beautiful responsive web dashboard
- Auto-refresh every 30 seconds
- Historical data tracking
- Alert on critical thresholds
- Status indicators (healthy, warning, critical, down)

**Components:**
1. **health-check.py** - Collector that gathers metrics from servers
2. **web-dashboard.py** - Web UI that displays the data
3. **start-monitoring.sh** - Quick start script

**Quick Start:**
```bash
# 1. Install Python dependencies
pip3 install -r requirements.txt

# 2. Configure your servers
cp inventory/example.yaml inventory/servers.yaml
# Edit servers.yaml with your server details

# 3. Start monitoring (both collector and web UI)
./scripts/monitoring/start-monitoring.sh

# 4. Open browser
# Visit: http://localhost:8080
```

**Manual Usage:**
```bash
# Run health check once
./scripts/monitoring/health-check.py --config inventory/servers.yaml --once

# Run continuously (check every 60 seconds)
./scripts/monitoring/health-check.py --config inventory/servers.yaml --interval 60

# Custom output directory
./scripts/monitoring/health-check.py --output /var/www/health-monitor

# Start web dashboard
./scripts/monitoring/web-dashboard.py --data-dir /tmp/health-monitor --port 8080
```

**Server Configuration:**
Edit `inventory/servers.yaml`:
```yaml
servers:
  home:
    - name: homelab-01
      ip: 192.168.1.100
      ssh_user: admin
      type: bare-metal
      tags:
        - production
        - docker

  vps:
    - name: prod-web-01
      ip: 1.2.3.4
      ssh_user: deploy
      type: vps
      tags:
        - production
        - web
```

**Run as Service:**
Copy example systemd service files:
```bash
sudo cp configs/examples/health-monitor.service /etc/systemd/system/
sudo cp configs/examples/health-dashboard.service /etc/systemd/system/

# Edit paths in service files
sudo nano /etc/systemd/system/health-monitor.service
sudo nano /etc/systemd/system/health-dashboard.service

# Start services
sudo systemctl daemon-reload
sudo systemctl enable --now health-monitor health-dashboard

# Check status
sudo systemctl status health-monitor
sudo systemctl status health-dashboard
```

**Dashboard Features:**
- 📊 Real-time metrics visualization
- 🎨 Color-coded status indicators
- 📈 Progress bars for resource usage
- 🐳 Docker container status
- ⚠️ Warning alerts for critical thresholds
- 📱 Responsive design (works on mobile)
- 🔄 Auto-refresh every 30 seconds

**Thresholds:**
- CPU > 80% = Warning
- Memory > 85% = Warning
- Disk > 85% = Warning, > 95% = Critical

## Platform Support

Currently supports:
- Ubuntu (20.04+)
- Debian (10+)

## Security Considerations

The installation script:
- ✅ Uses official package repositories
- ✅ Verifies GPG keys for Docker installation
- ✅ Sets up Docker rootless mode for better security
- ✅ Does not require sudo for most operations (except package installation)
- ✅ Backs up existing dotfiles before replacing them

## Roadmap

Completed:
- [x] Server health check script with web UI
- [x] Multi-server inventory management
- [x] Backup automation scripts
- [x] Docker cleanup automation
- [x] Database backup helpers (MySQL, PostgreSQL)

Future additions planned:
- [ ] Security baseline audit script
- [ ] SSL certificate management
- [ ] Monitoring stack setup (Prometheus + Grafana)
- [ ] Ansible playbooks for common tasks
- [ ] Network diagnostics and testing tools
- [ ] Log aggregation setup
- [ ] Automated security updates management
- [ ] Container orchestration helpers (Docker Swarm, K8s)

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - see LICENSE file for details

## Troubleshooting

### Docker rootless setup fails
If Docker rootless setup fails, you may need to:
1. Ensure your user has a valid subuid/subgid range: `grep $USER /etc/subuid /etc/subgid`
2. Install prerequisites: `sudo apt install uidmap dbus-user-session`
3. Logout and login again
4. Run: `dockerd-rootless-setuptool.sh install`

### nvm not found after installation
This is expected. Either:
- Logout and login again
- Run: `source ~/.zshrc`
- Or: `exec zsh`

### Shell doesn't change to zsh
Run manually: `chsh -s $(which zsh)`
Then logout and login again.

### Plugins not loading in zsh
Make sure oh-my-zsh is fully installed:
```bash
ls -la ~/.oh-my-zsh
```
If missing, the script will reinstall it on next run.

## Support

For issues, questions, or suggestions:
- Create an issue in this repository
- Check existing documentation in `docs/`
- Review runbooks in `runbooks/`

---

**Happy server managing!** 🚀

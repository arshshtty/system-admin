# System Admin Toolkit

A comprehensive collection of scripts, configurations, and tools for managing home servers, bare metal machines, and VPS instances.

## Overview

This repository provides ready-to-use automation scripts for:
- **Server bootstrapping** - Get new servers production-ready in minutes with essential tools
- **Development environment setup** - Docker, Zsh, modern CLI tools, Node.js, Python, and more
- **Health monitoring** - Real-time multi-server monitoring with Prometheus + Grafana
- **Log aggregation** - Centralized logging with Loki or ELK stack
- **Security tools** - Baseline audits, SSL management, automated updates
- **Network diagnostics** - Comprehensive network testing and troubleshooting
- **Backup automation** - Files, databases, Docker volumes with retention policies
- **Docker management** - Intelligent cleanup, Swarm orchestration helpers
- **Multi-server management** - Ansible playbooks and YAML-based inventory
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

## 🎨 Interactive TUI (NEW!)

**Prefer a visual interface?** We now have a friendly Terminal User Interface!

```bash
# Install dependencies
pip install -r requirements.txt

# Launch the TUI
./admin.py
```

The TUI provides:
- **Guided workflows** for common tasks (Docker cleanup, backups, monitoring, bootstrapping)
- **Command preview** - See the exact CLI command before execution
- **Educational design** - Learn the CLI as you use the interface
- **Safe by default** - Dry-run mode enabled for destructive operations
- **All the scripts** in one easy-to-navigate menu

Perfect for newcomers and occasional users! Power users can still use the scripts directly.

📖 **[Read the TUI Guide](TUI_GUIDE.md)** for detailed usage instructions.

## Repository Structure

```
system-admin/
├── scripts/
│   ├── bootstrap/          # Initial server setup scripts
│   │   └── install-essentials.sh
│   ├── monitoring/         # Health checks and monitoring stacks
│   │   ├── health-check.py
│   │   ├── web-dashboard.py
│   │   └── setup-prometheus-grafana.sh
│   ├── backup/            # Backup and recovery scripts
│   │   └── backup-manager.sh
│   ├── security/          # Security tools and hardening
│   │   ├── security-audit.sh
│   │   ├── ssl-manager.sh
│   │   └── auto-updates.sh
│   ├── docker/            # Docker management scripts
│   │   └── docker-cleanup.sh
│   ├── network/           # Network diagnostics tools
│   │   └── network-diagnostics.sh
│   ├── logging/           # Log aggregation setup
│   │   └── setup-log-aggregation.sh
│   ├── orchestration/     # Container orchestration helpers
│   │   └── docker-swarm-helper.sh
│   └── utils/             # Utility scripts
├── ansible/               # Ansible automation
│   ├── playbooks/         # Ready-to-use playbooks
│   ├── roles/             # Custom roles
│   └── inventories/       # Inventory files
├── configs/
│   ├── templates/         # Configuration templates
│   └── examples/          # Example configurations
├── dotfiles/              # Dotfiles for development
│   ├── .zshrc
│   ├── .vimrc
│   ├── .gitconfig
│   └── .tmux.conf
├── inventory/             # Server inventory files (YAML)
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

### 4. Security Tools

#### Security Baseline Audit (`scripts/security/security-audit.sh`)

Comprehensive security auditing for Linux servers.

**Features:**
- SSH configuration analysis
- Firewall status checks
- User account auditing
- Open ports scanning
- Failed login attempts monitoring
- Security updates checking
- File permissions validation
- Kernel security parameters review

**Quick Start:**
```bash
# Run security audit
sudo ./scripts/security/security-audit.sh

# Save report to file
sudo ./scripts/security/security-audit.sh --output security-report.txt

# JSON output
sudo ./scripts/security/security-audit.sh --json --output report.json

# Verbose mode
sudo ./scripts/security/security-audit.sh --verbose
```

#### SSL Certificate Management (`scripts/security/ssl-manager.sh`)

Manage SSL/TLS certificates with ease.

**Features:**
- Let's Encrypt certificate issuance
- Self-signed certificate generation
- Certificate renewal automation
- Expiry monitoring
- Multi-domain support

**Quick Start:**
```bash
# Issue Let's Encrypt certificate
sudo ./scripts/security/ssl-manager.sh issue --domain example.com --email admin@example.com --webroot /var/www/html

# Issue self-signed certificate
sudo ./scripts/security/ssl-manager.sh issue --domain localhost --self-signed

# Check certificate expiry
./scripts/security/ssl-manager.sh check --domain example.com

# Renew all certificates
sudo ./scripts/security/ssl-manager.sh renew --all

# List all certificates
./scripts/security/ssl-manager.sh list

# Setup automatic renewal
sudo ./scripts/security/ssl-manager.sh auto-renew
```

#### Automated Security Updates (`scripts/security/auto-updates.sh`)

Configure automatic security updates for Ubuntu/Debian.

**Features:**
- Automatic security patch installation
- Optional auto-reboot after updates
- Email notifications
- Interactive configuration wizard

**Quick Start:**
```bash
# Enable automatic updates
sudo ./scripts/security/auto-updates.sh enable

# Enable with auto-reboot at 3 AM
sudo ./scripts/security/auto-updates.sh enable --auto-reboot --reboot-time 03:00

# Enable with email notifications
sudo ./scripts/security/auto-updates.sh enable --email admin@example.com

# Check status
sudo ./scripts/security/auto-updates.sh status

# Interactive configuration
sudo ./scripts/security/auto-updates.sh configure

# Run updates now
sudo ./scripts/security/auto-updates.sh update-now
```

### 5. Network Diagnostics (`scripts/network/network-diagnostics.sh`)

Comprehensive network troubleshooting and testing toolkit.

**Features:**
- Quick health checks
- Latency and packet loss testing
- DNS diagnostics
- Port connectivity testing
- Traceroute analysis
- Interface information
- Speed testing

**Quick Start:**
```bash
# Quick network check
./scripts/network/network-diagnostics.sh check

# Test connectivity to host
./scripts/network/network-diagnostics.sh connectivity --host google.com

# DNS diagnostics
./scripts/network/network-diagnostics.sh dns --host example.com

# Check if port is open
./scripts/network/network-diagnostics.sh ports --host example.com --port 443

# Scan common ports
./scripts/network/network-diagnostics.sh ports --host example.com

# Test latency
./scripts/network/network-diagnostics.sh latency --host 8.8.8.8 --count 20

# Traceroute
./scripts/network/network-diagnostics.sh traceroute --host google.com

# Show interfaces
./scripts/network/network-diagnostics.sh interfaces

# Full diagnostic report
./scripts/network/network-diagnostics.sh report --output network-report.txt
```

### 6. Monitoring Stack Setup

#### Prometheus + Grafana (`scripts/monitoring/setup-prometheus-grafana.sh`)

Deploy a complete monitoring stack with Prometheus, Grafana, Node Exporter, and cAdvisor.

**Features:**
- One-command deployment
- Pre-configured dashboards
- Alert rules included
- Docker-based (easy to manage)
- Auto-configured data sources

**Quick Start:**
```bash
# Install monitoring stack
./scripts/monitoring/setup-prometheus-grafana.sh install

# Custom installation directory and ports
./scripts/monitoring/setup-prometheus-grafana.sh --install-dir /opt/monitoring --grafana-port 8080 install

# Start services
./scripts/monitoring/setup-prometheus-grafana.sh start

# Check status
./scripts/monitoring/setup-prometheus-grafana.sh status

# View logs
./scripts/monitoring/setup-prometheus-grafana.sh logs

# Stop services
./scripts/monitoring/setup-prometheus-grafana.sh stop

# Uninstall
./scripts/monitoring/setup-prometheus-grafana.sh uninstall
```

**Access Points:**
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin123)
- Node Exporter: http://localhost:9100
- cAdvisor: http://localhost:8081

### 7. Log Aggregation (`scripts/logging/setup-log-aggregation.sh`)

Deploy centralized logging with Loki/Promtail/Grafana or ELK stack.

**Features:**
- Choice of Loki (lightweight) or ELK (full-featured)
- Automatic log collection from system and Docker
- Web-based log viewing and searching
- Configurable retention policies

**Quick Start:**
```bash
# Install Loki stack (recommended)
./scripts/logging/setup-log-aggregation.sh install

# Install ELK stack
./scripts/logging/setup-log-aggregation.sh --stack elk install

# Start services
./scripts/logging/setup-log-aggregation.sh start

# Check status
./scripts/logging/setup-log-aggregation.sh status

# View logs
./scripts/logging/setup-log-aggregation.sh logs

# Stop services
./scripts/logging/setup-log-aggregation.sh stop
```

**Access Points:**
- Loki Stack:
  - Grafana: http://localhost:3001 (admin/admin123)
  - Loki API: http://localhost:3100
- ELK Stack:
  - Kibana: http://localhost:5601
  - Elasticsearch: http://localhost:9200

### 8. Container Orchestration

#### Docker Swarm Helper (`scripts/orchestration/docker-swarm-helper.sh`)

Simplify Docker Swarm cluster management.

**Features:**
- Easy cluster initialization
- Stack deployment helpers
- Service scaling
- Backup and restore
- Status monitoring

**Quick Start:**
```bash
# Initialize swarm
./scripts/orchestration/docker-swarm-helper.sh init --advertise-addr 192.168.1.100

# Show cluster status
./scripts/orchestration/docker-swarm-helper.sh status

# Deploy a stack
./scripts/orchestration/docker-swarm-helper.sh deploy --file docker-compose.yml --name myapp

# Scale a service
./scripts/orchestration/docker-swarm-helper.sh scale --service myapp_web --replicas 5

# Update service
./scripts/orchestration/docker-swarm-helper.sh update --service myapp_web --image nginx:latest

# Rollback service
./scripts/orchestration/docker-swarm-helper.sh rollback --service myapp_web

# Backup swarm configuration
./scripts/orchestration/docker-swarm-helper.sh backup

# Remove a stack
./scripts/orchestration/docker-swarm-helper.sh remove --name myapp
```

### 9. Ansible Automation (`ansible/`)

Pre-built Ansible playbooks for common server management tasks.

**Available Playbooks:**
- `server-setup.yml` - Initial server configuration
- `security-hardening.yml` - Apply security best practices
- `install-docker.yml` - Install Docker on target servers
- `update-servers.yml` - Update all packages

**Quick Start:**
```bash
# Install Ansible
sudo apt install ansible

# Create inventory
cp ansible/inventories/hosts.example.yml ansible/inventories/hosts.yml
# Edit hosts.yml with your servers

# Test connectivity
ansible all -i ansible/inventories/hosts.yml -m ping

# Run server setup
ansible-playbook -i ansible/inventories/hosts.yml ansible/playbooks/server-setup.yml

# Apply security hardening
ansible-playbook -i ansible/inventories/hosts.yml ansible/playbooks/security-hardening.yml

# Install Docker on all servers
ansible-playbook -i ansible/inventories/hosts.yml ansible/playbooks/install-docker.yml

# Update all servers
ansible-playbook -i ansible/inventories/hosts.yml ansible/playbooks/update-servers.yml
```

### 10. Firewall Management (`scripts/security/firewall-manager.sh`)

Simplified UFW/iptables firewall management with preset profiles.

**Features:**
- Easy firewall rule management
- Preset profiles (web, ssh, database, docker)
- IP-based access control
- Rule backup and logs
- Dry-run mode

**Quick Start:**
```bash
# Enable firewall
sudo ./scripts/security/firewall-manager.sh enable

# Apply web server preset
sudo ./scripts/security/firewall-manager.sh preset web

# Allow traffic from specific IP
sudo ./scripts/security/firewall-manager.sh allow-from 192.168.1.100

# Block an IP
sudo ./scripts/security/firewall-manager.sh deny-from 10.0.0.50

# Show firewall status
./scripts/security/firewall-manager.sh status
```

### 11. Alert Notification System (`scripts/alerting/notify.sh`)

Multi-channel alerting via ntfy.sh, Slack, Discord, and email.

**Features:**
- Multiple notification channels
- Alert levels (info, warning, error, critical)
- Configuration file support
- Test mode

**Quick Start:**
```bash
# Configure (create ~/.notify.conf)
cat > ~/.notify.conf << EOF
NTFY_TOPIC="myserver-alerts"
SLACK_WEBHOOK="https://hooks.slack.com/..."
EMAIL_TO="admin@example.com"
EOF

# Send alert
./scripts/alerting/notify.sh -c all -l critical "Disk full on /var"

# Test notifications
./scripts/alerting/notify.sh --test
```

### 12. Disk Cleanup (`scripts/disk/cleanup-old-files.sh`)

Automated disk space cleanup with safety features.

**Features:**
- Clean temp files, logs, caches
- Configurable retention periods
- Dry-run mode (enabled by default)
- Disk usage analysis

**Quick Start:**
```bash
# Analyze disk usage
./scripts/disk/cleanup-old-files.sh analyze

# Clean temp files (dry-run)
./scripts/disk/cleanup-old-files.sh --days 7 clean-temp

# Clean everything (actual cleanup)
sudo ./scripts/disk/cleanup-old-files.sh --execute clean-all
```

### 13. Nginx Configuration Generator (`scripts/web/nginx-config-gen.sh`)

Generate nginx configurations for common use cases.

**Features:**
- Templates for static sites, reverse proxy, PHP, WordPress
- SSL/TLS support
- Load balancer configurations
- Auto-enable sites

**Quick Start:**
```bash
# Static website
./scripts/web/nginx-config-gen.sh static example.com --root /var/www/example

# Reverse proxy
./scripts/web/nginx-config-gen.sh reverse-proxy app.example.com --port 3000 --ssl

# Load balancer
./scripts/web/nginx-config-gen.sh load-balancer api.example.com \\
    --backends "10.0.0.1:8080,10.0.0.2:8080"
```

### 14. Systemd Service Generator (`scripts/services/create-service.sh`)

Interactive systemd service file creator with best practices.

**Features:**
- Interactive mode
- Resource limits (CPU, memory)
- Auto-restart policies
- Environment variable support
- User/group management

**Quick Start:**
```bash
# Interactive mode
sudo ./scripts/services/create-service.sh --interactive

# Create service
sudo ./scripts/services/create-service.sh \\
    --name myapp \\
    --exec "/opt/myapp/start.sh" \\
    --user appuser \\
    --workdir /opt/myapp \\
    --restart always \\
    --enable --start
```

### 15. User Management (`scripts/users/`)

Standardized user provisioning and SSH key management.

**Manage Users (`manage-users.sh`):**
```bash
# Create user with sudo access
sudo ./scripts/users/manage-users.sh create john --sudo --groups docker

# Create service account
sudo ./scripts/users/manage-users.sh create appuser --shell /bin/false

# List all sudo users
sudo ./scripts/users/manage-users.sh list-sudo

# Audit user accounts
sudo ./scripts/users/manage-users.sh audit
```

**Deploy SSH Keys (`deploy-keys.sh`):**
```bash
# Deploy key to multiple servers
./scripts/users/deploy-keys.sh \\
    --key-file ~/.ssh/id_rsa.pub \\
    --servers servers.txt \\
    --user deploy
```

### 16. VPN Setup (`scripts/vpn/wireguard-setup.sh`)

Easy WireGuard VPN deployment with QR codes for mobile clients.

**Quick Start:**
```bash
# Install WireGuard
sudo ./scripts/vpn/wireguard-setup.sh install

# Setup server
sudo ./scripts/vpn/wireguard-setup.sh setup-server

# Add client
sudo ./scripts/vpn/wireguard-setup.sh add-client laptop

# Show QR code for mobile
sudo ./scripts/vpn/wireguard-setup.sh show-qr laptop

# Check status
sudo ./scripts/vpn/wireguard-setup.sh status
```

### 17. Database Optimization (`scripts/database/db-optimize.sh`)

Database maintenance and optimization for MySQL and PostgreSQL.

**Quick Start:**
```bash
# Analyze database performance
./scripts/database/db-optimize.sh analyze --type mysql

# Optimize MySQL tables
./scripts/database/db-optimize.sh optimize --type mysql --database myapp

# Vacuum PostgreSQL
sudo ./scripts/database/db-optimize.sh vacuum --type postgresql

# Show slow queries
./scripts/database/db-optimize.sh slow-queries --type mysql
```

### 18. System Performance Tuning (`scripts/performance/tune-system.sh`)

Optimize Linux kernel parameters for better performance.

**Quick Start:**
```bash
# Analyze current performance
./scripts/performance/tune-system.sh analyze

# Apply all optimizations
sudo ./scripts/performance/tune-system.sh tune-all

# Create swap file
sudo ./scripts/performance/tune-system.sh create-swap 4G

# Adjust swappiness
sudo ./scripts/performance/tune-system.sh adjust-swappiness 10
```

### 19. Runbooks (`docs/runbooks/`)

Step-by-step procedures for common system administration tasks.

**Available Runbooks:**
- `disk-full.md` - Diagnose and resolve disk space issues
- `high-cpu.md` - Handle high CPU usage situations
- `service-down.md` - Restore downed services

Each runbook includes:
- Immediate diagnosis steps
- Common causes and solutions
- Prevention measures
- Verification steps

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
- [x] Security baseline audit script
- [x] SSL certificate management
- [x] Monitoring stack setup (Prometheus + Grafana)
- [x] Ansible playbooks for common tasks
- [x] Network diagnostics and testing tools
- [x] Log aggregation setup
- [x] Automated security updates management
- [x] Container orchestration helpers (Docker Swarm)
- [x] Firewall management with UFW
- [x] Multi-channel alert notification system
- [x] Disk cleanup automation
- [x] Nginx configuration generator
- [x] Systemd service generator
- [x] User management and provisioning
- [x] SSH key deployment tool
- [x] WireGuard VPN setup
- [x] Database optimization tools
- [x] System performance tuning
- [x] Runbooks for common issues

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

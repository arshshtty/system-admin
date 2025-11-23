#!/usr/bin/env bash
#
# One-Liner Installer Generator
# Creates curl|bash style installers for common setups
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository settings
REPO_URL="${REPO_URL:-https://github.com/arshshtty/system-admin}"
RAW_URL="${RAW_URL:-https://raw.githubusercontent.com/arshshtty/system-admin/main}"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to show help
show_help() {
    cat << EOF
One-Liner Installer Generator

Creates easy-to-share installation commands for common setups.

USAGE:
    $(basename "$0") [COMMAND]

COMMANDS:
    bootstrap       Generate installer for server bootstrap
    docker          Generate installer for Docker setup
    monitoring      Generate installer for monitoring stack
    security        Generate installer for security tools
    all             Show all available one-liners
    generate        Generate installation wrapper scripts
    --help          Show this help message

EXAMPLES:
    # Show bootstrap one-liner
    $(basename "$0") bootstrap

    # Show all available one-liners
    $(basename "$0") all

    # Generate wrapper scripts for hosting
    $(basename "$0") generate

GENERATED ONE-LINERS:
    These commands can be shared with others for quick installation.
    They download and execute the installation scripts directly from GitHub.

SECURITY NOTE:
    Only run curl|bash commands from trusted sources!
    Always review scripts before execution when possible.
EOF
}

# Function to generate bootstrap installer
generate_bootstrap() {
    cat << 'EOF'
# ========================================
# Server Bootstrap One-Liner
# ========================================

# Full installation (recommended)
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/bootstrap/install-essentials.sh | bash

# Or with specific components:
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/bootstrap/install-essentials.sh | bash -s -- --core --docker --shell

# Components available:
# --core       : Core tools (git, vim, tmux, etc.)
# --docker     : Docker + Docker Compose
# --shell      : Zsh + oh-my-zsh
# --languages  : Node.js, Python tooling
# --modern-cli : Modern CLI tools (bat, exa, etc.)
# --dotfiles   : Install dotfiles
# --all        : Everything (default)

EOF
}

# Function to generate Docker installer
generate_docker() {
    cat << 'EOF'
# ========================================
# Docker Quick Install
# ========================================

# Install Docker Engine + Compose (rootless)
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/bootstrap/install-essentials.sh | bash -s -- --docker

# Docker cleanup one-liner
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/docker/docker-cleanup.sh | bash -s -- --all --dry-run

EOF
}

# Function to generate monitoring installer
generate_monitoring() {
    cat << 'EOF'
# ========================================
# Monitoring Stack One-Liner
# ========================================

# Install Prometheus + Grafana
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/monitoring/setup-prometheus-grafana.sh | bash -s -- install

# Or clone repo and use detailed setup:
git clone https://github.com/arshshtty/system-admin.git
cd system-admin
./scripts/monitoring/setup-prometheus-grafana.sh install

# Setup health monitoring
git clone https://github.com/arshshtty/system-admin.git
cd system-admin
pip3 install -r requirements.txt
cp inventory/example.yaml inventory/servers.yaml
# Edit servers.yaml with your servers
./scripts/monitoring/start-monitoring.sh

EOF
}

# Function to generate security installer
generate_security() {
    cat << 'EOF'
# ========================================
# Security Tools One-Liner
# ========================================

# Run security audit
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/security/security-audit.sh | sudo bash

# Enable automatic security updates
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/security/auto-updates.sh | sudo bash -s -- enable

# Issue Let's Encrypt certificate
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/security/ssl-manager.sh | sudo bash -s -- issue --domain example.com --email admin@example.com

EOF
}

# Function to generate network tools installer
generate_network() {
    cat << 'EOF'
# ========================================
# Network Diagnostics One-Liner
# ========================================

# Quick network check
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/network/network-diagnostics.sh | bash -s -- check

# Full diagnostic report
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/network/network-diagnostics.sh | bash -s -- report

EOF
}

# Function to generate backup installer
generate_backup() {
    cat << 'EOF'
# ========================================
# Backup Manager One-Liner
# ========================================

# Clone and setup backup manager
git clone https://github.com/arshshtty/system-admin.git
cd system-admin
./scripts/backup/backup-manager.sh --dry-run

# Configure backup settings by editing the script
# Then run: ./scripts/backup/backup-manager.sh

EOF
}

# Function to generate complete repo clone
generate_repo_clone() {
    cat << 'EOF'
# ========================================
# Complete Repository Setup
# ========================================

# Clone entire toolkit
git clone https://github.com/arshshtty/system-admin.git
cd system-admin

# Run bootstrap
./scripts/bootstrap/install-essentials.sh

# Setup monitoring (optional)
pip3 install -r requirements.txt
cp inventory/example.yaml inventory/servers.yaml
# Edit servers.yaml, then:
./scripts/monitoring/start-monitoring.sh

EOF
}

# Function to show all one-liners
show_all() {
    echo "================================================"
    echo "System Admin Toolkit - One-Liner Installers"
    echo "================================================"
    echo
    echo "Quick Start (Full Bootstrap):"
    echo "------------------------------"
    echo -e "${GREEN}curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/bootstrap/install-essentials.sh | bash${NC}"
    echo

    generate_bootstrap
    generate_docker
    generate_monitoring
    generate_security
    generate_network
    generate_backup
    generate_repo_clone

    cat << 'EOF'

# ========================================
# Utility Scripts One-Liners
# ========================================

# Auto-discover servers on network
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/utils/inventory-discovery.sh | bash -s -- --subnet 192.168.1.0/24

# Quick troubleshooting
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/utils/quick-troubleshoot.sh | bash

# Sync dotfiles across servers
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/utils/sync-dotfiles.sh | bash -s -- --servers server1,server2

# Set timezone
curl -fsSL https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/utils/set-timezone.sh | sudo bash -s -- --timezone America/New_York

================================================
Repository: https://github.com/arshshtty/system-admin
Documentation: See README.md in the repository
================================================

EOF
}

# Function to generate wrapper scripts for self-hosting
generate_wrappers() {
    local output_dir="installers"
    mkdir -p "$output_dir"

    print_info "Generating wrapper scripts in $output_dir/"

    # Bootstrap wrapper
    cat > "$output_dir/bootstrap.sh" << 'EOF'
#!/usr/bin/env bash
# Bootstrap installer wrapper
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/bootstrap/install-essentials.sh"

echo "Downloading and running bootstrap script..."
curl -fsSL "$SCRIPT_URL" | bash -s -- "$@"
EOF
    chmod +x "$output_dir/bootstrap.sh"

    # Docker wrapper
    cat > "$output_dir/docker-install.sh" << 'EOF'
#!/usr/bin/env bash
# Docker installer wrapper
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/bootstrap/install-essentials.sh"

echo "Installing Docker..."
curl -fsSL "$SCRIPT_URL" | bash -s -- --docker
EOF
    chmod +x "$output_dir/docker-install.sh"

    # Security audit wrapper
    cat > "$output_dir/security-audit.sh" << 'EOF'
#!/usr/bin/env bash
# Security audit wrapper
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/security/security-audit.sh"

echo "Running security audit..."
curl -fsSL "$SCRIPT_URL" | sudo bash -s -- "$@"
EOF
    chmod +x "$output_dir/security-audit.sh"

    # Monitoring setup wrapper
    cat > "$output_dir/monitoring-install.sh" << 'EOF'
#!/usr/bin/env bash
# Monitoring installer wrapper
set -euo pipefail

SCRIPT_URL="https://raw.githubusercontent.com/arshshtty/system-admin/main/scripts/monitoring/setup-prometheus-grafana.sh"

echo "Installing monitoring stack..."
curl -fsSL "$SCRIPT_URL" | bash -s -- install
EOF
    chmod +x "$output_dir/monitoring-install.sh"

    # Create README
    cat > "$output_dir/README.md" << 'EOF'
# One-Liner Installers

This directory contains wrapper scripts for easy distribution.

## Usage

You can host these scripts on your own server and provide simple installation commands:

```bash
# If hosted at https://yourserver.com/installers/

# Bootstrap installation
curl -fsSL https://yourserver.com/installers/bootstrap.sh | bash

# Docker installation
curl -fsSL https://yourserver.com/installers/docker-install.sh | bash

# Security audit
curl -fsSL https://yourserver.com/installers/security-audit.sh | bash

# Monitoring stack
curl -fsSL https://yourserver.com/installers/monitoring-install.sh | bash
```

## Hosting

To host these installers:

1. Upload the scripts to a web server
2. Ensure they're accessible via HTTPS
3. Share the installation commands with your team

## Security

Always review scripts before executing them with curl|bash.
These wrappers simply download and execute the scripts from the main repository.
EOF

    print_success "Generated wrapper scripts in $output_dir/"
    print_info "See $output_dir/README.md for usage instructions"
}

# Parse command line arguments
case "${1:-all}" in
    bootstrap)
        generate_bootstrap
        ;;
    docker)
        generate_docker
        ;;
    monitoring)
        generate_monitoring
        ;;
    security)
        generate_security
        ;;
    network)
        generate_network
        ;;
    backup)
        generate_backup
        ;;
    all)
        show_all
        ;;
    generate)
        generate_wrappers
        ;;
    --help)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo
        show_help
        exit 1
        ;;
esac

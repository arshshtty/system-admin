#!/usr/bin/env bash

set -euo pipefail

# Automated Security Updates Management
# Configures and manages automatic security updates for Ubuntu/Debian

VERSION="1.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default settings
DRY_RUN=false
AUTO_REBOOT=false
REBOOT_TIME="02:00"
EMAIL_NOTIFY=""

# Show help
show_help() {
    cat << EOF
Automated Security Updates Management v${VERSION}

Usage: $(basename "$0") COMMAND [options]

Commands:
  enable          Enable automatic security updates
  disable         Disable automatic security updates
  status          Show current configuration
  update-now      Run security updates immediately
  configure       Interactive configuration wizard

Options:
  --auto-reboot           Enable automatic reboot after updates
  --reboot-time TIME      Reboot time (default: 02:00)
  --email EMAIL           Email for notifications
  --dry-run               Test without making changes
  --help                  Show this help message

Examples:
  # Enable automatic security updates
  $(basename "$0") enable

  # Enable with automatic reboot at 3 AM
  $(basename "$0") enable --auto-reboot --reboot-time 03:00

  # Enable with email notifications
  $(basename "$0") enable --email admin@example.com

  # Check current status
  $(basename "$0") status

  # Run updates now
  $(basename "$0") update-now

  # Interactive configuration
  $(basename "$0") configure

EOF
}

# Logging functions
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This command requires root privileges"
        exit 1
    fi
}

# Check if unattended-upgrades is installed
check_installation() {
    if ! dpkg -l | grep -q "^ii.*unattended-upgrades"; then
        log_warning "unattended-upgrades is not installed"
        return 1
    fi
    return 0
}

# Install unattended-upgrades
install_unattended_upgrades() {
    log_info "Installing unattended-upgrades..."

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would install unattended-upgrades"
        return 0
    fi

    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades apt-listchanges

    log_success "unattended-upgrades installed"
}

# Configure unattended-upgrades
configure_unattended_upgrades() {
    check_root

    log_info "Configuring unattended-upgrades..."

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would configure unattended-upgrades"
        return 0
    fi

    # Backup existing configuration
    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
        cp /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.backup
    fi

    # Create configuration
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
// Automatically upgrade packages from these origins
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

// List of packages to not update
Unattended-Upgrade::Package-Blacklist {
    // Add packages here if needed
    // "vim";
    // "libc6";
};

// Do automatic removal of unused dependencies
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Do automatic removal of new unused dependencies
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";

// Automatically reboot *WITHOUT CONFIRMATION* if needed
Unattended-Upgrade::Automatic-Reboot "false";

// Automatically reboot at the specific time
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Email notification settings
// Unattended-Upgrade::Mail "";
// Unattended-Upgrade::MailReport "on-change";

// Update package list automatically
Unattended-Upgrade::Update-Days {"Mon";"Tue";"Wed";"Thu";"Fri";"Sat";"Sun";};

// Enable logging
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";

// Minimal steps to ensure updates are applied
Unattended-Upgrade::MinimalSteps "true";
EOF

    # Enable auto reboot if requested
    if [ "$AUTO_REBOOT" = true ]; then
        sed -i 's/Unattended-Upgrade::Automatic-Reboot "false"/Unattended-Upgrade::Automatic-Reboot "true"/' /etc/apt/apt.conf.d/50unattended-upgrades
        sed -i "s/Unattended-Upgrade::Automatic-Reboot-Time \"02:00\"/Unattended-Upgrade::Automatic-Reboot-Time \"$REBOOT_TIME\"/" /etc/apt/apt.conf.d/50unattended-upgrades
        log_info "Automatic reboot enabled at $REBOOT_TIME"
    fi

    # Configure email if provided
    if [ -n "$EMAIL_NOTIFY" ]; then
        sed -i "s|// Unattended-Upgrade::Mail \"\"|Unattended-Upgrade::Mail \"$EMAIL_NOTIFY\"|" /etc/apt/apt.conf.d/50unattended-upgrades
        sed -i 's|// Unattended-Upgrade::MailReport "on-change"|Unattended-Upgrade::MailReport "on-change"|' /etc/apt/apt.conf.d/50unattended-upgrades
        log_info "Email notifications configured for $EMAIL_NOTIFY"
    fi

    # Enable periodic updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF

    log_success "Configuration completed"
}

# Enable automatic updates
enable_updates() {
    check_root

    log_info "Enabling automatic security updates..."

    # Install if not present
    if ! check_installation; then
        install_unattended_upgrades
    fi

    # Configure
    configure_unattended_upgrades

    # Enable and start the service
    if [ "$DRY_RUN" = false ]; then
        systemctl enable unattended-upgrades
        systemctl start unattended-upgrades
    fi

    log_success "Automatic security updates enabled"

    # Show status
    show_status
}

# Disable automatic updates
disable_updates() {
    check_root

    log_info "Disabling automatic security updates..."

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would disable automatic updates"
        return 0
    fi

    # Disable the service
    systemctl stop unattended-upgrades 2>/dev/null || true
    systemctl disable unattended-upgrades 2>/dev/null || true

    # Disable in configuration
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
EOF

    log_success "Automatic security updates disabled"
}

# Show current status
show_status() {
    log_info "Current Automatic Updates Status"
    echo ""

    # Check if installed
    if ! check_installation; then
        log_error "unattended-upgrades is not installed"
        echo ""
        log_info "Run '$(basename "$0") enable' to set up automatic updates"
        return 1
    fi

    log_success "unattended-upgrades is installed"

    # Check service status
    if systemctl is-active --quiet unattended-upgrades; then
        log_success "Service is running"
    else
        log_warning "Service is not running"
    fi

    if systemctl is-enabled --quiet unattended-upgrades 2>/dev/null; then
        log_success "Service is enabled"
    else
        log_warning "Service is not enabled"
    fi

    # Check configuration
    echo ""
    log_info "Configuration:"

    if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
        local update_enabled=$(grep -oP 'APT::Periodic::Update-Package-Lists "\K\d+' /etc/apt/apt.conf.d/20auto-upgrades || echo "0")
        local upgrade_enabled=$(grep -oP 'APT::Periodic::Unattended-Upgrade "\K\d+' /etc/apt/apt.conf.d/20auto-upgrades || echo "0")

        if [ "$update_enabled" = "1" ]; then
            log_success "Package list updates: Enabled (daily)"
        else
            log_warning "Package list updates: Disabled"
        fi

        if [ "$upgrade_enabled" = "1" ]; then
            log_success "Automatic upgrades: Enabled"
        else
            log_warning "Automatic upgrades: Disabled"
        fi
    fi

    if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
        local auto_reboot=$(grep -oP 'Unattended-Upgrade::Automatic-Reboot "\K(true|false)' /etc/apt/apt.conf.d/50unattended-upgrades || echo "false")
        local reboot_time=$(grep -oP 'Unattended-Upgrade::Automatic-Reboot-Time "\K[^"]+' /etc/apt/apt.conf.d/50unattended-upgrades || echo "N/A")

        if [ "$auto_reboot" = "true" ]; then
            log_info "Automatic reboot: Enabled at $reboot_time"
        else
            log_info "Automatic reboot: Disabled"
        fi

        local email=$(grep -oP 'Unattended-Upgrade::Mail "\K[^"]+' /etc/apt/apt.conf.d/50unattended-upgrades || echo "")
        if [ -n "$email" ]; then
            log_info "Email notifications: $email"
        else
            log_info "Email notifications: Not configured"
        fi
    fi

    # Check last run
    echo ""
    log_info "Recent activity:"
    if [ -f /var/log/unattended-upgrades/unattended-upgrades.log ]; then
        echo "Last 5 log entries:"
        tail -n 5 /var/log/unattended-upgrades/unattended-upgrades.log
    else
        log_warning "No log file found yet"
    fi
}

# Run updates now
update_now() {
    check_root

    log_info "Running security updates now..."

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would run: unattended-upgrade --dry-run"
        unattended-upgrade --dry-run
    else
        log_info "This may take several minutes..."
        unattended-upgrade --debug --verbose
        log_success "Updates completed"
    fi
}

# Interactive configuration wizard
configure_wizard() {
    check_root

    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Automatic Updates Configuration Wizard${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"
    echo ""

    # Check if installed
    if ! check_installation; then
        read -p "unattended-upgrades is not installed. Install it now? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            install_unattended_upgrades
        else
            log_info "Installation cancelled"
            exit 0
        fi
    fi

    # Ask about auto-reboot
    read -p "Enable automatic reboot after updates? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        AUTO_REBOOT=true
        read -p "Enter reboot time (HH:MM, default 02:00): " reboot_input
        if [ -n "$reboot_input" ]; then
            REBOOT_TIME="$reboot_input"
        fi
    fi

    # Ask about email notifications
    read -p "Configure email notifications? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter email address: " email_input
        if [ -n "$email_input" ]; then
            EMAIL_NOTIFY="$email_input"
        fi
    fi

    # Confirm configuration
    echo ""
    log_info "Configuration Summary:"
    echo "  Automatic reboot: $AUTO_REBOOT"
    if [ "$AUTO_REBOOT" = true ]; then
        echo "  Reboot time: $REBOOT_TIME"
    fi
    if [ -n "$EMAIL_NOTIFY" ]; then
        echo "  Email notifications: $EMAIL_NOTIFY"
    fi
    echo ""

    read -p "Apply this configuration? (Y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        enable_updates
        log_success "Configuration applied successfully!"
    else
        log_info "Configuration cancelled"
    fi
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto-reboot)
                AUTO_REBOOT=true
                shift
                ;;
            --reboot-time)
                REBOOT_TIME="$2"
                shift 2
                ;;
            --email)
                EMAIL_NOTIFY="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            enable|disable|status|update-now|configure)
                command="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [ -z "$command" ]; then
        log_error "No command specified"
        show_help
        exit 1
    fi

    case $command in
        enable)
            enable_updates
            ;;
        disable)
            disable_updates
            ;;
        status)
            show_status
            ;;
        update-now)
            update_now
            ;;
        configure)
            configure_wizard
            ;;
    esac
}

main "$@"

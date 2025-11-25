#!/usr/bin/env bash
#
# Firewall Manager - Simplified UFW/iptables management
# Manage firewall rules with ease and safety
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DRY_RUN=false
FORCE=false
BACKEND="ufw"  # ufw or iptables

#######################################
# Print colored output
#######################################
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

#######################################
# Show help message
#######################################
show_help() {
    cat << EOF
Firewall Manager - Simplified firewall management for Ubuntu/Debian

USAGE:
    $(basename "$0") [OPTIONS] COMMAND [ARGS]

COMMANDS:
    status                  Show firewall status
    enable                  Enable firewall
    disable                 Disable firewall
    reset                   Reset firewall to defaults

    allow PORT [PROTOCOL]   Allow incoming traffic on port (default: tcp)
    deny PORT [PROTOCOL]    Deny incoming traffic on port
    delete PORT [PROTOCOL]  Delete firewall rule for port

    allow-from IP [PORT]    Allow traffic from specific IP (optionally on port)
    deny-from IP            Deny traffic from specific IP

    list                    List all firewall rules
    list-numbered           List rules with numbers (for deletion)

    preset PROFILE          Apply preset firewall profile
                           Profiles: web, ssh, database, docker, minimal

    backup [FILE]           Backup current firewall rules
    restore FILE            Restore firewall rules from backup

    logs [LINES]            Show recent firewall logs (default: 50)

OPTIONS:
    --dry-run              Show what would be done without doing it
    --force                Skip confirmation prompts
    --backend TYPE         Use specific backend (ufw or iptables)
    --help                 Show this help message

EXAMPLES:
    # Enable firewall
    $(basename "$0") enable

    # Allow SSH and HTTP/HTTPS
    $(basename "$0") allow 22
    $(basename "$0") allow 80
    $(basename "$0") allow 443

    # Apply web server preset
    $(basename "$0") preset web

    # Allow traffic from specific IP
    $(basename "$0") allow-from 192.168.1.100

    # Block an IP
    $(basename "$0") deny-from 10.0.0.50

    # Backup current rules
    $(basename "$0") backup firewall-backup.rules

    # View firewall logs
    $(basename "$0") logs 100

PRESET PROFILES:
    minimal    - SSH only (port 22)
    ssh        - SSH with rate limiting
    web        - SSH + HTTP + HTTPS (22, 80, 443)
    database   - SSH + MySQL/PostgreSQL (22, 3306, 5432)
    docker     - SSH + Docker Swarm ports (22, 2377, 7946, 4789)

EOF
}

#######################################
# Check if running as root
#######################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

#######################################
# Check if UFW is installed
#######################################
check_ufw() {
    if ! command -v ufw &> /dev/null; then
        print_error "UFW is not installed. Install it with: apt install ufw"
        exit 1
    fi
}

#######################################
# Execute command (respecting dry-run)
#######################################
execute() {
    local cmd="$*"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY-RUN] Would execute: $cmd"
        return 0
    else
        print_info "Executing: $cmd"
        eval "$cmd"
    fi
}

#######################################
# Confirm action
#######################################
confirm() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    local message="$1"
    read -p "$(echo -e "${YELLOW}${message}${NC} (y/N) ")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        exit 0
    fi
}

#######################################
# Show firewall status
#######################################
cmd_status() {
    check_ufw
    print_info "Firewall status:"
    ufw status verbose
}

#######################################
# Enable firewall
#######################################
cmd_enable() {
    check_root
    check_ufw

    # Make sure SSH is allowed before enabling
    if ! ufw status | grep -q "22.*ALLOW"; then
        print_warning "SSH (port 22) is not allowed! Adding rule to prevent lockout..."
        execute "ufw allow 22/tcp comment 'SSH'"
    fi

    confirm "Enable firewall?"
    execute "ufw --force enable"
    print_success "Firewall enabled"
}

#######################################
# Disable firewall
#######################################
cmd_disable() {
    check_root
    check_ufw

    confirm "Disable firewall? This will leave the system unprotected!"
    execute "ufw --force disable"
    print_success "Firewall disabled"
}

#######################################
# Reset firewall
#######################################
cmd_reset() {
    check_root
    check_ufw

    confirm "Reset firewall to defaults? This will remove all rules!"
    execute "ufw --force reset"
    print_success "Firewall reset to defaults"
}

#######################################
# Allow port
#######################################
cmd_allow() {
    check_root
    check_ufw

    local port="$1"
    local protocol="${2:-tcp}"

    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        print_error "Invalid port number: $port"
        exit 1
    fi

    execute "ufw allow ${port}/${protocol}"
    print_success "Allowed ${protocol} traffic on port ${port}"
}

#######################################
# Deny port
#######################################
cmd_deny() {
    check_root
    check_ufw

    local port="$1"
    local protocol="${2:-tcp}"

    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        print_error "Invalid port number: $port"
        exit 1
    fi

    if [[ "$port" == "22" ]]; then
        print_warning "Blocking SSH (port 22) may lock you out!"
        confirm "Are you sure you want to block SSH?"
    fi

    execute "ufw deny ${port}/${protocol}"
    print_success "Denied ${protocol} traffic on port ${port}"
}

#######################################
# Delete rule for port
#######################################
cmd_delete() {
    check_root
    check_ufw

    local port="$1"
    local protocol="${2:-tcp}"

    execute "ufw delete allow ${port}/${protocol}"
    print_success "Deleted rule for port ${port}/${protocol}"
}

#######################################
# Allow from IP
#######################################
cmd_allow_from() {
    check_root
    check_ufw

    local ip="$1"
    local port="${2:-}"

    if [[ -n "$port" ]]; then
        execute "ufw allow from ${ip} to any port ${port}"
        print_success "Allowed traffic from ${ip} on port ${port}"
    else
        execute "ufw allow from ${ip}"
        print_success "Allowed all traffic from ${ip}"
    fi
}

#######################################
# Deny from IP
#######################################
cmd_deny_from() {
    check_root
    check_ufw

    local ip="$1"

    execute "ufw deny from ${ip}"
    print_success "Denied all traffic from ${ip}"
}

#######################################
# List rules
#######################################
cmd_list() {
    check_ufw
    print_info "Active firewall rules:"
    ufw status numbered
}

#######################################
# Apply preset profile
#######################################
cmd_preset() {
    check_root
    check_ufw

    local profile="$1"

    case "$profile" in
        minimal)
            print_info "Applying minimal profile (SSH only)..."
            execute "ufw allow 22/tcp comment 'SSH'"
            ;;
        ssh)
            print_info "Applying SSH profile with rate limiting..."
            execute "ufw limit 22/tcp comment 'SSH with rate limiting'"
            ;;
        web)
            print_info "Applying web server profile..."
            execute "ufw allow 22/tcp comment 'SSH'"
            execute "ufw allow 80/tcp comment 'HTTP'"
            execute "ufw allow 443/tcp comment 'HTTPS'"
            ;;
        database)
            print_info "Applying database server profile..."
            execute "ufw allow 22/tcp comment 'SSH'"
            execute "ufw allow 3306/tcp comment 'MySQL'"
            execute "ufw allow 5432/tcp comment 'PostgreSQL'"
            ;;
        docker)
            print_info "Applying Docker Swarm profile..."
            execute "ufw allow 22/tcp comment 'SSH'"
            execute "ufw allow 2376/tcp comment 'Docker daemon'"
            execute "ufw allow 2377/tcp comment 'Docker Swarm management'"
            execute "ufw allow 7946/tcp comment 'Docker Swarm nodes (TCP)'"
            execute "ufw allow 7946/udp comment 'Docker Swarm nodes (UDP)'"
            execute "ufw allow 4789/udp comment 'Docker overlay network'"
            ;;
        *)
            print_error "Unknown profile: $profile"
            print_info "Available profiles: minimal, ssh, web, database, docker"
            exit 1
            ;;
    esac

    print_success "Profile '$profile' applied successfully"
}

#######################################
# Backup firewall rules
#######################################
cmd_backup() {
    check_root
    check_ufw

    local backup_file="${1:-firewall-backup-$(date +%Y%m%d-%H%M%S).rules}"

    print_info "Backing up firewall rules to: $backup_file"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "[DRY-RUN] Would backup to: $backup_file"
        return 0
    fi

    # Backup UFW rules
    {
        echo "# UFW Backup - $(date)"
        echo "# Restore with: $(basename "$0") restore $backup_file"
        echo ""
        ufw status numbered
    } > "$backup_file"

    print_success "Firewall rules backed up to: $backup_file"
}

#######################################
# Show firewall logs
#######################################
cmd_logs() {
    local lines="${1:-50}"

    print_info "Recent firewall log entries (last $lines):"

    if [[ -f /var/log/ufw.log ]]; then
        tail -n "$lines" /var/log/ufw.log
    elif journalctl -u ufw &>/dev/null; then
        journalctl -u ufw -n "$lines" --no-pager
    else
        print_warning "No firewall logs found"
    fi
}

#######################################
# Main function
#######################################
main() {
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --backend)
                BACKEND="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done

    # Get command
    local command="${1:-}"

    if [[ -z "$command" ]]; then
        show_help
        exit 1
    fi

    shift

    # Execute command
    case "$command" in
        status)
            cmd_status
            ;;
        enable)
            cmd_enable
            ;;
        disable)
            cmd_disable
            ;;
        reset)
            cmd_reset
            ;;
        allow)
            if [[ $# -lt 1 ]]; then
                print_error "Port number required"
                exit 1
            fi
            cmd_allow "$@"
            ;;
        deny)
            if [[ $# -lt 1 ]]; then
                print_error "Port number required"
                exit 1
            fi
            cmd_deny "$@"
            ;;
        delete)
            if [[ $# -lt 1 ]]; then
                print_error "Port number required"
                exit 1
            fi
            cmd_delete "$@"
            ;;
        allow-from)
            if [[ $# -lt 1 ]]; then
                print_error "IP address required"
                exit 1
            fi
            cmd_allow_from "$@"
            ;;
        deny-from)
            if [[ $# -lt 1 ]]; then
                print_error "IP address required"
                exit 1
            fi
            cmd_deny_from "$@"
            ;;
        list|list-numbered)
            cmd_list
            ;;
        preset)
            if [[ $# -lt 1 ]]; then
                print_error "Profile name required"
                exit 1
            fi
            cmd_preset "$@"
            ;;
        backup)
            cmd_backup "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"

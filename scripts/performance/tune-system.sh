#!/usr/bin/env bash
#
# System Performance Tuning - Optimize Linux system performance
# Tune kernel parameters, swap, and system settings
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
DRY_RUN=false
BACKUP=true

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
# Check root
#######################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

#######################################
# Show help
#######################################
show_help() {
    cat << EOF
System Performance Tuning - Optimize Linux performance

USAGE:
    $(basename "$0") COMMAND [OPTIONS]

COMMANDS:
    analyze                 Analyze current performance
    tune-network            Optimize network settings
    tune-disk               Optimize disk I/O
    tune-memory             Optimize memory management
    tune-all                Apply all optimizations
    create-swap SIZE        Create swap file (e.g., 2G, 4G)
    adjust-swappiness NUM   Set swappiness (0-100)
    restore                 Restore original settings

OPTIONS:
    --dry-run               Show what would be changed
    --no-backup             Don't backup current settings
    --help                  Show this help message

EXAMPLES:
    # Analyze current performance
    $(basename "$0") analyze

    # Tune all settings
    $(basename "$0") tune-all

    # Create 4GB swap file
    $(basename "$0") create-swap 4G

    # Set swappiness to 10
    $(basename "$0") adjust-swappiness 10

    # Tune network only
    $(basename "$0") tune-network

    # Dry run mode
    $(basename "$0") tune-all --dry-run

NOTES:
    - Changes are applied immediately and persist across reboots
    - Original settings are backed up to /etc/sysctl.conf.backup
    - Use with caution on production systems

EOF
}

#######################################
# Backup sysctl
#######################################
backup_sysctl() {
    if [[ "$BACKUP" == "true" ]] && [[ ! -f /etc/sysctl.conf.backup ]]; then
        cp /etc/sysctl.conf /etc/sysctl.conf.backup
        print_success "Backed up to /etc/sysctl.conf.backup"
    fi
}

#######################################
# Set sysctl parameter
#######################################
set_sysctl() {
    local param="$1"
    local value="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY-RUN] Would set: $param = $value"
        return
    fi

    # Set immediately
    sysctl -w "$param=$value" > /dev/null

    # Add to config if not already there
    if grep -q "^$param" /etc/sysctl.conf; then
        sed -i "s|^$param.*|$param = $value|" /etc/sysctl.conf
    else
        echo "$param = $value" >> /etc/sysctl.conf
    fi

    print_success "Set: $param = $value"
}

#######################################
# Analyze performance
#######################################
cmd_analyze() {
    print_info "System Performance Analysis"
    echo ""

    # Memory
    echo "=== Memory ==="
    free -h
    echo ""
    echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
    echo "Dirty ratio: $(cat /proc/sys/vm/dirty_ratio)"
    echo ""

    # Disk I/O
    echo "=== Disk I/O ==="
    if command -v iostat &> /dev/null; then
        iostat -x 1 2 | tail -n +4
    else
        print_warning "iostat not installed (apt install sysstat)"
    fi
    echo ""

    # Network
    echo "=== Network ==="
    echo "TCP connections: $(ss -tan | wc -l)"
    echo "File descriptors: $(sysctl fs.file-max | awk '{print $3}')"
    echo ""

    # Load
    echo "=== System Load ==="
    uptime
    echo ""

    # Top processes by CPU
    echo "=== Top CPU Processes ==="
    ps aux --sort=-%cpu | head -6
    echo ""

    # Top processes by memory
    echo "=== Top Memory Processes ==="
    ps aux --sort=-%mem | head -6
}

#######################################
# Tune network
#######################################
cmd_tune_network() {
    check_root
    backup_sysctl

    print_info "Optimizing network settings..."

    # Increase network buffer sizes
    set_sysctl "net.core.rmem_max" "134217728"
    set_sysctl "net.core.wmem_max" "134217728"
    set_sysctl "net.core.rmem_default" "1048576"
    set_sysctl "net.core.wmem_default" "1048576"

    # TCP optimization
    set_sysctl "net.ipv4.tcp_rmem" "4096 87380 67108864"
    set_sysctl "net.ipv4.tcp_wmem" "4096 65536 67108864"
    set_sysctl "net.ipv4.tcp_congestion_control" "bbr"
    set_sysctl "net.core.default_qdisc" "fq"

    # Connection optimization
    set_sysctl "net.core.somaxconn" "4096"
    set_sysctl "net.ipv4.tcp_max_syn_backlog" "8192"
    set_sysctl "net.ipv4.tcp_slow_start_after_idle" "0"
    set_sysctl "net.ipv4.tcp_tw_reuse" "1"

    # File descriptors
    set_sysctl "fs.file-max" "2097152"

    print_success "Network tuning complete"
}

#######################################
# Tune disk I/O
#######################################
cmd_tune_disk() {
    check_root
    backup_sysctl

    print_info "Optimizing disk I/O..."

    # Dirty pages (less aggressive flushing)
    set_sysctl "vm.dirty_ratio" "15"
    set_sysctl "vm.dirty_background_ratio" "5"
    set_sysctl "vm.dirty_expire_centisecs" "1500"
    set_sysctl "vm.dirty_writeback_centisecs" "500"

    # Inode and dentry cache
    set_sysctl "vm.vfs_cache_pressure" "50"

    print_success "Disk I/O tuning complete"
}

#######################################
# Tune memory
#######################################
cmd_tune_memory() {
    check_root
    backup_sysctl

    print_info "Optimizing memory settings..."

    # Swappiness (prefer RAM over swap)
    set_sysctl "vm.swappiness" "10"

    # OOM killer (less aggressive)
    set_sysctl "vm.overcommit_memory" "1"
    set_sysctl "vm.panic_on_oom" "0"

    # Huge pages for databases
    set_sysctl "vm.nr_hugepages" "128"

    print_success "Memory tuning complete"
}

#######################################
# Tune all
#######################################
cmd_tune_all() {
    check_root
    backup_sysctl

    print_info "Applying all performance optimizations..."
    echo ""

    cmd_tune_network
    echo ""
    cmd_tune_disk
    echo ""
    cmd_tune_memory
    echo ""

    print_success "All optimizations applied"
    print_info "Reboot to ensure all changes take effect"
}

#######################################
# Create swap file
#######################################
cmd_create_swap() {
    check_root

    local size="$1"

    if [[ -z "$size" ]]; then
        print_error "Size required (e.g., 2G, 4G)"
        exit 1
    fi

    local swap_file="/swapfile"

    if [[ -f "$swap_file" ]]; then
        print_error "Swap file already exists: $swap_file"
        exit 1
    fi

    print_info "Creating ${size} swap file..."

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY-RUN] Would create swap file"
        return
    fi

    # Create swap file
    fallocate -l "$size" "$swap_file"
    chmod 600 "$swap_file"
    mkswap "$swap_file"
    swapon "$swap_file"

    # Add to fstab
    if ! grep -q "$swap_file" /etc/fstab; then
        echo "$swap_file none swap sw 0 0" >> /etc/fstab
    fi

    print_success "Swap file created and enabled"
    free -h
}

#######################################
# Adjust swappiness
#######################################
cmd_adjust_swappiness() {
    check_root

    local value="$1"

    if [[ -z "$value" ]]; then
        print_error "Swappiness value required (0-100)"
        exit 1
    fi

    if [[ $value -lt 0 ]] || [[ $value -gt 100 ]]; then
        print_error "Swappiness must be between 0 and 100"
        exit 1
    fi

    set_sysctl "vm.swappiness" "$value"

    print_info "Current swappiness: $value"
    print_info "0 = avoid swap, 100 = aggressive swap"
}

#######################################
# Restore settings
#######################################
cmd_restore() {
    check_root

    if [[ ! -f /etc/sysctl.conf.backup ]]; then
        print_error "No backup found"
        exit 1
    fi

    print_warning "Restoring original settings"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    cp /etc/sysctl.conf.backup /etc/sysctl.conf
    sysctl -p

    print_success "Settings restored"
}

#######################################
# Main function
#######################################
main() {
    local command="${1:-}"

    if [[ -z "$command" ]]; then
        show_help
        exit 1
    fi

    shift

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-backup)
                BACKUP=false
                shift
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

    # Execute command
    case "$command" in
        analyze)
            cmd_analyze
            ;;
        tune-network)
            cmd_tune_network
            ;;
        tune-disk)
            cmd_tune_disk
            ;;
        tune-memory)
            cmd_tune_memory
            ;;
        tune-all)
            cmd_tune_all
            ;;
        create-swap)
            cmd_create_swap "$@"
            ;;
        adjust-swappiness)
            cmd_adjust_swappiness "$@"
            ;;
        restore)
            cmd_restore
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

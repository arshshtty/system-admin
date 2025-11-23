#!/usr/bin/env bash
#
# Quick Troubleshoot Script
# Single command to gather comprehensive diagnostic information
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FILE=""
INCLUDE_LOGS=false
VERBOSE=false
SAVE_REPORT=false

# Function to print colored output
print_header() {
    echo -e "\n${BOLD}${CYAN}========================================${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${BOLD}${CYAN}========================================${NC}\n"
}

print_section() {
    echo -e "\n${BOLD}${BLUE}>>> $1${NC}\n"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show help
show_help() {
    cat << EOF
Quick Troubleshoot Script

Gather comprehensive diagnostic information for troubleshooting.

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --output FILE       Save report to file
    --include-logs      Include recent system logs (can be large)
    --verbose           Show detailed command output
    --help              Show this help message

EXAMPLES:
    # Run quick diagnostic
    $(basename "$0")

    # Save report to file
    $(basename "$0") --output troubleshoot-report.txt

    # Include system logs in report
    $(basename "$0") --include-logs --output full-report.txt

COLLECTED INFORMATION:
    - System information (OS, kernel, uptime)
    - Resource usage (CPU, memory, disk)
    - Network configuration and connectivity
    - Running services and processes
    - Docker containers (if Docker installed)
    - Recent system logs (if --include-logs)
    - Disk I/O and performance metrics
    - Open ports and connections
    - Failed systemd services
    - Last logins and user sessions

REQUIREMENTS:
    - Most tools are standard on Linux systems
    - Some checks require root (will skip if not available)
EOF
}

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to run command and show result
run_check() {
    local description=$1
    local command=$2
    local show_output=${3:-true}

    echo -e "${BLUE}▸ ${description}${NC}"

    if [ "$VERBOSE" = true ] || [ "$show_output" = true ]; then
        if eval "$command" 2>&1; then
            echo
        else
            print_warning "Command failed or returned no data"
            echo
        fi
    else
        eval "$command" &>/dev/null && print_success "OK" || print_warning "Failed"
    fi
}

# System Information
check_system_info() {
    print_section "System Information"

    run_check "Operating System" "cat /etc/os-release 2>/dev/null || uname -a"
    run_check "Kernel Version" "uname -r"
    run_check "System Uptime" "uptime"
    run_check "Current Time" "date"
    run_check "Timezone" "timedatectl 2>/dev/null || cat /etc/timezone 2>/dev/null || echo \$TZ"
    run_check "Hostname" "hostname -f 2>/dev/null || hostname"
}

# Resource Usage
check_resources() {
    print_section "Resource Usage"

    run_check "CPU Information" "lscpu 2>/dev/null | grep -E 'Model name|CPU\(s\)|Thread|Core' || cat /proc/cpuinfo | grep 'model name' | head -1"
    run_check "CPU Usage" "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\\([0-9.]*\\)%* id.*/\\1/' | awk '{print \"CPU Usage: \" 100 - \$1 \"%\"}'"
    run_check "Load Average" "cat /proc/loadavg"
    run_check "Memory Usage" "free -h"
    run_check "Disk Usage" "df -h | grep -v tmpfs"
    run_check "Inode Usage" "df -i | grep -v tmpfs | awk 'NR==1 || /\\/dev/'"
}

# Disk I/O
check_disk_io() {
    print_section "Disk I/O"

    if command_exists iostat; then
        run_check "Disk I/O Statistics" "iostat -x 1 2 | tail -n +4"
    else
        print_warning "iostat not available (install sysstat: sudo apt install sysstat)"
    fi

    if [ -r /proc/diskstats ]; then
        run_check "Disk Stats" "cat /proc/diskstats | awk '{print \$3, \$4, \$8}' | column -t | head -10"
    fi
}

# Network Configuration
check_network() {
    print_section "Network Configuration"

    run_check "Network Interfaces" "ip addr show || ifconfig"
    run_check "Routing Table" "ip route || route -n"
    run_check "DNS Configuration" "cat /etc/resolv.conf"
    run_check "Network Connectivity Test" "ping -c 3 8.8.8.8"
    run_check "DNS Resolution Test" "nslookup google.com 2>/dev/null || dig google.com 2>/dev/null || host google.com"
}

# Open Ports and Connections
check_ports() {
    print_section "Open Ports & Connections"

    if command_exists ss; then
        run_check "Listening Ports" "ss -tuln | grep LISTEN"
        run_check "Active Connections" "ss -tunp | grep ESTAB | head -20"
    elif command_exists netstat; then
        run_check "Listening Ports" "netstat -tuln | grep LISTEN"
        run_check "Active Connections" "netstat -tunp | grep ESTABLISHED | head -20"
    else
        print_warning "Neither ss nor netstat available"
    fi

    run_check "Connection Count by State" "ss -tan 2>/dev/null | awk 'NR>1 {print \$1}' | sort | uniq -c | sort -rn || netstat -tan 2>/dev/null | awk 'NR>2 {print \$6}' | sort | uniq -c | sort -rn"
}

# Process Information
check_processes() {
    print_section "Top Processes"

    run_check "Top CPU Consumers" "ps aux --sort=-%cpu | head -11"
    run_check "Top Memory Consumers" "ps aux --sort=-%mem | head -11"
    run_check "Process Count" "ps aux | wc -l"
    run_check "Zombie Processes" "ps aux | awk '\$8 ~ /Z/ {print}' | head -10"
}

# Systemd Services
check_services() {
    print_section "Systemd Services"

    if command_exists systemctl; then
        run_check "Failed Services" "systemctl --failed --no-pager"
        run_check "Recently Active Services" "systemctl list-units --type=service --state=running --no-pager | head -20"
    else
        print_warning "systemctl not available"
    fi
}

# Docker Containers
check_docker() {
    print_section "Docker Containers"

    if command_exists docker; then
        run_check "Docker Version" "docker --version"
        run_check "Running Containers" "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'"
        run_check "Docker Disk Usage" "docker system df"

        # Check for unhealthy containers
        local unhealthy
        unhealthy=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null || true)
        if [ -n "$unhealthy" ]; then
            print_error "Unhealthy containers detected: $unhealthy"
        fi

        # Check for exited containers
        local exited_count
        exited_count=$(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null | wc -l || echo "0")
        if [ "$exited_count" -gt 0 ]; then
            print_warning "$exited_count exited containers found"
            run_check "Exited Containers" "docker ps -a --filter 'status=exited' --format 'table {{.Names}}\t{{.Status}}' | head -10"
        fi
    else
        print_info "Docker not installed"
    fi
}

# Security Checks
check_security() {
    print_section "Security Status"

    run_check "Last Login Attempts" "last -n 10 2>/dev/null || echo 'last command not available'"
    run_check "Failed Login Attempts" "grep 'Failed password' /var/log/auth.log 2>/dev/null | tail -10 || echo 'auth.log not accessible (requires sudo)'"

    if command_exists ufw; then
        run_check "Firewall Status (UFW)" "sudo ufw status 2>/dev/null || echo 'Requires sudo access'"
    fi

    if command_exists fail2ban-client; then
        run_check "Fail2ban Status" "sudo fail2ban-client status 2>/dev/null || echo 'Requires sudo access'"
    fi
}

# System Logs
check_logs() {
    if [ "$INCLUDE_LOGS" = false ]; then
        print_section "System Logs (skipped, use --include-logs to show)"
        return
    fi

    print_section "Recent System Logs"

    if command_exists journalctl; then
        run_check "Recent Errors (last hour)" "sudo journalctl -p err -S '1 hour ago' --no-pager 2>/dev/null || echo 'Requires sudo access'"
        run_check "Recent System Messages" "sudo journalctl -n 50 --no-pager 2>/dev/null || echo 'Requires sudo access'"
    else
        run_check "System Log" "tail -50 /var/log/syslog 2>/dev/null || tail -50 /var/log/messages 2>/dev/null || echo 'Log files not accessible'"
    fi
}

# Storage Details
check_storage() {
    print_section "Storage Details"

    run_check "Mounted Filesystems" "mount | column -t"
    run_check "Block Devices" "lsblk 2>/dev/null || echo 'lsblk not available'"

    # Check for large directories
    if [ "$VERBOSE" = true ]; then
        run_check "Largest Directories in /var" "du -sh /var/* 2>/dev/null | sort -rh | head -10 || echo 'Requires appropriate permissions'"
        run_check "Largest Directories in /home" "du -sh /home/* 2>/dev/null | sort -rh | head -10 || echo 'Requires appropriate permissions'"
    fi
}

# Quick Health Assessment
health_assessment() {
    print_header "Quick Health Assessment"

    local issues=0

    # Check CPU
    local cpu_idle
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print int($1)}')
    if [ "$cpu_idle" -lt 20 ]; then
        print_error "High CPU usage detected (${cpu_idle}% idle)"
        ((issues++))
    else
        print_success "CPU usage normal (${cpu_idle}% idle)"
    fi

    # Check memory
    local mem_used_percent
    mem_used_percent=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    if [ "$mem_used_percent" -gt 90 ]; then
        print_error "High memory usage: ${mem_used_percent}%"
        ((issues++))
    else
        print_success "Memory usage acceptable: ${mem_used_percent}%"
    fi

    # Check disk
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        print_error "High disk usage on /: ${disk_usage}%"
        ((issues++))
    else
        print_success "Disk usage acceptable: ${disk_usage}%"
    fi

    # Check load average
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
    local cpu_cores
    cpu_cores=$(nproc)
    local load_threshold=$((cpu_cores * 2))

    if (( $(echo "$load_avg > $load_threshold" | bc -l 2>/dev/null || echo 0) )); then
        print_error "High load average: $load_avg (cores: $cpu_cores)"
        ((issues++))
    else
        print_success "Load average normal: $load_avg (cores: $cpu_cores)"
    fi

    # Check failed services
    if command_exists systemctl; then
        local failed_services
        failed_services=$(systemctl --failed --no-legend | wc -l)
        if [ "$failed_services" -gt 0 ]; then
            print_error "Failed systemd services: $failed_services"
            ((issues++))
        else
            print_success "No failed systemd services"
        fi
    fi

    echo
    if [ $issues -eq 0 ]; then
        print_success "Overall: System appears healthy"
    else
        print_warning "Overall: $issues potential issues detected"
    fi
}

# Main execution
main() {
    print_header "Quick Troubleshoot Diagnostic"

    echo "Collecting system diagnostic information..."
    echo "Started at: $(date)"
    echo

    # Run all checks
    health_assessment
    check_system_info
    check_resources
    check_disk_io
    check_storage
    check_network
    check_ports
    check_processes
    check_services
    check_docker
    check_security
    check_logs

    print_header "Diagnostic Complete"
    echo "Finished at: $(date)"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_FILE="$2"
            SAVE_REPORT=true
            shift 2
            ;;
        --include-logs)
            INCLUDE_LOGS=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo
            show_help
            exit 1
            ;;
    esac
done

# Execute main function
if [ "$SAVE_REPORT" = true ]; then
    main 2>&1 | tee "$OUTPUT_FILE"
    print_success "Report saved to: $OUTPUT_FILE"
else
    main
fi

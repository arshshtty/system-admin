#!/usr/bin/env bash

set -euo pipefail

# Security Baseline Audit Script
# Performs comprehensive security checks on Linux servers
# Supports Ubuntu and Debian systems

VERSION="1.0.0"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Tracking variables
ISSUES_CRITICAL=0
ISSUES_WARNING=0
ISSUES_INFO=0

# Output settings
OUTPUT_FILE=""
VERBOSE=false
JSON_OUTPUT=false

# Show help
show_help() {
    cat << EOF
Security Baseline Audit Script v${VERSION}

Usage: $(basename "$0") [options]

Performs comprehensive security audit on Linux systems including:
  - SSH configuration hardening
  - Firewall status and rules
  - User accounts and permissions
  - Open ports and listening services
  - Failed login attempts
  - Security updates status
  - File permissions on sensitive files
  - Password policies
  - Kernel security parameters

Options:
  --output FILE       Save report to file (default: stdout)
  --json              Output in JSON format
  --verbose           Show detailed information
  --help              Show this help message

Examples:
  $(basename "$0")                           # Run audit and display results
  $(basename "$0") --output audit-report.txt # Save to file
  $(basename "$0") --json --output report.json # JSON output

Exit codes:
  0 - No critical issues found
  1 - Critical security issues detected
  2 - Script error

EOF
}

# Logging functions
log_header() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "\n${BLUE}===================================================${NC}"
        echo -e "${BLUE}$1${NC}"
        echo -e "${BLUE}===================================================${NC}"
    fi
}

log_critical() {
    ((ISSUES_CRITICAL++))
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${RED}[CRITICAL]${NC} $1"
    fi
}

log_warning() {
    ((ISSUES_WARNING++))
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${YELLOW}[WARNING]${NC} $1"
    fi
}

log_info() {
    ((ISSUES_INFO++))
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_pass() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${GREEN}[PASS]${NC} $1"
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Warning: Not running as root. Some checks may be limited.${NC}"
        return 1
    fi
    return 0
}

# SSH Configuration Audit
audit_ssh() {
    log_header "SSH Configuration Audit"

    local ssh_config="/etc/ssh/sshd_config"

    if [ ! -f "$ssh_config" ]; then
        log_warning "SSH config file not found"
        return
    fi

    # Check PermitRootLogin
    if grep -qE "^PermitRootLogin\s+(no|prohibit-password)" "$ssh_config"; then
        log_pass "Root login disabled or restricted"
    else
        log_critical "Root login via SSH is enabled"
    fi

    # Check PasswordAuthentication
    if grep -qE "^PasswordAuthentication\s+no" "$ssh_config"; then
        log_pass "Password authentication disabled"
    else
        log_warning "Password authentication is enabled (consider key-based auth only)"
    fi

    # Check Protocol (should not be explicitly set to 1)
    if grep -qE "^Protocol\s+1" "$ssh_config"; then
        log_critical "SSH Protocol 1 is enabled (insecure)"
    else
        log_pass "SSH Protocol 1 not explicitly enabled"
    fi

    # Check PermitEmptyPasswords
    if grep -qE "^PermitEmptyPasswords\s+yes" "$ssh_config"; then
        log_critical "Empty passwords are permitted"
    else
        log_pass "Empty passwords not permitted"
    fi

    # Check X11Forwarding
    if grep -qE "^X11Forwarding\s+yes" "$ssh_config"; then
        log_info "X11 forwarding is enabled"
    fi

    # Check MaxAuthTries
    local max_auth_tries=$(grep -E "^MaxAuthTries" "$ssh_config" | awk '{print $2}')
    if [ -n "$max_auth_tries" ] && [ "$max_auth_tries" -le 4 ]; then
        log_pass "MaxAuthTries is set to reasonable value: $max_auth_tries"
    else
        log_warning "MaxAuthTries not set or too high (recommended: 3-4)"
    fi
}

# Firewall Status Audit
audit_firewall() {
    log_header "Firewall Status Audit"

    # Check UFW
    if command -v ufw &> /dev/null; then
        local ufw_status=$(ufw status 2>/dev/null | grep -i "Status:" | awk '{print $2}')
        if [ "$ufw_status" = "active" ]; then
            log_pass "UFW firewall is active"
            if [ "$VERBOSE" = true ]; then
                ufw status numbered
            fi
        else
            log_critical "UFW firewall is not active"
        fi
    fi

    # Check iptables
    if command -v iptables &> /dev/null && check_root; then
        local iptables_rules=$(iptables -L -n 2>/dev/null | grep -c "^Chain")
        if [ "$iptables_rules" -gt 3 ]; then
            log_pass "iptables rules are configured"
        else
            log_warning "iptables has minimal/no rules configured"
        fi
    fi
}

# User Accounts Audit
audit_users() {
    log_header "User Accounts Audit"

    # Check for users with UID 0 (root privileges)
    local root_users=$(awk -F: '$3 == 0 {print $1}' /etc/passwd)
    local root_count=$(echo "$root_users" | wc -l)
    if [ "$root_count" -eq 1 ] && [ "$root_users" = "root" ]; then
        log_pass "Only root account has UID 0"
    else
        log_critical "Multiple accounts with UID 0 detected: $root_users"
    fi

    # Check for users with empty passwords
    if check_root; then
        local empty_pass=$(awk -F: '$2 == "" {print $1}' /etc/shadow 2>/dev/null)
        if [ -z "$empty_pass" ]; then
            log_pass "No users with empty passwords"
        else
            log_critical "Users with empty passwords: $empty_pass"
        fi
    fi

    # Check for users with no password expiry
    if check_root; then
        local no_expiry=$(awk -F: '$5 == "" || $5 == 99999 {print $1}' /etc/shadow 2>/dev/null | grep -v "^#")
        if [ -z "$no_expiry" ]; then
            log_pass "All users have password expiry set"
        else
            log_warning "Users without password expiry: $(echo $no_expiry | tr '\n' ' ')"
        fi
    fi

    # Check for users with valid shells
    local user_shells=$(awk -F: '$7 !~ /(nologin|false)/ && $3 >= 1000 {print $1}' /etc/passwd)
    if [ "$VERBOSE" = true ]; then
        echo "Regular users with shell access:"
        echo "$user_shells"
    fi
}

# Open Ports Audit
audit_ports() {
    log_header "Open Ports and Services Audit"

    if command -v ss &> /dev/null; then
        local listening_tcp=$(ss -tulpn 2>/dev/null | grep LISTEN | wc -l)
        log_info "Found $listening_tcp listening TCP services"

        if [ "$VERBOSE" = true ]; then
            echo ""
            ss -tulpn 2>/dev/null | grep LISTEN
        fi

        # Check for common risky ports
        if ss -tulpn 2>/dev/null | grep -q ":23 "; then
            log_critical "Telnet (port 23) is listening - INSECURE!"
        fi

        if ss -tulpn 2>/dev/null | grep -q ":21 "; then
            log_warning "FTP (port 21) is listening - consider SFTP instead"
        fi
    elif command -v netstat &> /dev/null; then
        local listening_tcp=$(netstat -tulpn 2>/dev/null | grep LISTEN | wc -l)
        log_info "Found $listening_tcp listening TCP services"
    else
        log_warning "Neither ss nor netstat available - cannot check open ports"
    fi
}

# Failed Login Attempts
audit_failed_logins() {
    log_header "Failed Login Attempts Audit"

    if [ ! -f /var/log/auth.log ]; then
        log_warning "auth.log not found - cannot check failed logins"
        return
    fi

    if check_root; then
        local failed_ssh=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo "0")
        local failed_sudo=$(grep -c "authentication failure" /var/log/auth.log 2>/dev/null || echo "0")

        if [ "$failed_ssh" -gt 100 ]; then
            log_critical "High number of failed SSH attempts: $failed_ssh"
        elif [ "$failed_ssh" -gt 10 ]; then
            log_warning "Moderate failed SSH attempts: $failed_ssh"
        else
            log_pass "Low failed SSH attempts: $failed_ssh"
        fi

        if [ "$failed_sudo" -gt 50 ]; then
            log_warning "High number of failed sudo attempts: $failed_sudo"
        fi
    fi
}

# Security Updates Audit
audit_updates() {
    log_header "Security Updates Audit"

    if command -v apt-get &> /dev/null; then
        # Update package cache
        apt-get update &> /dev/null || true

        local security_updates=$(apt-get upgrade -s 2>/dev/null | grep -i "security" | wc -l)
        local total_updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")

        if [ "$security_updates" -gt 0 ]; then
            log_warning "$security_updates security updates available"
        else
            log_pass "No security updates pending"
        fi

        if [ "$total_updates" -gt 50 ]; then
            log_warning "$total_updates total package updates available"
        fi

        # Check if unattended-upgrades is installed
        if dpkg -l | grep -q unattended-upgrades; then
            log_pass "unattended-upgrades package is installed"
        else
            log_warning "unattended-upgrades not installed - consider enabling automatic security updates"
        fi
    fi
}

# File Permissions Audit
audit_file_permissions() {
    log_header "File Permissions Audit"

    # Check /etc/passwd
    local passwd_perms=$(stat -c "%a" /etc/passwd)
    if [ "$passwd_perms" = "644" ]; then
        log_pass "/etc/passwd has correct permissions (644)"
    else
        log_warning "/etc/passwd permissions: $passwd_perms (should be 644)"
    fi

    # Check /etc/shadow
    if [ -f /etc/shadow ]; then
        local shadow_perms=$(stat -c "%a" /etc/shadow)
        if [ "$shadow_perms" = "640" ] || [ "$shadow_perms" = "600" ]; then
            log_pass "/etc/shadow has correct permissions ($shadow_perms)"
        else
            log_critical "/etc/shadow permissions: $shadow_perms (should be 640 or 600)"
        fi
    fi

    # Check for world-writable files in /etc
    if check_root; then
        local writable_etc=$(find /etc -type f -perm -002 2>/dev/null | wc -l)
        if [ "$writable_etc" -gt 0 ]; then
            log_critical "Found $writable_etc world-writable files in /etc"
            if [ "$VERBOSE" = true ]; then
                find /etc -type f -perm -002 2>/dev/null
            fi
        else
            log_pass "No world-writable files in /etc"
        fi
    fi
}

# Kernel Security Parameters
audit_kernel_params() {
    log_header "Kernel Security Parameters Audit"

    # Check if IP forwarding is disabled (unless this is a router)
    local ip_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "unknown")
    if [ "$ip_forward" = "0" ]; then
        log_pass "IP forwarding is disabled"
    elif [ "$ip_forward" = "1" ]; then
        log_info "IP forwarding is enabled (expected for routers/VPN servers)"
    fi

    # Check if SYN cookies are enabled
    local syn_cookies=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo "unknown")
    if [ "$syn_cookies" = "1" ]; then
        log_pass "SYN cookies enabled (DDoS protection)"
    else
        log_warning "SYN cookies not enabled"
    fi

    # Check if ICMP redirects are disabled
    local icmp_redirects=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null || echo "unknown")
    if [ "$icmp_redirects" = "0" ]; then
        log_pass "ICMP redirects disabled"
    else
        log_warning "ICMP redirects enabled (security risk)"
    fi
}

# Security Tools Check
audit_security_tools() {
    log_header "Security Tools Audit"

    local tools=("fail2ban" "aide" "rkhunter" "chkrootkit" "clamav")
    local installed_count=0

    for tool in "${tools[@]}"; do
        if command -v "$tool" &> /dev/null || dpkg -l | grep -q "^ii.*$tool"; then
            log_pass "$tool is installed"
            ((installed_count++))
        else
            log_info "$tool is not installed"
        fi
    done

    if [ "$installed_count" -eq 0 ]; then
        log_warning "No security scanning tools installed (consider fail2ban, aide, rkhunter)"
    fi
}

# Generate Summary
generate_summary() {
    if [ "$JSON_OUTPUT" = false ]; then
        log_header "Audit Summary"
        echo -e "${RED}Critical Issues: $ISSUES_CRITICAL${NC}"
        echo -e "${YELLOW}Warnings: $ISSUES_WARNING${NC}"
        echo -e "${BLUE}Informational: $ISSUES_INFO${NC}"

        if [ "$ISSUES_CRITICAL" -gt 0 ]; then
            echo -e "\n${RED}ATTENTION: Critical security issues detected!${NC}"
            echo "Please address these issues immediately."
            return 1
        elif [ "$ISSUES_WARNING" -gt 10 ]; then
            echo -e "\n${YELLOW}Multiple warnings detected. Review recommended.${NC}"
            return 0
        else
            echo -e "\n${GREEN}Overall security posture looks reasonable.${NC}"
            return 0
        fi
    else
        # JSON output
        cat << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hostname": "$(hostname)",
  "summary": {
    "critical": $ISSUES_CRITICAL,
    "warnings": $ISSUES_WARNING,
    "info": $ISSUES_INFO
  }
}
EOF
    fi
}

# Main execution
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --json)
                JSON_OUTPUT=true
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
                echo "Unknown option: $1"
                show_help
                exit 2
                ;;
        esac
    done

    # Redirect output if file specified
    if [ -n "$OUTPUT_FILE" ]; then
        exec > >(tee "$OUTPUT_FILE")
    fi

    # Display header
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║    Security Baseline Audit Script v${VERSION}        ║${NC}"
        echo -e "${BLUE}║    $(date)                      ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi

    # Run all audits
    audit_ssh
    audit_firewall
    audit_users
    audit_ports
    audit_failed_logins
    audit_updates
    audit_file_permissions
    audit_kernel_params
    audit_security_tools

    # Generate summary and exit with appropriate code
    if generate_summary; then
        exit 0
    else
        exit 1
    fi
}

main "$@"

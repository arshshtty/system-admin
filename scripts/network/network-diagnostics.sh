#!/usr/bin/env bash

set -euo pipefail

# Network Diagnostics and Testing Tool
# Comprehensive network troubleshooting and analysis

VERSION="1.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default settings
VERBOSE=false
OUTPUT_FILE=""

# Show help
show_help() {
    cat << EOF
Network Diagnostics and Testing Tool v${VERSION}

Usage: $(basename "$0") COMMAND [options]

Commands:
  check           Quick network health check
  traceroute      Trace route to destination
  bandwidth       Test bandwidth/throughput
  latency         Test latency and packet loss
  dns             DNS diagnostics
  ports           Check open ports and services
  connectivity    Test internet connectivity
  interfaces      Show network interfaces
  speed           Run comprehensive speed test
  report          Generate full diagnostic report

Options:
  --host HOST         Target host/IP for tests
  --port PORT         Target port number
  --count N           Number of test iterations (default: 10)
  --timeout N         Timeout in seconds (default: 5)
  --output FILE       Save report to file
  --verbose           Show detailed output
  --help              Show this help message

Examples:
  # Quick health check
  $(basename "$0") check

  # Test connectivity to specific host
  $(basename "$0") connectivity --host google.com

  # DNS diagnostics
  $(basename "$0") dns --host example.com

  # Check if port is open
  $(basename "$0") ports --host example.com --port 443

  # Full diagnostic report
  $(basename "$0") report --output network-report.txt

  # Trace route with verbose output
  $(basename "$0") traceroute --host 8.8.8.8 --verbose

EOF
}

# Logging functions
log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

log_section() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}\n"
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Quick network health check
quick_check() {
    log_section "Quick Network Health Check"

    # Check network interfaces
    log_info "Checking network interfaces..."
    if ip link show | grep -q "state UP"; then
        log_success "Network interface is UP"
    else
        log_error "No active network interface found"
    fi

    # Check default gateway
    log_info "Checking default gateway..."
    local gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [ -n "$gateway" ]; then
        log_success "Default gateway: $gateway"
        if ping -c 1 -W 2 "$gateway" &> /dev/null; then
            log_success "Gateway is reachable"
        else
            log_error "Gateway is not reachable"
        fi
    else
        log_error "No default gateway configured"
    fi

    # Check DNS resolution
    log_info "Checking DNS resolution..."
    if host google.com &> /dev/null; then
        log_success "DNS resolution working"
    else
        log_error "DNS resolution failed"
    fi

    # Check internet connectivity
    log_info "Checking internet connectivity..."
    if ping -c 1 -W 3 8.8.8.8 &> /dev/null; then
        log_success "Internet connectivity: OK"
    else
        log_error "No internet connectivity"
    fi

    # Check public IP
    log_info "Checking public IP..."
    local public_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "Unable to determine")
    log_info "Public IP: $public_ip"
}

# Traceroute to destination
run_traceroute() {
    local host=$1

    log_section "Traceroute to $host"

    if ! command_exists traceroute; then
        log_warning "traceroute not installed. Trying with mtr..."
        if command_exists mtr; then
            mtr -r -c 1 "$host"
        else
            log_error "Neither traceroute nor mtr is installed"
            log_info "Install with: sudo apt install traceroute mtr"
            return 1
        fi
    else
        traceroute -m 20 "$host"
    fi
}

# Test latency and packet loss
test_latency() {
    local host=$1
    local count=${2:-10}

    log_section "Latency Test to $host"

    if ! ping -c "$count" -W 2 "$host" > /tmp/ping-test.txt 2>&1; then
        log_error "Host $host is unreachable"
        return 1
    fi

    # Parse ping results
    local packet_loss=$(grep -oP '\d+(?=% packet loss)' /tmp/ping-test.txt)
    local avg_latency=$(grep -oP 'rtt min/avg/max/mdev = [\d.]+/\K[\d.]+' /tmp/ping-test.txt)

    echo "Packets sent: $count"
    echo "Packet loss: ${packet_loss}%"
    echo "Average latency: ${avg_latency} ms"

    if [ "$packet_loss" -eq 0 ]; then
        log_success "No packet loss"
    elif [ "$packet_loss" -lt 5 ]; then
        log_warning "Minor packet loss: ${packet_loss}%"
    else
        log_error "High packet loss: ${packet_loss}%"
    fi

    if (( $(echo "$avg_latency < 50" | bc -l) )); then
        log_success "Excellent latency: ${avg_latency}ms"
    elif (( $(echo "$avg_latency < 100" | bc -l) )); then
        log_info "Good latency: ${avg_latency}ms"
    else
        log_warning "High latency: ${avg_latency}ms"
    fi

    rm -f /tmp/ping-test.txt
}

# DNS diagnostics
test_dns() {
    local host=$1

    log_section "DNS Diagnostics for $host"

    # Check with system resolver
    log_info "System DNS resolution:"
    if host "$host" &> /dev/null; then
        host "$host" | head -5
    else
        log_error "Failed to resolve $host"
    fi

    # Check with different DNS servers
    local dns_servers=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    local dns_names=("Google" "Cloudflare" "OpenDNS")

    echo ""
    log_info "Testing with public DNS servers:"

    for i in "${!dns_servers[@]}"; do
        local server="${dns_servers[$i]}"
        local name="${dns_names[$i]}"

        if dig @"$server" "$host" +short +timeout=2 &> /dev/null; then
            local result=$(dig @"$server" "$host" +short +timeout=2 | head -1)
            log_success "$name ($server): $result"
        else
            log_error "$name ($server): Failed"
        fi
    done

    # Show DNS servers configured
    echo ""
    log_info "Configured DNS servers:"
    if [ -f /etc/resolv.conf ]; then
        grep "^nameserver" /etc/resolv.conf | awk '{print "  " $2}'
    fi
}

# Check port connectivity
check_port() {
    local host=$1
    local port=$2
    local timeout=${3:-5}

    log_section "Port Check: $host:$port"

    # Try with nc (netcat)
    if command_exists nc; then
        if timeout "$timeout" nc -zv "$host" "$port" 2>&1 | grep -q "succeeded"; then
            log_success "Port $port is OPEN on $host"
            return 0
        else
            log_error "Port $port is CLOSED on $host"
            return 1
        fi
    # Try with telnet
    elif command_exists telnet; then
        if timeout "$timeout" telnet "$host" "$port" 2>&1 | grep -q "Connected"; then
            log_success "Port $port is OPEN on $host"
            return 0
        else
            log_error "Port $port is CLOSED on $host"
            return 1
        fi
    # Try with bash built-in
    else
        if timeout "$timeout" bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
            log_success "Port $port is OPEN on $host"
            return 0
        else
            log_error "Port $port is CLOSED on $host"
            return 1
        fi
    fi
}

# Scan common ports
scan_common_ports() {
    local host=$1

    log_section "Common Port Scan: $host"

    local common_ports=(
        "22:SSH"
        "80:HTTP"
        "443:HTTPS"
        "25:SMTP"
        "587:SMTP-Submission"
        "3306:MySQL"
        "5432:PostgreSQL"
        "6379:Redis"
        "27017:MongoDB"
        "3000:Dev-Server"
        "8080:HTTP-Alt"
        "9090:Prometheus"
    )

    log_info "Scanning common ports on $host..."
    echo ""

    for port_info in "${common_ports[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info##*:}"

        if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Port $port ($service) - OPEN"
        else
            if [ "$VERBOSE" = true ]; then
                echo -e "${RED}✗${NC} Port $port ($service) - CLOSED"
            fi
        fi
    done
}

# Test internet connectivity
test_connectivity() {
    local host=${1:-""}

    log_section "Internet Connectivity Test"

    local test_hosts=("8.8.8.8" "1.1.1.1" "google.com" "cloudflare.com")

    if [ -n "$host" ]; then
        test_hosts=("$host")
    fi

    for test_host in "${test_hosts[@]}"; do
        if ping -c 3 -W 2 "$test_host" &> /dev/null; then
            log_success "Connected to $test_host"
        else
            log_error "Cannot reach $test_host"
        fi
    done

    # Test HTTP/HTTPS connectivity
    log_info "Testing HTTP/HTTPS connectivity..."
    if curl -s --max-time 5 http://example.com &> /dev/null; then
        log_success "HTTP connectivity: OK"
    else
        log_error "HTTP connectivity: FAILED"
    fi

    if curl -s --max-time 5 https://example.com &> /dev/null; then
        log_success "HTTPS connectivity: OK"
    else
        log_error "HTTPS connectivity: FAILED"
    fi
}

# Show network interfaces
show_interfaces() {
    log_section "Network Interfaces"

    if command_exists ip; then
        ip -brief addr show
        echo ""
        log_info "Detailed interface information:"
        ip addr show
    else
        ifconfig
    fi

    echo ""
    log_info "Routing table:"
    if command_exists ip; then
        ip route show
    else
        route -n
    fi
}

# Speed test
run_speed_test() {
    log_section "Network Speed Test"

    # Check if speedtest-cli is available
    if ! command_exists speedtest-cli && ! command_exists speedtest; then
        log_warning "speedtest-cli not installed"
        log_info "Install with: pip install speedtest-cli"
        log_info "Or: sudo apt install speedtest-cli"
        return 1
    fi

    log_info "Running speed test (this may take a minute)..."

    if command_exists speedtest-cli; then
        speedtest-cli --simple
    else
        speedtest
    fi
}

# Generate comprehensive report
generate_report() {
    log_section "Comprehensive Network Diagnostic Report"
    echo "Generated: $(date)"
    echo "Hostname: $(hostname)"
    echo ""

    quick_check
    echo ""
    show_interfaces
    echo ""
    test_dns "google.com"
    echo ""
    test_latency "8.8.8.8" 10
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command=""
    local host=""
    local port=""
    local count=10
    local timeout=5

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --host)
                host="$2"
                shift 2
                ;;
            --port)
                port="$2"
                shift 2
                ;;
            --count)
                count="$2"
                shift 2
                ;;
            --timeout)
                timeout="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            check|traceroute|bandwidth|latency|dns|ports|connectivity|interfaces|speed|report)
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

    # Redirect output if file specified
    if [ -n "$OUTPUT_FILE" ]; then
        exec > >(tee "$OUTPUT_FILE")
    fi

    # Execute command
    case $command in
        check)
            quick_check
            ;;
        traceroute)
            if [ -z "$host" ]; then
                log_error "--host is required"
                exit 1
            fi
            run_traceroute "$host"
            ;;
        latency)
            if [ -z "$host" ]; then
                log_error "--host is required"
                exit 1
            fi
            test_latency "$host" "$count"
            ;;
        dns)
            if [ -z "$host" ]; then
                log_error "--host is required"
                exit 1
            fi
            test_dns "$host"
            ;;
        ports)
            if [ -z "$host" ]; then
                log_error "--host is required"
                exit 1
            fi
            if [ -n "$port" ]; then
                check_port "$host" "$port" "$timeout"
            else
                scan_common_ports "$host"
            fi
            ;;
        connectivity)
            test_connectivity "$host"
            ;;
        interfaces)
            show_interfaces
            ;;
        speed)
            run_speed_test
            ;;
        report)
            generate_report
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

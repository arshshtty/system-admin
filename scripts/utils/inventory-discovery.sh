#!/usr/bin/env bash
#
# Server Inventory Auto-Discovery Script
# Scans network and builds YAML inventory automatically
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SUBNET=""
OUTPUT_FILE="inventory/discovered-servers.yaml"
SSH_USER="${USER}"
SSH_PORT=22
TIMEOUT=2
SCAN_PORTS="22,80,443,3306,5432,6379,9000"
VERBOSE=false
DRY_RUN=false

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
Server Inventory Auto-Discovery Script

Scans network and automatically builds a YAML inventory of discovered servers.

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --subnet SUBNET         Network subnet to scan (e.g., 192.168.1.0/24)
                           If not specified, will scan local subnet
    --output FILE           Output file path (default: inventory/discovered-servers.yaml)
    --ssh-user USER         SSH username to test (default: current user)
    --ssh-port PORT         SSH port to test (default: 22)
    --timeout SECONDS       Connection timeout (default: 2)
    --ports PORTS           Comma-separated ports to scan (default: 22,80,443,3306,5432,6379,9000)
    --verbose               Show detailed output
    --dry-run               Show what would be discovered without writing file
    --help                  Show this help message

EXAMPLES:
    # Discover servers on local network
    $(basename "$0") --subnet 192.168.1.0/24

    # Custom output file and SSH user
    $(basename "$0") --subnet 10.0.0.0/24 --output my-servers.yaml --ssh-user admin

    # Verbose mode with custom timeout
    $(basename "$0") --subnet 192.168.1.0/24 --verbose --timeout 5

    # Dry run to see what would be discovered
    $(basename "$0") --subnet 192.168.1.0/24 --dry-run

REQUIREMENTS:
    - nmap (install with: sudo apt install nmap)
    - SSH access to target servers (for detailed discovery)

DISCOVERED INFORMATION:
    - IP addresses
    - Open ports
    - SSH accessibility
    - Hostname (if SSH accessible)
    - Operating system (basic detection)
    - Running services (based on open ports)

OUTPUT FORMAT:
    YAML file compatible with the monitoring and automation scripts
EOF
}

# Function to check if required tools are installed
check_requirements() {
    local missing_tools=()

    if ! command -v nmap &> /dev/null; then
        missing_tools+=("nmap")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Install with: sudo apt install ${missing_tools[*]}"
        exit 1
    fi
}

# Function to detect local subnet if not specified
detect_local_subnet() {
    local ip
    ip=$(ip route get 8.8.8.8 | grep -oP 'src \K\S+')

    if [ -z "$ip" ]; then
        print_error "Could not detect local IP address"
        exit 1
    fi

    # Get subnet from IP
    local subnet
    subnet=$(ip -o -f inet addr show | grep "$ip" | awk '{print $4}')

    if [ -z "$subnet" ]; then
        # Fallback: assume /24 network
        subnet="${ip%.*}.0/24"
    fi

    echo "$subnet"
}

# Function to identify service by port
identify_service() {
    local port=$1
    case $port in
        22) echo "SSH" ;;
        80) echo "HTTP" ;;
        443) echo "HTTPS" ;;
        3306) echo "MySQL" ;;
        5432) echo "PostgreSQL" ;;
        6379) echo "Redis" ;;
        27017) echo "MongoDB" ;;
        9000) echo "Portainer" ;;
        8080) echo "HTTP-Alt" ;;
        *) echo "Unknown" ;;
    esac
}

# Function to scan network and discover hosts
scan_network() {
    local subnet=$1

    print_info "Scanning network: $subnet"
    print_info "This may take a few minutes..."

    # Use nmap for host discovery and port scanning
    local nmap_output
    nmap_output=$(mktemp)

    if [ "$VERBOSE" = true ]; then
        sudo nmap -sn -T4 "$subnet" -oG - | grep "Up" | awk '{print $2}' | tee "$nmap_output"
    else
        sudo nmap -sn -T4 "$subnet" -oG - | grep "Up" | awk '{print $2}' > "$nmap_output"
    fi

    local host_count
    host_count=$(wc -l < "$nmap_output")

    print_success "Found $host_count active hosts"

    echo "$nmap_output"
}

# Function to scan ports on a host
scan_host_ports() {
    local ip=$1

    if [ "$VERBOSE" = true ]; then
        print_info "Scanning ports on $ip..."
    fi

    # Quick port scan
    local open_ports
    open_ports=$(sudo nmap -p "$SCAN_PORTS" --open -T4 "$ip" 2>/dev/null | grep "^[0-9]" | grep "open" | awk '{print $1}' | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')

    echo "$open_ports"
}

# Function to test SSH connectivity
test_ssh() {
    local ip=$1
    local user=$2
    local port=$3

    # Try to connect via SSH with key-based auth (no password prompt)
    if timeout "$TIMEOUT" ssh -o BatchMode=yes -o ConnectTimeout="$TIMEOUT" -o StrictHostKeyChecking=no -p "$port" "${user}@${ip}" "echo ok" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to get hostname via SSH
get_hostname() {
    local ip=$1
    local user=$2
    local port=$3

    timeout "$TIMEOUT" ssh -o BatchMode=yes -o ConnectTimeout="$TIMEOUT" -o StrictHostKeyChecking=no -p "$port" "${user}@${ip}" "hostname" 2>/dev/null || echo "unknown"
}

# Function to detect OS via SSH
detect_os() {
    local ip=$1
    local user=$2
    local port=$3

    local os_info
    os_info=$(timeout "$TIMEOUT" ssh -o BatchMode=yes -o ConnectTimeout="$TIMEOUT" -o StrictHostKeyChecking=no -p "$port" "${user}@${ip}" "cat /etc/os-release 2>/dev/null | grep '^ID=' | cut -d'=' -f2 | tr -d '\"'" 2>/dev/null)

    if [ -n "$os_info" ]; then
        echo "$os_info"
    else
        echo "unknown"
    fi
}

# Function to build YAML inventory
build_inventory() {
    local hosts_file=$1
    local discovered_servers=()

    # Read discovered hosts
    while IFS= read -r ip; do
        if [ "$VERBOSE" = true ]; then
            print_info "Analyzing $ip..."
        fi

        # Scan ports
        local open_ports
        open_ports=$(scan_host_ports "$ip")

        # Check if SSH is accessible
        local ssh_accessible=false
        local hostname="unknown"
        local os_type="unknown"

        if echo "$open_ports" | grep -q "22"; then
            if test_ssh "$ip" "$SSH_USER" "$SSH_PORT"; then
                ssh_accessible=true
                hostname=$(get_hostname "$ip" "$SSH_USER" "$SSH_PORT")
                os_type=$(detect_os "$ip" "$SSH_USER" "$SSH_PORT")

                if [ "$VERBOSE" = true ]; then
                    print_success "$ip is SSH accessible (hostname: $hostname)"
                fi
            fi
        fi

        # Build server entry
        discovered_servers+=("$ip|$hostname|$open_ports|$ssh_accessible|$os_type")

    done < "$hosts_file"

    # Generate YAML
    local yaml_content
    yaml_content="# Auto-discovered server inventory
# Generated on: $(date)
# Scan subnet: $SUBNET
# Total servers discovered: ${#discovered_servers[@]}

servers:
  discovered:"

    for server in "${discovered_servers[@]}"; do
        IFS='|' read -r ip hostname open_ports ssh_accessible os_type <<< "$server"

        # Determine server type
        local server_type="unknown"
        if echo "$open_ports" | grep -qE "(80|443)"; then
            server_type="web-server"
        elif echo "$open_ports" | grep -qE "(3306|5432|27017|6379)"; then
            server_type="database"
        elif [ "$ssh_accessible" = true ]; then
            server_type="server"
        fi

        # Identify services
        local services=""
        if [ -n "$open_ports" ]; then
            IFS=',' read -ra PORTS <<< "$open_ports"
            for port in "${PORTS[@]}"; do
                local service
                service=$(identify_service "$port")
                services="${services}${service}, "
            done
            services="${services%, }"  # Remove trailing comma
        fi

        yaml_content="${yaml_content}
    - name: ${hostname}
      ip: ${ip}
      ssh_user: ${SSH_USER}
      ssh_accessible: ${ssh_accessible}
      type: ${server_type}
      os: ${os_type}
      open_ports: [${open_ports}]
      services: [${services}]
      tags:
        - auto-discovered"
    done

    echo "$yaml_content"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --subnet)
            SUBNET="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --ssh-user)
            SSH_USER="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --ports)
            SCAN_PORTS="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

# Main execution
main() {
    print_info "Server Inventory Auto-Discovery"
    echo

    # Check requirements
    check_requirements

    # Detect subnet if not specified
    if [ -z "$SUBNET" ]; then
        print_info "No subnet specified, detecting local subnet..."
        SUBNET=$(detect_local_subnet)
        print_info "Detected subnet: $SUBNET"
    fi

    # Scan network
    hosts_file=$(scan_network "$SUBNET")

    # Build inventory
    print_info "Building inventory..."
    yaml_content=$(build_inventory "$hosts_file")

    # Output results
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN - Would write to: $OUTPUT_FILE"
        echo
        echo "$yaml_content"
    else
        # Create directory if it doesn't exist
        mkdir -p "$(dirname "$OUTPUT_FILE")"

        # Write YAML file
        echo "$yaml_content" > "$OUTPUT_FILE"
        print_success "Inventory saved to: $OUTPUT_FILE"
    fi

    # Cleanup
    rm -f "$hosts_file"

    echo
    print_success "Discovery complete!"
}

main

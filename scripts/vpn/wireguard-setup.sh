#!/usr/bin/env bash
#
# WireGuard VPN Setup - Easy WireGuard VPN deployment
# Create secure VPN server and generate client configurations
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
WG_INTERFACE="wg0"
WG_PORT="51820"
WG_NET="10.8.0.0/24"
SERVER_IP=""
CONFIG_DIR="/etc/wireguard"
CLIENTS_DIR="/etc/wireguard/clients"

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
WireGuard VPN Setup - Easy WireGuard deployment

USAGE:
    $(basename "$0") COMMAND [OPTIONS]

COMMANDS:
    install                 Install WireGuard
    setup-server            Setup VPN server
    add-client NAME         Add new client
    remove-client NAME      Remove client
    list-clients            List all clients
    show-qr NAME            Show QR code for client
    status                  Show server status
    uninstall               Uninstall WireGuard

SERVER OPTIONS:
    --port PORT             Listen port (default: 51820)
    --network CIDR          VPN network (default: 10.8.0.0/24)
    --interface IFACE       Interface name (default: wg0)

CLIENT OPTIONS:
    --allowed-ips CIDR      Allowed IPs (default: 0.0.0.0/0 - all traffic)
    --dns SERVER            DNS server (default: 1.1.1.1)

EXAMPLES:
    # Install WireGuard
    $(basename "$0") install

    # Setup server
    $(basename "$0") setup-server

    # Add client
    $(basename "$0") add-client laptop

    # Show client QR code (for mobile)
    $(basename "$0") show-qr laptop

    # List all clients
    $(basename "$0") list-clients

    # Check status
    $(basename "$0") status

NOTES:
    - Client configs are saved in /etc/wireguard/clients/
    - Use QR codes for easy mobile setup
    - Traffic is routed through VPN server by default
    - IPv4 forwarding is automatically enabled

EOF
}

#######################################
# Install WireGuard
#######################################
cmd_install() {
    check_root

    print_info "Installing WireGuard..."

    if command -v wg &> /dev/null; then
        print_warning "WireGuard already installed"
        wg version
        return 0
    fi

    # Install WireGuard
    apt-get update
    apt-get install -y wireguard wireguard-tools qrencode

    print_success "WireGuard installed"
    wg version
}

#######################################
# Setup server
#######################################
cmd_setup_server() {
    check_root

    if [[ ! -x "$(command -v wg)" ]]; then
        print_error "WireGuard not installed. Run: $0 install"
        exit 1
    fi

    print_info "Setting up WireGuard server..."

    # Get public IP
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || echo "")
    fi

    if [[ -z "$SERVER_IP" ]]; then
        read -p "Enter server public IP: " SERVER_IP
    fi

    print_info "Server IP: $SERVER_IP"

    # Create directories
    mkdir -p "$CONFIG_DIR" "$CLIENTS_DIR"
    chmod 700 "$CONFIG_DIR"

    # Generate server keys if they don't exist
    if [[ ! -f "$CONFIG_DIR/server_private.key" ]]; then
        wg genkey | tee "$CONFIG_DIR/server_private.key" | wg pubkey > "$CONFIG_DIR/server_public.key"
        chmod 600 "$CONFIG_DIR/server_private.key"
        print_success "Server keys generated"
    fi

    local server_private_key
    server_private_key=$(cat "$CONFIG_DIR/server_private.key")
    local server_ip_addr="${WG_NET%.*}.1"

    # Create server config
    cat > "$CONFIG_DIR/$WG_INTERFACE.conf" << EOF
[Interface]
Address = $server_ip_addr/24
ListenPort = $WG_PORT
PrivateKey = $server_private_key
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

EOF

    chmod 600 "$CONFIG_DIR/$WG_INTERFACE.conf"

    # Enable IPv4 forwarding
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    sysctl -p

    # Open firewall port
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        ufw allow "$WG_PORT/udp"
        print_success "Firewall rule added"
    fi

    # Enable and start WireGuard
    systemctl enable wg-quick@"$WG_INTERFACE"
    systemctl start wg-quick@"$WG_INTERFACE"

    print_success "WireGuard server setup complete"
    print_info "Server endpoint: $SERVER_IP:$WG_PORT"
    print_info "Server network: $WG_NET"
}

#######################################
# Add client
#######################################
cmd_add_client() {
    check_root

    local client_name="$1"
    shift

    local allowed_ips="0.0.0.0/0"
    local dns="1.1.1.1"

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --allowed-ips)
                allowed_ips="$2"
                shift 2
                ;;
            --dns)
                dns="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if [[ -z "$client_name" ]]; then
        print_error "Client name required"
        exit 1
    fi

    if [[ -f "$CLIENTS_DIR/$client_name.conf" ]]; then
        print_error "Client already exists: $client_name"
        exit 1
    fi

    print_info "Adding client: $client_name"

    # Get next available IP
    local next_ip
    next_ip=$(grep -h "AllowedIPs" "$CONFIG_DIR/$WG_INTERFACE.conf" 2>/dev/null | awk '{print $3}' | cut -d'/' -f1 | cut -d'.' -f4 | sort -n | tail -1)
    if [[ -z "$next_ip" ]]; then
        next_ip=1
    fi
    next_ip=$((next_ip + 1))

    local client_ip="${WG_NET%.*}.$next_ip"
    local server_ip="${WG_NET%.*}.1"

    # Generate client keys
    local client_private_key
    local client_public_key
    client_private_key=$(wg genkey)
    client_public_key=$(echo "$client_private_key" | wg pubkey)

    # Get server public key and endpoint
    local server_public_key
    server_public_key=$(cat "$CONFIG_DIR/server_public.key")

    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com)
    fi

    # Add client to server config
    cat >> "$CONFIG_DIR/$WG_INTERFACE.conf" << EOF

[Peer]
# $client_name
PublicKey = $client_public_key
AllowedIPs = $client_ip/32
EOF

    # Create client config
    cat > "$CLIENTS_DIR/$client_name.conf" << EOF
[Interface]
PrivateKey = $client_private_key
Address = $client_ip/24
DNS = $dns

[Peer]
PublicKey = $server_public_key
Endpoint = $SERVER_IP:$WG_PORT
AllowedIPs = $allowed_ips
PersistentKeepalive = 25
EOF

    chmod 600 "$CLIENTS_DIR/$client_name.conf"

    # Restart WireGuard
    systemctl restart wg-quick@"$WG_INTERFACE"

    print_success "Client added: $client_name"
    print_info "Client IP: $client_ip"
    print_info "Config file: $CLIENTS_DIR/$client_name.conf"
    print_info ""
    print_info "To use on client device:"
    echo "  1. Copy $CLIENTS_DIR/$client_name.conf to client"
    echo "  2. Or use: $(basename "$0") show-qr $client_name"
}

#######################################
# Remove client
#######################################
cmd_remove_client() {
    check_root

    local client_name="$1"

    if [[ ! -f "$CLIENTS_DIR/$client_name.conf" ]]; then
        print_error "Client not found: $client_name"
        exit 1
    fi

    print_warning "Removing client: $client_name"

    # Get client public key
    local client_public_key
    client_public_key=$(grep "PublicKey" "$CLIENTS_DIR/$client_name.conf" | awk '{print $3}')

    # Remove from server config
    sed -i "/# $client_name/,/AllowedIPs/d" "$CONFIG_DIR/$WG_INTERFACE.conf"

    # Remove client config
    rm -f "$CLIENTS_DIR/$client_name.conf"

    # Restart WireGuard
    systemctl restart wg-quick@"$WG_INTERFACE"

    print_success "Client removed: $client_name"
}

#######################################
# List clients
#######################################
cmd_list_clients() {
    print_info "Configured clients:"
    echo ""

    if [[ ! -d "$CLIENTS_DIR" ]] || [[ -z "$(ls -A "$CLIENTS_DIR")" ]]; then
        print_warning "No clients configured"
        return
    fi

    for conf in "$CLIENTS_DIR"/*.conf; do
        local name
        name=$(basename "$conf" .conf)
        local ip
        ip=$(grep "Address" "$conf" | awk '{print $3}')
        echo "  $name - $ip"
    done
}

#######################################
# Show QR code
#######################################
cmd_show_qr() {
    local client_name="$1"

    if [[ ! -f "$CLIENTS_DIR/$client_name.conf" ]]; then
        print_error "Client not found: $client_name"
        exit 1
    fi

    print_info "QR code for: $client_name"
    echo ""

    qrencode -t ansiutf8 < "$CLIENTS_DIR/$client_name.conf"
}

#######################################
# Show status
#######################################
cmd_status() {
    print_info "WireGuard status:"
    echo ""

    if systemctl is-active --quiet wg-quick@"$WG_INTERFACE"; then
        print_success "Service is running"
    else
        print_error "Service is not running"
    fi

    echo ""
    wg show
}

#######################################
# Uninstall
#######################################
cmd_uninstall() {
    check_root

    print_warning "This will remove WireGuard and all configurations"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi

    # Stop and disable service
    systemctl stop wg-quick@"$WG_INTERFACE" || true
    systemctl disable wg-quick@"$WG_INTERFACE" || true

    # Remove package
    apt-get remove -y wireguard wireguard-tools qrencode

    # Remove configs
    rm -rf "$CONFIG_DIR" "$CLIENTS_DIR"

    print_success "WireGuard uninstalled"
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

    case "$command" in
        install)
            cmd_install
            ;;
        setup-server)
            cmd_setup_server "$@"
            ;;
        add-client)
            if [[ $# -lt 1 ]]; then
                print_error "Client name required"
                exit 1
            fi
            cmd_add_client "$@"
            ;;
        remove-client)
            if [[ $# -lt 1 ]]; then
                print_error "Client name required"
                exit 1
            fi
            cmd_remove_client "$@"
            ;;
        list-clients)
            cmd_list_clients
            ;;
        show-qr)
            if [[ $# -lt 1 ]]; then
                print_error "Client name required"
                exit 1
            fi
            cmd_show_qr "$@"
            ;;
        status)
            cmd_status
            ;;
        uninstall)
            cmd_uninstall
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

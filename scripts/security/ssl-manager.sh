#!/usr/bin/env bash

set -euo pipefail

# SSL Certificate Management Tool
# Manages SSL/TLS certificates for web servers
# Supports Let's Encrypt, self-signed certificates, and certificate monitoring

VERSION="1.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default settings
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"
LETSENCRYPT_DIR="/etc/letsencrypt"
ACME_CLIENT="certbot"
DRY_RUN=false

# Show help
show_help() {
    cat << EOF
SSL Certificate Management Tool v${VERSION}

Usage: $(basename "$0") COMMAND [options]

Commands:
  issue           Issue a new SSL certificate
  renew           Renew existing certificates
  check           Check certificate expiry
  list            List all certificates
  revoke          Revoke a certificate
  install         Install certificate for web server

Issue Options:
  --domain DOMAIN         Domain name (required)
  --email EMAIL          Email for Let's Encrypt notifications
  --self-signed          Generate self-signed certificate
  --letsencrypt          Use Let's Encrypt (default)
  --webroot PATH         Webroot path for Let's Encrypt
  --standalone           Use standalone mode (requires port 80/443)
  --dns                  Use DNS challenge (manual)

Renew Options:
  --all                  Renew all certificates
  --domain DOMAIN        Renew specific domain
  --force                Force renewal even if not expiring

Check Options:
  --domain DOMAIN        Check specific domain
  --all                  Check all certificates
  --days N               Warn if expiring within N days (default: 30)

Common Options:
  --dry-run              Test without making changes
  --verbose              Show detailed output
  --help                 Show this help message

Examples:
  # Issue Let's Encrypt certificate
  $(basename "$0") issue --domain example.com --email admin@example.com

  # Issue self-signed certificate
  $(basename "$0") issue --domain localhost --self-signed

  # Check certificate expiry
  $(basename "$0") check --domain example.com

  # Renew all expiring certificates
  $(basename "$0") renew --all

  # List all certificates
  $(basename "$0") list

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

# Check dependencies
check_dependencies() {
    local missing_deps=()

    if [ "$ACME_CLIENT" = "certbot" ]; then
        if ! command -v certbot &> /dev/null; then
            missing_deps+=("certbot")
        fi
    fi

    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: sudo apt install ${missing_deps[*]}"
        exit 1
    fi
}

# Issue self-signed certificate
issue_self_signed() {
    local domain=$1
    local days=${2:-365}

    check_root

    log_info "Generating self-signed certificate for $domain"

    local key_file="$KEY_DIR/${domain}.key"
    local cert_file="$CERT_DIR/${domain}.crt"

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would generate:"
        log_info "  Key: $key_file"
        log_info "  Certificate: $cert_file"
        return 0
    fi

    # Generate private key
    openssl genrsa -out "$key_file" 2048
    chmod 600 "$key_file"

    # Generate certificate
    openssl req -new -x509 -key "$key_file" -out "$cert_file" -days "$days" \
        -subj "/CN=$domain"

    chmod 644 "$cert_file"

    log_success "Self-signed certificate generated"
    log_info "Key: $key_file"
    log_info "Certificate: $cert_file"
}

# Issue Let's Encrypt certificate
issue_letsencrypt() {
    local domain=$1
    local email=$2
    local webroot=${3:-""}
    local standalone=${4:-false}

    check_root
    check_dependencies

    log_info "Issuing Let's Encrypt certificate for $domain"

    local certbot_args=(
        "certonly"
        "--non-interactive"
        "--agree-tos"
        "--email" "$email"
        "-d" "$domain"
    )

    if [ "$standalone" = true ]; then
        certbot_args+=("--standalone")
    elif [ -n "$webroot" ]; then
        certbot_args+=("--webroot" "-w" "$webroot")
    else
        log_error "Either --webroot or --standalone must be specified"
        exit 1
    fi

    if [ "$DRY_RUN" = true ]; then
        certbot_args+=("--dry-run")
    fi

    if certbot "${certbot_args[@]}"; then
        log_success "Certificate issued successfully"
        log_info "Certificate location: $LETSENCRYPT_DIR/live/$domain/"
    else
        log_error "Failed to issue certificate"
        exit 1
    fi
}

# Renew certificates
renew_certificates() {
    local domain=${1:-""}
    local force=${2:-false}

    check_root
    check_dependencies

    local certbot_args=("renew")

    if [ -n "$domain" ]; then
        certbot_args+=("--cert-name" "$domain")
    fi

    if [ "$force" = true ]; then
        certbot_args+=("--force-renewal")
    fi

    if [ "$DRY_RUN" = true ]; then
        certbot_args+=("--dry-run")
    fi

    log_info "Renewing certificates..."

    if certbot "${certbot_args[@]}"; then
        log_success "Certificate renewal completed"
    else
        log_error "Certificate renewal failed"
        exit 1
    fi
}

# Check certificate expiry
check_certificate() {
    local cert_path=$1
    local warn_days=${2:-30}

    if [ ! -f "$cert_path" ]; then
        log_error "Certificate not found: $cert_path"
        return 1
    fi

    local expiry_date=$(openssl x509 -in "$cert_path" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))

    local domain=$(openssl x509 -in "$cert_path" -noout -subject | sed -n 's/.*CN=\([^,]*\).*/\1/p')

    if [ "$days_until_expiry" -lt 0 ]; then
        log_error "$domain: EXPIRED ${days_until_expiry#-} days ago"
        return 1
    elif [ "$days_until_expiry" -lt "$warn_days" ]; then
        log_warning "$domain: Expires in $days_until_expiry days ($expiry_date)"
        return 1
    else
        log_success "$domain: Valid for $days_until_expiry days ($expiry_date)"
        return 0
    fi
}

# Check all Let's Encrypt certificates
check_all_letsencrypt() {
    local warn_days=${1:-30}

    if [ ! -d "$LETSENCRYPT_DIR/live" ]; then
        log_info "No Let's Encrypt certificates found"
        return 0
    fi

    log_info "Checking Let's Encrypt certificates..."
    echo ""

    local has_issues=0

    for cert_dir in "$LETSENCRYPT_DIR/live"/*; do
        if [ -d "$cert_dir" ]; then
            local cert_file="$cert_dir/cert.pem"
            if [ -f "$cert_file" ]; then
                check_certificate "$cert_file" "$warn_days" || has_issues=1
            fi
        fi
    done

    return $has_issues
}

# List all certificates
list_certificates() {
    log_info "Let's Encrypt Certificates:"
    echo ""

    if [ -d "$LETSENCRYPT_DIR/live" ]; then
        for cert_dir in "$LETSENCRYPT_DIR/live"/*; do
            if [ -d "$cert_dir" ]; then
                local domain=$(basename "$cert_dir")
                local cert_file="$cert_dir/cert.pem"

                if [ -f "$cert_file" ]; then
                    local expiry=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
                    local issuer=$(openssl x509 -in "$cert_file" -noout -issuer | sed 's/issuer=//')

                    echo -e "${BLUE}Domain:${NC} $domain"
                    echo -e "${BLUE}Expires:${NC} $expiry"
                    echo -e "${BLUE}Issuer:${NC} $issuer"
                    echo ""
                fi
            fi
        done
    else
        log_info "No Let's Encrypt certificates found"
    fi

    log_info "Self-signed Certificates in $CERT_DIR:"
    echo ""

    if [ -d "$CERT_DIR" ]; then
        for cert_file in "$CERT_DIR"/*.crt; do
            if [ -f "$cert_file" ]; then
                local domain=$(basename "$cert_file" .crt)
                local expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "Unknown")
                local issuer=$(openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null | sed 's/issuer=//' || echo "Unknown")

                if [[ "$issuer" == *"$domain"* ]] || [[ "$issuer" == *"Self-signed"* ]]; then
                    echo -e "${BLUE}Domain:${NC} $domain"
                    echo -e "${BLUE}Expires:${NC} $expiry"
                    echo -e "${BLUE}Type:${NC} Self-signed"
                    echo ""
                fi
            fi
        done
    fi
}

# Install certificate for web server
install_certificate() {
    local domain=$1
    local server_type=${2:-"nginx"}

    check_root

    log_info "Installing certificate for $domain ($server_type)"

    case $server_type in
        nginx)
            local nginx_conf="/etc/nginx/sites-available/$domain"
            if [ ! -f "$nginx_conf" ]; then
                log_warning "Nginx config not found: $nginx_conf"
                log_info "Sample configuration:"
                cat << EOF

server {
    listen 443 ssl http2;
    server_name $domain;

    ssl_certificate $LETSENCRYPT_DIR/live/$domain/fullchain.pem;
    ssl_certificate_key $LETSENCRYPT_DIR/live/$domain/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Your other settings...
}

EOF
            else
                log_info "Update your nginx config with:"
                echo "  ssl_certificate $LETSENCRYPT_DIR/live/$domain/fullchain.pem;"
                echo "  ssl_certificate_key $LETSENCRYPT_DIR/live/$domain/privkey.pem;"
            fi
            ;;
        apache)
            log_info "For Apache, add to your VirtualHost:"
            echo "  SSLCertificateFile $LETSENCRYPT_DIR/live/$domain/cert.pem"
            echo "  SSLCertificateKeyFile $LETSENCRYPT_DIR/live/$domain/privkey.pem"
            echo "  SSLCertificateChainFile $LETSENCRYPT_DIR/live/$domain/chain.pem"
            ;;
        *)
            log_error "Unsupported server type: $server_type"
            exit 1
            ;;
    esac
}

# Setup automatic renewal
setup_auto_renew() {
    check_root

    log_info "Setting up automatic certificate renewal"

    local cron_job="0 0,12 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'"

    if crontab -l 2>/dev/null | grep -q "certbot renew"; then
        log_info "Automatic renewal already configured"
    else
        if [ "$DRY_RUN" = false ]; then
            (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
            log_success "Automatic renewal configured (runs twice daily)"
        else
            log_info "[DRY RUN] Would add cron job: $cron_job"
        fi
    fi

    # Also setup systemd timer if certbot provides it
    if [ -f /lib/systemd/system/certbot.timer ]; then
        if [ "$DRY_RUN" = false ]; then
            systemctl enable certbot.timer
            systemctl start certbot.timer
            log_success "Certbot systemd timer enabled"
        else
            log_info "[DRY RUN] Would enable certbot systemd timer"
        fi
    fi
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command=$1
    shift

    # Parse common options
    local domain=""
    local email=""
    local webroot=""
    local standalone=false
    local self_signed=false
    local force=false
    local warn_days=30
    local all=false
    local server_type="nginx"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                domain="$2"
                shift 2
                ;;
            --email)
                email="$2"
                shift 2
                ;;
            --webroot)
                webroot="$2"
                shift 2
                ;;
            --standalone)
                standalone=true
                shift
                ;;
            --self-signed)
                self_signed=true
                shift
                ;;
            --force)
                force=true
                shift
                ;;
            --days)
                warn_days="$2"
                shift 2
                ;;
            --all)
                all=true
                shift
                ;;
            --server)
                server_type="$2"
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
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Execute command
    case $command in
        issue)
            if [ -z "$domain" ]; then
                log_error "Domain is required (--domain)"
                exit 1
            fi

            if [ "$self_signed" = true ]; then
                issue_self_signed "$domain"
            else
                if [ -z "$email" ]; then
                    log_error "Email is required for Let's Encrypt (--email)"
                    exit 1
                fi
                issue_letsencrypt "$domain" "$email" "$webroot" "$standalone"
            fi
            ;;
        renew)
            renew_certificates "$domain" "$force"
            ;;
        check)
            if [ "$all" = true ]; then
                check_all_letsencrypt "$warn_days"
            elif [ -n "$domain" ]; then
                local cert_file="$LETSENCRYPT_DIR/live/$domain/cert.pem"
                check_certificate "$cert_file" "$warn_days"
            else
                log_error "Specify --domain or --all"
                exit 1
            fi
            ;;
        list)
            list_certificates
            ;;
        install)
            if [ -z "$domain" ]; then
                log_error "Domain is required (--domain)"
                exit 1
            fi
            install_certificate "$domain" "$server_type"
            ;;
        auto-renew)
            setup_auto_renew
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

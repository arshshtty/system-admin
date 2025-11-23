#!/usr/bin/env bash
#
# Nginx Configuration Generator
# Generate nginx configurations for common use cases
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
DRY_RUN=false

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
# Show help
#######################################
show_help() {
    cat << EOF
Nginx Configuration Generator - Generate nginx configs for common use cases

USAGE:
    $(basename "$0") [OPTIONS] TEMPLATE DOMAIN [ARGS]

TEMPLATES:
    static              Static website
    reverse-proxy       Reverse proxy to backend service
    php                 PHP application (with PHP-FPM)
    wordpress           WordPress site
    nodejs              Node.js application
    python              Python WSGI application
    redirect            Redirect to another domain
    load-balancer       Load balancer for multiple backends

OPTIONS:
    --ssl               Enable SSL/TLS with Let's Encrypt
    --ssl-only          Force HTTPS (redirect HTTP to HTTPS)
    --port PORT         Backend port (for proxy templates)
    --root PATH         Document root (for static templates)
    --output FILE       Output configuration file
    --enable            Enable site immediately
    --dry-run           Show config without creating file
    --help              Show this help message

EXAMPLES:
    # Static website
    $(basename "$0") static example.com --root /var/www/example.com

    # Reverse proxy to local service
    $(basename "$0") reverse-proxy app.example.com --port 3000 --ssl

    # WordPress site with SSL
    $(basename "$0") wordpress blog.example.com --root /var/www/blog --ssl-only

    # Node.js application
    $(basename "$0") nodejs app.example.com --port 8080 --ssl

    # Redirect domain
    $(basename "$0") redirect old.example.com --to https://new.example.com

    # Load balancer
    $(basename "$0") load-balancer api.example.com --backends "10.0.0.1:8080,10.0.0.2:8080"

NOTES:
    - Generated configs are placed in $NGINX_CONF_DIR
    - Use --enable to automatically symlink to $NGINX_ENABLED_DIR
    - SSL certificates should be obtained separately (use certbot)
    - Test config with: nginx -t
    - Reload nginx with: systemctl reload nginx

EOF
}

#######################################
# Generate static site config
#######################################
generate_static() {
    local domain="$1"
    local root="${2:-/var/www/$domain}"
    local ssl="$3"

    cat << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    root $root;
    index index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Logging
    access_log /var/log/nginx/${domain}-access.log;
    error_log /var/log/nginx/${domain}-error.log;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
EOF

    if [[ "$ssl" == "true" ]]; then
        cat << EOF

    # Uncomment after obtaining SSL certificate with certbot
    # listen 443 ssl http2;
    # listen [::]:443 ssl http2;
    # ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    # ssl_protocols TLSv1.2 TLSv1.3;
    # ssl_ciphers HIGH:!aNULL:!MD5;
EOF
    fi

    echo "}"
}

#######################################
# Generate reverse proxy config
#######################################
generate_reverse_proxy() {
    local domain="$1"
    local port="$2"
    local ssl="$3"
    local backend="${4:-127.0.0.1:$port}"

    cat << EOF
upstream ${domain//./_}_backend {
    server $backend;
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    # Logging
    access_log /var/log/nginx/${domain}-access.log;
    error_log /var/log/nginx/${domain}-error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Client max body size
    client_max_body_size 100M;

    location / {
        proxy_pass http://${domain//./_}_backend;
        proxy_http_version 1.1;

        # Proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;

        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
EOF

    if [[ "$ssl" == "true" ]]; then
        cat << EOF

    # Uncomment after obtaining SSL certificate
    # listen 443 ssl http2;
    # listen [::]:443 ssl http2;
    # ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
    # ssl_protocols TLSv1.2 TLSv1.3;
    # ssl_ciphers HIGH:!aNULL:!MD5;
EOF
    fi

    echo "}"
}

#######################################
# Generate PHP config
#######################################
generate_php() {
    local domain="$1"
    local root="${2:-/var/www/$domain}"
    local ssl="$3"

    cat << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    root $root;
    index index.php index.html index.htm;

    # Logging
    access_log /var/log/nginx/${domain}-access.log;
    error_log /var/log/nginx/${domain}-error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # PHP processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    # Deny access to sensitive files
    location ~* (\.log|\.md|\.sql|\.sh)$ {
        deny all;
    }
EOF

    if [[ "$ssl" == "true" ]]; then
        cat << EOF

    # Uncomment after obtaining SSL certificate
    # listen 443 ssl http2;
    # listen [::]:443 ssl http2;
    # ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
EOF
    fi

    echo "}"
}

#######################################
# Generate redirect config
#######################################
generate_redirect() {
    local domain="$1"
    local target="$2"

    cat << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    # Logging
    access_log /var/log/nginx/${domain}-access.log;
    error_log /var/log/nginx/${domain}-error.log;

    # Permanent redirect
    return 301 $target\$request_uri;
}
EOF
}

#######################################
# Generate load balancer config
#######################################
generate_load_balancer() {
    local domain="$1"
    local backends="$2"

    cat << EOF
upstream ${domain//./_}_pool {
    least_conn;
EOF

    IFS=',' read -ra BACKEND_LIST <<< "$backends"
    for backend in "${BACKEND_LIST[@]}"; do
        echo "    server $backend max_fails=3 fail_timeout=30s;"
    done

    cat << EOF
    keepalive 32;
}

server {
    listen 80;
    listen [::]:80;
    server_name $domain;

    # Logging
    access_log /var/log/nginx/${domain}-access.log;
    error_log /var/log/nginx/${domain}-error.log;

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    location / {
        proxy_pass http://${domain//./_}_pool;
        proxy_http_version 1.1;

        # Proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Connection "";

        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # Retry on failure
        proxy_next_upstream error timeout http_502 http_503 http_504;
    }
}
EOF
}

#######################################
# Main function
#######################################
main() {
    local template=""
    local domain=""
    local port=""
    local root=""
    local output=""
    local ssl=false
    local ssl_only=false
    local enable=false
    local target=""
    local backends=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ssl)
                ssl=true
                shift
                ;;
            --ssl-only)
                ssl=true
                ssl_only=true
                shift
                ;;
            --port)
                port="$2"
                shift 2
                ;;
            --root)
                root="$2"
                shift 2
                ;;
            --output)
                output="$2"
                shift 2
                ;;
            --enable)
                enable=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --to)
                target="$2"
                shift 2
                ;;
            --backends)
                backends="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$template" ]]; then
                    template="$1"
                elif [[ -z "$domain" ]]; then
                    domain="$1"
                fi
                shift
                ;;
        esac
    done

    # Validate inputs
    if [[ -z "$template" ]] || [[ -z "$domain" ]]; then
        print_error "Template and domain are required"
        show_help
        exit 1
    fi

    # Set output file
    if [[ -z "$output" ]]; then
        output="$NGINX_CONF_DIR/$domain"
    fi

    # Generate configuration
    local config=""

    case "$template" in
        static)
            config=$(generate_static "$domain" "$root" "$ssl")
            ;;
        reverse-proxy)
            if [[ -z "$port" ]]; then
                print_error "--port is required for reverse-proxy template"
                exit 1
            fi
            config=$(generate_reverse_proxy "$domain" "$port" "$ssl")
            ;;
        php|wordpress)
            config=$(generate_php "$domain" "$root" "$ssl")
            ;;
        nodejs|python)
            if [[ -z "$port" ]]; then
                print_error "--port is required for $template template"
                exit 1
            fi
            config=$(generate_reverse_proxy "$domain" "$port" "$ssl")
            ;;
        redirect)
            if [[ -z "$target" ]]; then
                print_error "--to is required for redirect template"
                exit 1
            fi
            config=$(generate_redirect "$domain" "$target")
            ;;
        load-balancer)
            if [[ -z "$backends" ]]; then
                print_error "--backends is required for load-balancer template"
                exit 1
            fi
            config=$(generate_load_balancer "$domain" "$backends")
            ;;
        *)
            print_error "Unknown template: $template"
            show_help
            exit 1
            ;;
    esac

    # Output or save configuration
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Generated configuration:"
        echo ""
        echo "$config"
    else
        print_info "Writing configuration to: $output"
        echo "$config" | sudo tee "$output" > /dev/null
        print_success "Configuration created: $output"

        if [[ "$enable" == "true" ]]; then
            sudo ln -sf "$output" "$NGINX_ENABLED_DIR/"
            print_success "Site enabled: $domain"
        fi

        print_info "Next steps:"
        echo "  1. Review the configuration: sudo nano $output"
        echo "  2. Test nginx config: sudo nginx -t"
        if [[ "$ssl" == "true" ]]; then
            echo "  3. Obtain SSL certificate: sudo certbot --nginx -d $domain"
        fi
        if [[ "$enable" != "true" ]]; then
            echo "  3. Enable site: sudo ln -s $output $NGINX_ENABLED_DIR/"
        fi
        echo "  4. Reload nginx: sudo systemctl reload nginx"
    fi
}

main "$@"

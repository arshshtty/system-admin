#!/usr/bin/env bash

set -euo pipefail

# Prometheus + Grafana Setup Automation
# Automates deployment of monitoring stack using Docker Compose

VERSION="1.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default settings
INSTALL_DIR="${INSTALL_DIR:-$HOME/monitoring-stack}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
NODE_EXPORTER_PORT="${NODE_EXPORTER_PORT:-9100}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin123}"
DRY_RUN=false

# Show help
show_help() {
    cat << EOF
Prometheus + Grafana Setup Automation v${VERSION}

Usage: $(basename "$0") [options] COMMAND

Commands:
  install         Install monitoring stack
  uninstall       Remove monitoring stack
  start           Start services
  stop            Stop services
  restart         Restart services
  status          Show service status
  logs            Show service logs

Options:
  --install-dir PATH      Installation directory (default: ~/monitoring-stack)
  --prometheus-port PORT  Prometheus port (default: 9090)
  --grafana-port PORT     Grafana port (default: 3000)
  --node-port PORT        Node Exporter port (default: 9100)
  --admin-user USER       Grafana admin username (default: admin)
  --admin-pass PASS       Grafana admin password (default: admin123)
  --dry-run               Test without making changes
  --help                  Show this help message

Examples:
  # Install with defaults
  $(basename "$0") install

  # Install with custom ports
  $(basename "$0") --grafana-port 8080 install

  # Check status
  $(basename "$0") status

  # View logs
  $(basename "$0") logs

Environment Variables:
  INSTALL_DIR             Installation directory
  PROMETHEUS_PORT         Prometheus port
  GRAFANA_PORT            Grafana port
  NODE_EXPORTER_PORT      Node Exporter port
  GRAFANA_ADMIN_USER      Grafana admin username
  GRAFANA_ADMIN_PASSWORD  Grafana admin password

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

# Check dependencies
check_dependencies() {
    local missing_deps=()

    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        missing_deps+=("docker-compose")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install Docker first with: ./scripts/bootstrap/install-essentials.sh --docker"
        exit 1
    fi
}

# Create Prometheus configuration
create_prometheus_config() {
    cat > "$INSTALL_DIR/prometheus/prometheus.yml" << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'monitoring-stack'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets: []

# Load rules once and periodically evaluate them
rule_files:
  - "alerts/*.yml"

# Scrape configurations
scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
        labels:
          instance: 'local-server'

  # Docker containers (cAdvisor)
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  # Add your custom targets here
  # - job_name: 'my-app'
  #   static_configs:
  #     - targets: ['app:8080']
EOF

    log_success "Prometheus configuration created"
}

# Create alert rules
create_alert_rules() {
    mkdir -p "$INSTALL_DIR/prometheus/alerts"

    cat > "$INSTALL_DIR/prometheus/alerts/system.yml" << 'EOF'
groups:
  - name: system_alerts
    interval: 30s
    rules:
      # High CPU usage
      - alert: HighCpuUsage
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% (current value: {{ $value }}%)"

      # High memory usage
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% (current value: {{ $value }}%)"

      # High disk usage
      - alert: HighDiskUsage
        expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage on {{ $labels.instance }}"
          description: "Disk usage is above 85% (current value: {{ $value }}%)"

      # Service down
      - alert: ServiceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "Service {{ $labels.job }} on {{ $labels.instance }} has been down for more than 2 minutes"
EOF

    log_success "Alert rules created"
}

# Create Grafana provisioning configs
create_grafana_provisioning() {
    mkdir -p "$INSTALL_DIR/grafana/provisioning/datasources"
    mkdir -p "$INSTALL_DIR/grafana/provisioning/dashboards"

    # Datasource configuration
    cat > "$INSTALL_DIR/grafana/provisioning/datasources/prometheus.yml" << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

    # Dashboard provider configuration
    cat > "$INSTALL_DIR/grafana/provisioning/dashboards/default.yml" << EOF
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

    log_success "Grafana provisioning configured"
}

# Create Docker Compose file
create_docker_compose() {
    cat > "$INSTALL_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    ports:
      - "${PROMETHEUS_PORT}:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/alerts:/etc/prometheus/alerts
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
    networks:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "${GRAFANA_PORT}:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    networks:
      - monitoring
    depends_on:
      - prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "${NODE_EXPORTER_PORT}:9100"
    command:
      - '--path.rootfs=/host'
    volumes:
      - '/:/host:ro,rslave'
    networks:
      - monitoring

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "8081:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
    privileged: true
    networks:
      - monitoring

volumes:
  prometheus-data:
  grafana-data:

networks:
  monitoring:
    driver: bridge
EOF

    log_success "Docker Compose configuration created"
}

# Create README for the installation
create_readme() {
    cat > "$INSTALL_DIR/README.md" << 'EOF'
# Monitoring Stack

This directory contains a complete Prometheus + Grafana monitoring stack.

## Services

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000
- **Node Exporter**: http://localhost:9100
- **cAdvisor**: http://localhost:8081

## Default Credentials

- Grafana Username: admin
- Grafana Password: admin123 (change this!)

## Management

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Restart services
docker-compose restart

# Update images
docker-compose pull
docker-compose up -d
```

## Customization

### Adding Scrape Targets

Edit `prometheus/prometheus.yml` and add your targets:

```yaml
scrape_configs:
  - job_name: 'my-app'
    static_configs:
      - targets: ['app:8080']
```

Then restart Prometheus:
```bash
docker-compose restart prometheus
```

### Adding Dashboards

1. Create dashboard in Grafana UI
2. Export as JSON
3. Save to `grafana/provisioning/dashboards/`
4. Restart Grafana

### Alert Rules

Edit `prometheus/alerts/system.yml` to customize alerts.

## Importing Dashboards

Popular dashboards from https://grafana.com/grafana/dashboards/:

- Node Exporter Full: 1860
- Docker Monitoring: 893
- Prometheus Stats: 2

## Data Retention

- Prometheus: 30 days (configurable in docker-compose.yml)
- Grafana: Unlimited

## Backup

```bash
# Backup Grafana data
docker-compose exec grafana grafana-cli admin export-dashboard

# Backup Prometheus data
docker run --rm -v monitoring-stack_prometheus-data:/data -v $(pwd):/backup ubuntu tar czf /backup/prometheus-backup.tar.gz /data
```

EOF

    log_success "README created"
}

# Install monitoring stack
install_stack() {
    log_info "Installing monitoring stack to: $INSTALL_DIR"

    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        log_warning "Installation directory already exists"
        read -p "Overwrite existing installation? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would create:"
        log_info "  - $INSTALL_DIR/docker-compose.yml"
        log_info "  - $INSTALL_DIR/prometheus/prometheus.yml"
        log_info "  - $INSTALL_DIR/grafana/provisioning/"
        return 0
    fi

    # Create directory structure
    mkdir -p "$INSTALL_DIR"/{prometheus,grafana/provisioning/{datasources,dashboards}}

    # Create configurations
    create_prometheus_config
    create_alert_rules
    create_grafana_provisioning
    create_docker_compose
    create_readme

    log_success "Monitoring stack installed successfully!"
    echo ""
    log_info "To start the stack:"
    echo "  cd $INSTALL_DIR"
    echo "  docker-compose up -d"
    echo ""
    log_info "Access services at:"
    echo "  Prometheus: http://localhost:$PROMETHEUS_PORT"
    echo "  Grafana:    http://localhost:$GRAFANA_PORT"
    echo "  Username:   $GRAFANA_ADMIN_USER"
    echo "  Password:   $GRAFANA_ADMIN_PASSWORD"
    echo ""
    log_warning "Remember to change the default Grafana password!"
}

# Uninstall monitoring stack
uninstall_stack() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Installation not found at: $INSTALL_DIR"
        exit 1
    fi

    log_warning "This will remove the monitoring stack and all data!"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would remove $INSTALL_DIR"
        return 0
    fi

    cd "$INSTALL_DIR"
    docker-compose down -v
    cd - > /dev/null
    rm -rf "$INSTALL_DIR"

    log_success "Monitoring stack uninstalled"
}

# Start services
start_services() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Installation not found. Run 'install' first."
        exit 1
    fi

    log_info "Starting monitoring stack..."
    cd "$INSTALL_DIR"
    docker-compose up -d
    log_success "Services started"
    docker-compose ps
}

# Stop services
stop_services() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Installation not found"
        exit 1
    fi

    log_info "Stopping monitoring stack..."
    cd "$INSTALL_DIR"
    docker-compose down
    log_success "Services stopped"
}

# Restart services
restart_services() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Installation not found"
        exit 1
    fi

    log_info "Restarting monitoring stack..."
    cd "$INSTALL_DIR"
    docker-compose restart
    log_success "Services restarted"
}

# Show status
show_status() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Installation not found"
        exit 1
    fi

    cd "$INSTALL_DIR"
    docker-compose ps
}

# Show logs
show_logs() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Installation not found"
        exit 1
    fi

    cd "$INSTALL_DIR"
    docker-compose logs -f
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    # Parse options first
    local command=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --prometheus-port)
                PROMETHEUS_PORT="$2"
                shift 2
                ;;
            --grafana-port)
                GRAFANA_PORT="$2"
                shift 2
                ;;
            --node-port)
                NODE_EXPORTER_PORT="$2"
                shift 2
                ;;
            --admin-user)
                GRAFANA_ADMIN_USER="$2"
                shift 2
                ;;
            --admin-pass)
                GRAFANA_ADMIN_PASSWORD="$2"
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
            install|uninstall|start|stop|restart|status|logs)
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

    # Execute command
    case $command in
        install)
            check_dependencies
            install_stack
            ;;
        uninstall)
            uninstall_stack
            ;;
        start)
            check_dependencies
            start_services
            ;;
        stop)
            check_dependencies
            stop_services
            ;;
        restart)
            check_dependencies
            restart_services
            ;;
        status)
            check_dependencies
            show_status
            ;;
        logs)
            check_dependencies
            show_logs
            ;;
    esac
}

main "$@"

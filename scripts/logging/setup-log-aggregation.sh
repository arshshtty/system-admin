#!/usr/bin/env bash

set -euo pipefail

# Log Aggregation Setup Script
# Deploys Loki + Promtail + Grafana for centralized logging

VERSION="1.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default settings
INSTALL_DIR="${INSTALL_DIR:-$HOME/log-aggregation}"
LOKI_PORT="${LOKI_PORT:-3100}"
GRAFANA_PORT="${GRAFANA_PORT:-3001}"
GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin123}"
STACK_TYPE="${STACK_TYPE:-loki}"  # loki or elk
DRY_RUN=false

# Show help
show_help() {
    cat << EOF
Log Aggregation Setup Script v${VERSION}

Usage: $(basename "$0") [options] COMMAND

Commands:
  install         Install log aggregation stack
  uninstall       Remove log aggregation stack
  start           Start services
  stop            Stop services
  restart         Restart services
  status          Show service status
  logs            Show service logs

Options:
  --install-dir PATH      Installation directory (default: ~/log-aggregation)
  --stack TYPE            Stack type: loki or elk (default: loki)
  --loki-port PORT        Loki port (default: 3100)
  --grafana-port PORT     Grafana port (default: 3001)
  --admin-user USER       Grafana admin username (default: admin)
  --admin-pass PASS       Grafana admin password (default: admin123)
  --dry-run               Test without making changes
  --help                  Show this help message

Stack Types:
  loki    - Lightweight: Loki + Promtail + Grafana (recommended)
  elk     - Full-featured: Elasticsearch + Logstash + Kibana

Examples:
  # Install Loki stack (lightweight, recommended)
  $(basename "$0") install

  # Install ELK stack
  $(basename "$0") --stack elk install

  # Start services
  $(basename "$0") start

  # View logs
  $(basename "$0") logs

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
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required but not installed"
        log_info "Install with: ./scripts/bootstrap/install-essentials.sh --docker"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
        log_error "Docker Compose is required but not installed"
        exit 1
    fi
}

# Create Loki configuration
create_loki_config() {
    mkdir -p "$INSTALL_DIR/loki"

    cat > "$INSTALL_DIR/loki/loki-config.yml" << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://localhost:9093

limits_config:
  retention_period: 168h  # 7 days
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

compactor:
  working_directory: /loki/compactor
  shared_store: filesystem
  compaction_interval: 5m
EOF

    log_success "Loki configuration created"
}

# Create Promtail configuration
create_promtail_config() {
    mkdir -p "$INSTALL_DIR/promtail"

    cat > "$INSTALL_DIR/promtail/promtail-config.yml" << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # System logs
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  # Docker container logs
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          job: docker
          __path__: /var/lib/docker/containers/*/*-json.log
    pipeline_stages:
      - json:
          expressions:
            log: log
            stream: stream
            time: time
      - labels:
          stream:
      - timestamp:
          source: time
          format: RFC3339Nano
      - output:
          source: log

  # Application logs (customize as needed)
  - job_name: app
    static_configs:
      - targets:
          - localhost
        labels:
          job: app
          __path__: /app/logs/*.log
EOF

    log_success "Promtail configuration created"
}

# Create Grafana datasource for Loki
create_grafana_loki_datasource() {
    mkdir -p "$INSTALL_DIR/grafana/provisioning/datasources"

    cat > "$INSTALL_DIR/grafana/provisioning/datasources/loki.yml" << 'EOF'
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
    editable: true
    jsonData:
      maxLines: 1000
EOF

    log_success "Grafana Loki datasource configured"
}

# Create Docker Compose for Loki stack
create_loki_docker_compose() {
    cat > "$INSTALL_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    ports:
      - "${LOKI_PORT}:3100"
    volumes:
      - ./loki/loki-config.yml:/etc/loki/loki-config.yml
      - loki-data:/loki
    command: -config.file=/etc/loki/loki-config.yml
    networks:
      - logging

  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ./promtail/promtail-config.yml:/etc/promtail/promtail-config.yml
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    command: -config.file=/etc/promtail/promtail-config.yml
    networks:
      - logging
    depends_on:
      - loki

  grafana:
    image: grafana/grafana:latest
    container_name: grafana-logs
    restart: unless-stopped
    ports:
      - "${GRAFANA_PORT}:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GRAFANA_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
      - GF_PATHS_PROVISIONING=/etc/grafana/provisioning
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    networks:
      - logging
    depends_on:
      - loki

volumes:
  loki-data:
  grafana-data:

networks:
  logging:
    driver: bridge
EOF

    log_success "Loki Docker Compose configuration created"
}

# Create Docker Compose for ELK stack
create_elk_docker_compose() {
    cat > "$INSTALL_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
    container_name: elasticsearch
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch-data:/usr/share/elasticsearch/data
    networks:
      - elk

  logstash:
    image: docker.elastic.co/logstash/logstash:8.8.0
    container_name: logstash
    restart: unless-stopped
    volumes:
      - ./logstash/logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
    ports:
      - "5000:5000"
      - "9600:9600"
    networks:
      - elk
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.8.0
    container_name: kibana
    restart: unless-stopped
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    networks:
      - elk
    depends_on:
      - elasticsearch

  filebeat:
    image: docker.elastic.co/beats/filebeat:8.8.0
    container_name: filebeat
    restart: unless-stopped
    user: root
    volumes:
      - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - filebeat-data:/usr/share/filebeat/data
    command: filebeat -e -strict.perms=false
    networks:
      - elk
    depends_on:
      - elasticsearch
      - logstash

volumes:
  elasticsearch-data:
  filebeat-data:

networks:
  elk:
    driver: bridge
EOF

    log_success "ELK Docker Compose configuration created"
}

# Create ELK configuration files
create_elk_configs() {
    mkdir -p "$INSTALL_DIR"/{logstash,filebeat}

    # Logstash configuration
    cat > "$INSTALL_DIR/logstash/logstash.conf" << 'EOF'
input {
  beats {
    port => 5000
  }
}

filter {
  if [docker][container][name] {
    mutate {
      add_field => { "container_name" => "%{[docker][container][name]}" }
    }
  }

  grok {
    match => { "message" => "%{COMBINEDAPACHELOG}" }
    tag_on_failure => []
  }

  date {
    match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
EOF

    # Filebeat configuration
    cat > "$INSTALL_DIR/filebeat/filebeat.yml" << 'EOF'
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/*.log
      - /var/log/syslog

  - type: container
    enabled: true
    paths:
      - '/var/lib/docker/containers/*/*.log'

output.logstash:
  hosts: ["logstash:5000"]

logging.level: info
EOF

    log_success "ELK configuration files created"
}

# Create README
create_readme() {
    local stack_name=$1
    local access_info=""

    if [ "$stack_name" = "loki" ]; then
        access_info="- **Grafana**: http://localhost:$GRAFANA_PORT
- **Loki API**: http://localhost:$LOKI_PORT"
    else
        access_info="- **Kibana**: http://localhost:5601
- **Elasticsearch**: http://localhost:9200
- **Logstash**: http://localhost:5000"
    fi

    cat > "$INSTALL_DIR/README.md" << EOF
# Log Aggregation Stack ($stack_name)

Centralized logging solution for collecting, storing, and analyzing logs.

## Access Points

$access_info

## Default Credentials

- Username: $GRAFANA_ADMIN_USER
- Password: $GRAFANA_ADMIN_PASSWORD

## Management

\`\`\`bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Restart services
docker-compose restart
\`\`\`

## Log Sources

The stack is configured to collect logs from:
- System logs (/var/log/*)
- Docker container logs
- Application logs (customize in config files)

## Querying Logs

### Loki (if using Loki stack)

In Grafana, use LogQL queries:
\`\`\`
{job="varlogs"} |= "error"
{job="docker"} |= "nginx"
\`\`\`

### Kibana (if using ELK stack)

1. Open Kibana at http://localhost:5601
2. Create an index pattern: logs-*
3. Use Kibana Discover to search logs

## Retention

- Loki: 7 days (configurable in loki-config.yml)
- Elasticsearch: Unlimited (manage with ILM policies)

## Customization

### Adding Log Sources

Edit the appropriate config file:
- Loki: \`promtail/promtail-config.yml\`
- ELK: \`filebeat/filebeat.yml\`

### Alert Rules

Configure alerts in:
- Grafana: Alerting section
- ELK: Elasticsearch Watcher

## Troubleshooting

\`\`\`bash
# Check container status
docker-compose ps

# View container logs
docker-compose logs [service-name]

# Test connectivity
curl http://localhost:$LOKI_PORT/ready  # Loki
curl http://localhost:9200/_cluster/health  # Elasticsearch
\`\`\`

EOF

    log_success "README created"
}

# Install log aggregation stack
install_stack() {
    log_info "Installing $STACK_TYPE log aggregation stack to: $INSTALL_DIR"

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
        log_info "[DRY RUN] Would install $STACK_TYPE stack to $INSTALL_DIR"
        return 0
    fi

    mkdir -p "$INSTALL_DIR"

    if [ "$STACK_TYPE" = "loki" ]; then
        create_loki_config
        create_promtail_config
        create_grafana_loki_datasource
        create_loki_docker_compose
    else
        create_elk_configs
        create_elk_docker_compose
    fi

    create_readme "$STACK_TYPE"

    log_success "Log aggregation stack installed successfully!"
    echo ""
    log_info "To start the stack:"
    echo "  cd $INSTALL_DIR"
    echo "  docker-compose up -d"
    echo ""

    if [ "$STACK_TYPE" = "loki" ]; then
        log_info "Access Grafana at: http://localhost:$GRAFANA_PORT"
    else
        log_info "Access Kibana at: http://localhost:5601"
    fi

    echo "Username: $GRAFANA_ADMIN_USER"
    echo "Password: $GRAFANA_ADMIN_PASSWORD"
}

# Uninstall stack
uninstall_stack() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Installation not found at: $INSTALL_DIR"
        exit 1
    fi

    log_warning "This will remove the log aggregation stack and all data!"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    cd "$INSTALL_DIR"
    docker-compose down -v
    cd - > /dev/null
    rm -rf "$INSTALL_DIR"

    log_success "Log aggregation stack uninstalled"
}

# Start services
start_services() {
    if [ ! -d "$INSTALL_DIR" ]; then
        log_error "Installation not found. Run 'install' first."
        exit 1
    fi

    log_info "Starting log aggregation stack..."
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

    log_info "Stopping log aggregation stack..."
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

    log_info "Restarting log aggregation stack..."
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

    local command=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --stack)
                STACK_TYPE="$2"
                shift 2
                ;;
            --loki-port)
                LOKI_PORT="$2"
                shift 2
                ;;
            --grafana-port)
                GRAFANA_PORT="$2"
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

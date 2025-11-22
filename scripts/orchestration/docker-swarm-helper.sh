#!/usr/bin/env bash

set -euo pipefail

# Docker Swarm Helper Script
# Simplifies Docker Swarm cluster management

VERSION="1.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Show help
show_help() {
    cat << EOF
Docker Swarm Helper Script v${VERSION}

Usage: $(basename "$0") COMMAND [options]

Commands:
  init            Initialize swarm cluster
  join            Join worker node to cluster
  leave           Leave swarm cluster
  status          Show cluster status
  deploy          Deploy a stack
  remove          Remove a stack
  scale           Scale a service
  update          Update a service
  rollback        Rollback a service
  backup          Backup swarm configuration
  restore         Restore swarm configuration

Init Options:
  --advertise-addr IP     Advertise address for the manager

Join Options:
  --token TOKEN          Join token
  --manager-addr IP      Manager address

Deploy Options:
  --file FILE            Docker Compose file
  --name STACK           Stack name

Scale Options:
  --service NAME         Service name
  --replicas N           Number of replicas

Examples:
  # Initialize swarm
  $(basename "$0") init --advertise-addr 192.168.1.100

  # Show cluster status
  $(basename "$0") status

  # Deploy a stack
  $(basename "$0") deploy --file docker-compose.yml --name myapp

  # Scale a service
  $(basename "$0") scale --service myapp_web --replicas 5

  # Backup swarm config
  $(basename "$0") backup

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

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        log_info "Install with: ./scripts/bootstrap/install-essentials.sh --docker"
        exit 1
    fi
}

# Check if swarm is initialized
is_swarm_initialized() {
    docker info 2>/dev/null | grep -q "Swarm: active"
}

# Initialize swarm
init_swarm() {
    local advertise_addr=${1:-""}

    check_docker

    if is_swarm_initialized; then
        log_warning "Swarm is already initialized"
        return 0
    fi

    log_info "Initializing Docker Swarm..."

    local init_cmd="docker swarm init"
    if [ -n "$advertise_addr" ]; then
        init_cmd="$init_cmd --advertise-addr $advertise_addr"
    fi

    if $init_cmd; then
        log_success "Swarm initialized successfully"
        echo ""
        log_info "To add worker nodes, run on the worker:"
        docker swarm join-token worker | grep "docker swarm join"
        echo ""
        log_info "To add manager nodes, run on the manager:"
        docker swarm join-token manager | grep "docker swarm join"
    else
        log_error "Failed to initialize swarm"
        exit 1
    fi
}

# Join swarm
join_swarm() {
    local token=$1
    local manager_addr=$2

    check_docker

    if is_swarm_initialized; then
        log_warning "Already part of a swarm cluster"
        return 0
    fi

    log_info "Joining swarm cluster..."

    if docker swarm join --token "$token" "$manager_addr"; then
        log_success "Successfully joined swarm cluster"
    else
        log_error "Failed to join swarm cluster"
        exit 1
    fi
}

# Leave swarm
leave_swarm() {
    check_docker

    if ! is_swarm_initialized; then
        log_warning "Not part of a swarm cluster"
        return 0
    fi

    log_warning "This will remove this node from the swarm cluster"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        return 0
    fi

    if docker swarm leave --force; then
        log_success "Left swarm cluster"
    else
        log_error "Failed to leave swarm cluster"
        exit 1
    fi
}

# Show cluster status
show_status() {
    check_docker

    if ! is_swarm_initialized; then
        log_warning "Swarm is not initialized"
        log_info "Run '$(basename "$0") init' to initialize swarm"
        return 1
    fi

    log_info "Swarm Cluster Status"
    echo ""

    # Show nodes
    log_info "Nodes:"
    docker node ls
    echo ""

    # Show services
    log_info "Services:"
    if [ "$(docker service ls -q | wc -l)" -gt 0 ]; then
        docker service ls
    else
        echo "No services running"
    fi
    echo ""

    # Show stacks
    log_info "Stacks:"
    if [ "$(docker stack ls | tail -n +2 | wc -l)" -gt 0 ]; then
        docker stack ls
    else
        echo "No stacks deployed"
    fi
}

# Deploy stack
deploy_stack() {
    local compose_file=$1
    local stack_name=$2

    check_docker

    if ! is_swarm_initialized; then
        log_error "Swarm is not initialized"
        exit 1
    fi

    if [ ! -f "$compose_file" ]; then
        log_error "Compose file not found: $compose_file"
        exit 1
    fi

    log_info "Deploying stack: $stack_name"

    if docker stack deploy -c "$compose_file" "$stack_name"; then
        log_success "Stack deployed successfully"
        echo ""
        log_info "Stack services:"
        docker stack services "$stack_name"
    else
        log_error "Failed to deploy stack"
        exit 1
    fi
}

# Remove stack
remove_stack() {
    local stack_name=$1

    check_docker

    if ! is_swarm_initialized; then
        log_error "Swarm is not initialized"
        exit 1
    fi

    log_warning "This will remove all services in stack: $stack_name"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        return 0
    fi

    if docker stack rm "$stack_name"; then
        log_success "Stack removed: $stack_name"
    else
        log_error "Failed to remove stack"
        exit 1
    fi
}

# Scale service
scale_service() {
    local service_name=$1
    local replicas=$2

    check_docker

    if ! is_swarm_initialized; then
        log_error "Swarm is not initialized"
        exit 1
    fi

    log_info "Scaling $service_name to $replicas replicas..."

    if docker service scale "$service_name=$replicas"; then
        log_success "Service scaled successfully"
        docker service ps "$service_name"
    else
        log_error "Failed to scale service"
        exit 1
    fi
}

# Update service
update_service() {
    local service_name=$1
    local image=$2

    check_docker

    if ! is_swarm_initialized; then
        log_error "Swarm is not initialized"
        exit 1
    fi

    log_info "Updating service: $service_name"

    if docker service update --image "$image" "$service_name"; then
        log_success "Service updated successfully"
        docker service ps "$service_name"
    else
        log_error "Failed to update service"
        exit 1
    fi
}

# Rollback service
rollback_service() {
    local service_name=$1

    check_docker

    if ! is_swarm_initialized; then
        log_error "Swarm is not initialized"
        exit 1
    fi

    log_info "Rolling back service: $service_name"

    if docker service rollback "$service_name"; then
        log_success "Service rolled back successfully"
    else
        log_error "Failed to rollback service"
        exit 1
    fi
}

# Backup swarm configuration
backup_swarm() {
    local backup_dir=${1:-"/tmp/swarm-backup-$(date +%Y%m%d-%H%M%S)"}

    check_docker

    if ! is_swarm_initialized; then
        log_error "Swarm is not initialized"
        exit 1
    fi

    log_info "Backing up swarm configuration to: $backup_dir"

    mkdir -p "$backup_dir"

    # Export node information
    docker node ls --format "{{json .}}" > "$backup_dir/nodes.json"

    # Export service configurations
    for service in $(docker service ls --format "{{.Name}}"); do
        docker service inspect "$service" > "$backup_dir/service-$service.json"
    done

    # Export stack information
    docker stack ls --format "{{.Name}}" > "$backup_dir/stacks.txt"

    # Create archive
    tar czf "$backup_dir.tar.gz" -C "$(dirname "$backup_dir")" "$(basename "$backup_dir")"
    rm -rf "$backup_dir"

    log_success "Backup created: $backup_dir.tar.gz"
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    local command=""
    local advertise_addr=""
    local token=""
    local manager_addr=""
    local compose_file=""
    local stack_name=""
    local service_name=""
    local replicas=""
    local image=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --advertise-addr)
                advertise_addr="$2"
                shift 2
                ;;
            --token)
                token="$2"
                shift 2
                ;;
            --manager-addr)
                manager_addr="$2"
                shift 2
                ;;
            --file)
                compose_file="$2"
                shift 2
                ;;
            --name)
                stack_name="$2"
                shift 2
                ;;
            --service)
                service_name="$2"
                shift 2
                ;;
            --replicas)
                replicas="$2"
                shift 2
                ;;
            --image)
                image="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            init|join|leave|status|deploy|remove|scale|update|rollback|backup|restore)
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

    case $command in
        init)
            init_swarm "$advertise_addr"
            ;;
        join)
            if [ -z "$token" ] || [ -z "$manager_addr" ]; then
                log_error "--token and --manager-addr are required"
                exit 1
            fi
            join_swarm "$token" "$manager_addr"
            ;;
        leave)
            leave_swarm
            ;;
        status)
            show_status
            ;;
        deploy)
            if [ -z "$compose_file" ] || [ -z "$stack_name" ]; then
                log_error "--file and --name are required"
                exit 1
            fi
            deploy_stack "$compose_file" "$stack_name"
            ;;
        remove)
            if [ -z "$stack_name" ]; then
                log_error "--name is required"
                exit 1
            fi
            remove_stack "$stack_name"
            ;;
        scale)
            if [ -z "$service_name" ] || [ -z "$replicas" ]; then
                log_error "--service and --replicas are required"
                exit 1
            fi
            scale_service "$service_name" "$replicas"
            ;;
        update)
            if [ -z "$service_name" ] || [ -z "$image" ]; then
                log_error "--service and --image are required"
                exit 1
            fi
            update_service "$service_name" "$image"
            ;;
        rollback)
            if [ -z "$service_name" ]; then
                log_error "--service is required"
                exit 1
            fi
            rollback_service "$service_name"
            ;;
        backup)
            backup_swarm
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

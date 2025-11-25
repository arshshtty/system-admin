#!/usr/bin/env bash
#
# Safe Service Restart Helper
# Safely restart services with validation and rollback
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SERVICE_NAME=""
SERVICE_TYPE="systemd"  # systemd or docker
WAIT_TIME=5
MAX_RETRIES=3
PRE_CHECK=true
POST_CHECK=true
ROLLBACK_ON_FAILURE=true
BACKUP_CONFIG=false
CONFIG_FILES=""
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
Safe Service Restart Helper

Safely restart systemd services or Docker containers with validation and rollback.

USAGE:
    $(basename "$0") --service SERVICE [OPTIONS]

OPTIONS:
    --service NAME          Service or container name to restart (required)
    --type TYPE             Service type: systemd or docker (default: systemd)
    --wait TIME             Seconds to wait before health check (default: 5)
    --retries NUM           Max restart attempts (default: 3)
    --no-pre-check          Skip pre-restart validation
    --no-post-check         Skip post-restart validation
    --no-rollback           Don't rollback on failure
    --backup-config FILES   Backup config files before restart (comma-separated)
    --verbose               Show detailed output
    --dry-run               Show what would be done without doing it
    --help                  Show this help message

EXAMPLES:
    # Restart systemd service
    sudo $(basename "$0") --service nginx

    # Restart Docker container with health check
    $(basename "$0") --service web-app --type docker --wait 10

    # Restart with config backup
    sudo $(basename "$0") --service nginx --backup-config /etc/nginx/nginx.conf,/etc/nginx/sites-enabled/default

    # Multiple retry attempts
    sudo $(basename "$0") --service mysql --retries 5 --wait 10

    # Dry run to see what would happen
    $(basename "$0") --service nginx --dry-run

FEATURES:
    - Pre-restart health validation
    - Graceful restart with wait period
    - Post-restart health validation
    - Automatic rollback on failure
    - Config file backup
    - Multiple retry attempts
    - Support for systemd services and Docker containers

VALIDATION:
    - For systemd: Checks service status before and after
    - For docker: Checks container health status
    - Waits for service to stabilize before declaring success
EOF
}

# Function to check if service is systemd
check_systemd_service() {
    local service=$1

    if systemctl list-units --all --type=service --no-legend | grep -q "^${service}.service"; then
        return 0
    else
        return 1
    fi
}

# Function to check systemd service status
check_systemd_status() {
    local service=$1

    if systemctl is-active --quiet "$service"; then
        return 0
    else
        return 1
    fi
}

# Function to get systemd service uptime
get_systemd_uptime() {
    local service=$1

    systemctl show "$service" --property=ActiveEnterTimestamp | cut -d'=' -f2
}

# Function to check Docker container
check_docker_container() {
    local container=$1

    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        return 0
    else
        return 1
    fi
}

# Function to check Docker container status
check_docker_status() {
    local container=$1

    local status
    status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "not_found")

    if [ "$status" = "running" ]; then
        # Check health status if available
        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")

        if [ "$health" = "healthy" ] || [ "$health" = "none" ]; then
            return 0
        else
            if [ "$VERBOSE" = true ]; then
                print_warning "Container is running but health check failed: $health"
            fi
            return 1
        fi
    else
        return 1
    fi
}

# Function to backup configuration files
backup_configs() {
    if [ -z "$CONFIG_FILES" ]; then
        return
    fi

    local backup_dir="/tmp/service-backup-$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    print_info "Backing up configuration files to: $backup_dir"

    IFS=',' read -ra FILES <<< "$CONFIG_FILES"
    for file in "${FILES[@]}"; do
        if [ -f "$file" ]; then
            if [ "$DRY_RUN" = false ]; then
                cp -p "$file" "$backup_dir/"
                print_success "Backed up: $file"
            else
                print_info "[DRY RUN] Would backup: $file"
            fi
        else
            print_warning "Config file not found: $file"
        fi
    done

    echo "$backup_dir"
}

# Function to restart systemd service
restart_systemd_service() {
    local service=$1

    print_info "Restarting systemd service: $service"

    if [ "$DRY_RUN" = false ]; then
        if systemctl restart "$service"; then
            print_success "Service restart command executed"
            return 0
        else
            print_error "Failed to restart service"
            return 1
        fi
    else
        print_info "[DRY RUN] Would execute: systemctl restart $service"
        return 0
    fi
}

# Function to restart Docker container
restart_docker_container() {
    local container=$1

    print_info "Restarting Docker container: $container"

    if [ "$DRY_RUN" = false ]; then
        if docker restart "$container" &>/dev/null; then
            print_success "Container restart command executed"
            return 0
        else
            print_error "Failed to restart container"
            return 1
        fi
    else
        print_info "[DRY RUN] Would execute: docker restart $container"
        return 0
    fi
}

# Function to wait and validate
wait_and_validate() {
    local service=$1
    local service_type=$2

    print_info "Waiting ${WAIT_TIME}s for service to stabilize..."
    sleep "$WAIT_TIME"

    print_info "Performing post-restart validation..."

    local attempt=0
    while [ $attempt -lt "$MAX_RETRIES" ]; do
        if [ "$service_type" = "systemd" ]; then
            if check_systemd_status "$service"; then
                print_success "Service is active and running"
                return 0
            fi
        else
            if check_docker_status "$service"; then
                print_success "Container is healthy and running"
                return 0
            fi
        fi

        ((attempt++))
        if [ $attempt -lt "$MAX_RETRIES" ]; then
            print_warning "Validation failed, attempt $attempt/$MAX_RETRIES"
            sleep 2
        fi
    done

    print_error "Service validation failed after $MAX_RETRIES attempts"
    return 1
}

# Function to perform rollback
perform_rollback() {
    local service=$1
    local service_type=$2

    if [ "$ROLLBACK_ON_FAILURE" = false ]; then
        print_warning "Rollback disabled, skipping"
        return
    fi

    print_warning "Attempting to recover service..."

    if [ "$service_type" = "systemd" ]; then
        if [ "$DRY_RUN" = false ]; then
            systemctl start "$service" 2>/dev/null || true
        else
            print_info "[DRY RUN] Would attempt: systemctl start $service"
        fi
    else
        if [ "$DRY_RUN" = false ]; then
            docker start "$service" 2>/dev/null || true
        else
            print_info "[DRY RUN] Would attempt: docker start $service"
        fi
    fi

    sleep 3

    # Check if recovery worked
    if [ "$service_type" = "systemd" ]; then
        if check_systemd_status "$service"; then
            print_success "Service recovered"
        else
            print_error "Recovery failed - manual intervention required"
        fi
    else
        if check_docker_status "$service"; then
            print_success "Container recovered"
        else
            print_error "Recovery failed - manual intervention required"
        fi
    fi
}

# Main restart logic
safe_restart() {
    local service=$1
    local service_type=$2

    # Verify service exists
    print_info "Verifying service exists..."
    if [ "$service_type" = "systemd" ]; then
        if ! check_systemd_service "$service"; then
            print_error "Systemd service not found: $service"
            exit 1
        fi
    else
        if ! check_docker_container "$service"; then
            print_error "Docker container not found: $service"
            exit 1
        fi
    fi

    # Pre-restart check
    if [ "$PRE_CHECK" = true ]; then
        print_info "Performing pre-restart validation..."
        if [ "$service_type" = "systemd" ]; then
            if check_systemd_status "$service"; then
                print_success "Service is currently running"
                if [ "$VERBOSE" = true ]; then
                    local uptime
                    uptime=$(get_systemd_uptime "$service")
                    print_info "Service active since: $uptime"
                fi
            else
                print_warning "Service is not currently active"
            fi
        else
            if check_docker_status "$service"; then
                print_success "Container is currently running"
            else
                print_warning "Container is not currently healthy"
            fi
        fi
    fi

    # Backup configs if requested
    local backup_dir=""
    if [ "$BACKUP_CONFIG" = true ]; then
        backup_dir=$(backup_configs)
    fi

    # Perform restart
    local restart_success=false
    if [ "$service_type" = "systemd" ]; then
        if restart_systemd_service "$service"; then
            restart_success=true
        fi
    else
        if restart_docker_container "$service"; then
            restart_success=true
        fi
    fi

    if [ "$restart_success" = false ]; then
        print_error "Restart command failed"
        exit 1
    fi

    # Post-restart validation
    if [ "$POST_CHECK" = true ]; then
        if wait_and_validate "$service" "$service_type"; then
            print_success "Service restart completed successfully!"
            if [ -n "$backup_dir" ]; then
                print_info "Config backup available at: $backup_dir"
            fi
            return 0
        else
            print_error "Service restart failed validation"
            perform_rollback "$service" "$service_type"
            exit 1
        fi
    else
        print_success "Service restart completed (validation skipped)"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --type)
            SERVICE_TYPE="$2"
            if [[ ! "$SERVICE_TYPE" =~ ^(systemd|docker)$ ]]; then
                print_error "Invalid service type. Must be 'systemd' or 'docker'"
                exit 1
            fi
            shift 2
            ;;
        --wait)
            WAIT_TIME="$2"
            shift 2
            ;;
        --retries)
            MAX_RETRIES="$2"
            shift 2
            ;;
        --no-pre-check)
            PRE_CHECK=false
            shift
            ;;
        --no-post-check)
            POST_CHECK=false
            shift
            ;;
        --no-rollback)
            ROLLBACK_ON_FAILURE=false
            shift
            ;;
        --backup-config)
            BACKUP_CONFIG=true
            CONFIG_FILES="$2"
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
    print_info "Safe Service Restart Helper"
    echo

    # Validate service name provided
    if [ -z "$SERVICE_NAME" ]; then
        print_error "Service name is required"
        echo
        show_help
        exit 1
    fi

    # Check if we need sudo for systemd
    if [ "$SERVICE_TYPE" = "systemd" ] && [ "$EUID" -ne 0 ]; then
        print_error "Systemd service restart requires sudo/root privileges"
        print_info "Try: sudo $0 --service $SERVICE_NAME $*"
        exit 1
    fi

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - No changes will be made"
        echo
    fi

    # Perform safe restart
    safe_restart "$SERVICE_NAME" "$SERVICE_TYPE"
}

main

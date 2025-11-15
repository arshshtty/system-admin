#!/usr/bin/env bash

#############################################################################
# docker-cleanup.sh
#
# Intelligent Docker cleanup automation
# Safely removes unused containers, images, volumes, and networks
# Shows disk space saved and supports dry-run mode
#
# Usage:
#   ./docker-cleanup.sh [options]
#
# Options:
#   --all               Clean everything (containers, images, volumes, networks)
#   --containers        Clean only stopped containers
#   --images            Clean only unused images
#   --volumes           Clean only unused volumes
#   --networks          Clean only unused networks
#   --dangling          Clean only dangling images
#   --dry-run           Show what would be cleaned without doing it
#   --force             Skip confirmation prompts
#   --keep-days N       Keep images/containers from last N days (default: 7)
#   --schedule          Set up automatic cleanup (cron)
#   --help              Show this help message
#
#############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DRY_RUN=false
FORCE=false
CLEAN_ALL=false
CLEAN_CONTAINERS=false
CLEAN_IMAGES=false
CLEAN_VOLUMES=false
CLEAN_NETWORKS=false
CLEAN_DANGLING=false
SCHEDULE_MODE=false
KEEP_DAYS=7

#############################################################################
# Helper Functions
#############################################################################

log() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $*"
}

log_stat() {
    echo -e "${CYAN}[STAT]${NC} $*"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_docker() {
    if ! command_exists docker; then
        log_error "Docker not found. Please install Docker first."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        log_error "Cannot connect to Docker daemon. Is it running?"
        exit 1
    fi
}

human_readable_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}")KB"
    else
        echo "${bytes}B"
    fi
}

get_docker_disk_usage() {
    docker system df 2>/dev/null || true
}

confirm() {
    if [ "$FORCE" = true ]; then
        return 0
    fi

    read -p "$(echo -e "${YELLOW}Continue? [y/N]${NC} ")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Cancelled by user"
        return 1
    fi
    return 0
}

#############################################################################
# Cleanup Functions
#############################################################################

show_current_usage() {
    log "Current Docker disk usage:"
    echo ""
    get_docker_disk_usage
    echo ""
}

cleanup_containers() {
    log "Cleaning up stopped containers..."

    local count=$(docker ps -aq -f status=exited -f status=created | wc -l)

    if [ "$count" -eq 0 ]; then
        log_success "No stopped containers to clean"
        return 0
    fi

    log_stat "Found $count stopped container(s)"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would remove the following containers:"
        docker ps -a -f status=exited -f status=created --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"
        return 0
    fi

    echo ""
    docker ps -a -f status=exited -f status=created --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"
    echo ""

    if ! confirm; then
        return 0
    fi

    docker container prune -f
    log_success "Removed $count stopped container(s)"
}

cleanup_images() {
    log "Cleaning up unused images..."

    # Get unused images (not associated with any container)
    local count=$(docker images -f dangling=false -q | wc -l)

    if [ "$count" -eq 0 ]; then
        log_success "No unused images to clean"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would remove unused images"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"
        return 0
    fi

    log_stat "Checking for unused images..."
    echo ""

    if ! confirm; then
        return 0
    fi

    docker image prune -a -f --filter "until=${KEEP_DAYS}d"
    log_success "Cleaned up unused images (kept images from last $KEEP_DAYS days)"
}

cleanup_dangling_images() {
    log "Cleaning up dangling images..."

    local count=$(docker images -f dangling=true -q | wc -l)

    if [ "$count" -eq 0 ]; then
        log_success "No dangling images to clean"
        return 0
    fi

    log_stat "Found $count dangling image(s)"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would remove the following dangling images:"
        docker images -f dangling=true
        return 0
    fi

    echo ""
    docker images -f dangling=true
    echo ""

    if ! confirm; then
        return 0
    fi

    docker image prune -f
    log_success "Removed $count dangling image(s)"
}

cleanup_volumes() {
    log "Cleaning up unused volumes..."

    local count=$(docker volume ls -q -f dangling=true | wc -l)

    if [ "$count" -eq 0 ]; then
        log_success "No unused volumes to clean"
        return 0
    fi

    log_warn "Found $count unused volume(s)"
    log_warn "⚠️  WARNING: This will permanently delete data in unused volumes!"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would remove the following volumes:"
        docker volume ls -f dangling=true
        return 0
    fi

    echo ""
    docker volume ls -f dangling=true
    echo ""

    if ! confirm; then
        return 0
    fi

    docker volume prune -f
    log_success "Removed $count unused volume(s)"
}

cleanup_networks() {
    log "Cleaning up unused networks..."

    # Count unused networks (excluding default networks)
    local count=$(docker network ls --filter "type=custom" -q | wc -l)

    if [ "$count" -eq 0 ]; then
        log_success "No unused networks to clean"
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would remove unused networks"
        docker network ls --filter "type=custom"
        return 0
    fi

    log_stat "Checking for unused networks..."
    echo ""

    if ! confirm; then
        return 0
    fi

    docker network prune -f
    log_success "Cleaned up unused networks"
}

cleanup_build_cache() {
    log "Cleaning up build cache..."

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would clean build cache"
        docker buildx du 2>/dev/null || docker builder df 2>/dev/null || true
        return 0
    fi

    if ! confirm; then
        return 0
    fi

    docker builder prune -f
    log_success "Cleaned up build cache"
}

cleanup_all() {
    log "========================================="
    log "Docker Cleanup - Full System Clean"
    log "========================================="

    show_current_usage

    # Store initial size
    local before_size=$(docker system df -v | awk '/Total.*Reclaimable/ {print $4}' | tr -d 'B' | head -1)

    # Run all cleanup operations
    cleanup_containers
    echo ""
    cleanup_dangling_images
    echo ""
    cleanup_images
    echo ""
    cleanup_volumes
    echo ""
    cleanup_networks
    echo ""
    cleanup_build_cache

    echo ""
    log "========================================="
    log "Cleanup Summary"
    log "========================================="
    show_current_usage

    log_success "Docker cleanup completed!"
}

#############################################################################
# Scheduling
#############################################################################

setup_schedule() {
    log "Setting up automatic Docker cleanup..."

    local script_path="$(readlink -f "$0")"
    local cron_schedule="${1:-0 3 * * 0}"  # Default: Every Sunday at 3 AM

    log "Script path: $script_path"
    log "Schedule: $cron_schedule"

    # Check if crontab exists
    if ! command_exists crontab; then
        log_error "crontab not found. Please install cron."
        exit 1
    fi

    # Create cron job
    local cron_entry="$cron_schedule $script_path --all --force >> /var/log/docker-cleanup.log 2>&1"

    # Check if entry already exists
    if crontab -l 2>/dev/null | grep -q "$script_path"; then
        log_warn "Cron job already exists"
        crontab -l | grep "$script_path"
        return 0
    fi

    # Add to crontab
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -

    log_success "Scheduled automatic cleanup: $cron_schedule"
    log "To view: crontab -l"
    log "To remove: crontab -e (and delete the line)"
}

#############################################################################
# Statistics & Reporting
#############################################################################

show_statistics() {
    log "========================================="
    log "Docker Resource Statistics"
    log "========================================="
    echo ""

    # Containers
    local total_containers=$(docker ps -aq | wc -l)
    local running_containers=$(docker ps -q | wc -l)
    local stopped_containers=$(docker ps -aq -f status=exited -f status=created | wc -l)

    log_stat "Containers:"
    log_stat "  Total: $total_containers"
    log_stat "  Running: $running_containers"
    log_stat "  Stopped: $stopped_containers"
    echo ""

    # Images
    local total_images=$(docker images -q | wc -l)
    local dangling_images=$(docker images -f dangling=true -q | wc -l)

    log_stat "Images:"
    log_stat "  Total: $total_images"
    log_stat "  Dangling: $dangling_images"
    echo ""

    # Volumes
    local total_volumes=$(docker volume ls -q | wc -l)
    local unused_volumes=$(docker volume ls -q -f dangling=true | wc -l)

    log_stat "Volumes:"
    log_stat "  Total: $total_volumes"
    log_stat "  Unused: $unused_volumes"
    echo ""

    # Networks
    local total_networks=$(docker network ls -q | wc -l)

    log_stat "Networks: $total_networks"
    echo ""

    # Disk usage
    log_stat "Disk Usage:"
    get_docker_disk_usage
    echo ""

    log "========================================="
}

show_help() {
    grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# \?//'
    exit 0
}

#############################################################################
# Main
#############################################################################

main() {
    # Check for Docker
    check_docker

    # Parse arguments
    if [ $# -eq 0 ]; then
        show_statistics
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                CLEAN_ALL=true
                shift
                ;;
            --containers)
                CLEAN_CONTAINERS=true
                shift
                ;;
            --images)
                CLEAN_IMAGES=true
                shift
                ;;
            --volumes)
                CLEAN_VOLUMES=true
                shift
                ;;
            --networks)
                CLEAN_NETWORKS=true
                shift
                ;;
            --dangling)
                CLEAN_DANGLING=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --keep-days)
                KEEP_DAYS="$2"
                shift 2
                ;;
            --schedule)
                SCHEDULE_MODE=true
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                ;;
        esac
    done

    # Handle schedule mode
    if [ "$SCHEDULE_MODE" = true ]; then
        setup_schedule
        exit 0
    fi

    # Execute cleanup
    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN MODE - No changes will be made"
        echo ""
    fi

    if [ "$CLEAN_ALL" = true ]; then
        cleanup_all
    else
        [ "$CLEAN_CONTAINERS" = true ] && cleanup_containers && echo ""
        [ "$CLEAN_DANGLING" = true ] && cleanup_dangling_images && echo ""
        [ "$CLEAN_IMAGES" = true ] && cleanup_images && echo ""
        [ "$CLEAN_VOLUMES" = true ] && cleanup_volumes && echo ""
        [ "$CLEAN_NETWORKS" = true ] && cleanup_networks && echo ""
    fi
}

main "$@"

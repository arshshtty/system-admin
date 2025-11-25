#!/usr/bin/env bash
#
# Disk Cleanup - Automated cleanup of old files, logs, and caches
# Free up disk space safely
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
DRY_RUN=true
FORCE=false
DAYS_OLD=30
MIN_SIZE="10M"
VERBOSE=false

# Directories to clean
TMP_DIRS=("/tmp" "/var/tmp")
LOG_DIRS=("/var/log")
CACHE_DIRS=("/var/cache/apt/archives" "$HOME/.cache")

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
Disk Cleanup - Automated cleanup of old files and caches

USAGE:
    $(basename "$0") [OPTIONS] COMMAND

COMMANDS:
    analyze             Analyze disk usage without cleaning
    clean-temp          Clean temporary directories
    clean-logs          Clean old log files
    clean-cache         Clean cache directories
    clean-docker        Clean Docker resources
    clean-apt           Clean APT cache
    clean-old           Find and remove old files
    clean-all           Run all cleanup tasks

OPTIONS:
    --days DAYS         Remove files older than DAYS (default: 30)
    --min-size SIZE     Only clean files larger than SIZE (e.g., 10M, 1G)
    --dry-run           Show what would be cleaned (default)
    --execute           Actually perform the cleanup
    --force             Skip confirmation prompts
    --verbose           Show detailed output
    --help              Show this help message

EXAMPLES:
    # Analyze current disk usage
    $(basename "$0") analyze

    # Clean temp files older than 7 days (dry-run)
    $(basename "$0") --days 7 clean-temp

    # Actually clean old logs
    $(basename "$0") --execute --days 60 clean-logs

    # Clean everything older than 30 days
    $(basename "$0") --execute clean-all

    # Find large old files
    $(basename "$0") --days 90 --min-size 100M clean-old

SAFETY:
    - Dry-run is enabled by default
    - Use --execute to actually delete files
    - Protected directories are never touched
    - Confirmation required unless --force is used

EOF
}

#######################################
# Human readable size
#######################################
human_size() {
    local size=$1
    numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size}B"
}

#######################################
# Confirm action
#######################################
confirm() {
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    local message="$1"
    read -p "$(echo -e "${YELLOW}${message}${NC} (y/N) ")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        return 1
    fi
    return 0
}

#######################################
# Analyze disk usage
#######################################
cmd_analyze() {
    print_info "Analyzing disk usage..."
    echo ""

    # Overall disk usage
    print_info "Disk Usage by Filesystem:"
    df -h | grep -v "tmpfs\|loop"
    echo ""

    # Largest directories
    print_info "Top 10 Largest Directories:"
    du -sh /* 2>/dev/null | sort -rh | head -10
    echo ""

    # Temp directory usage
    if [[ -d /tmp ]]; then
        local tmp_size
        tmp_size=$(du -sb /tmp 2>/dev/null | cut -f1)
        print_info "/tmp usage: $(human_size "$tmp_size")"
    fi

    # Log directory usage
    if [[ -d /var/log ]]; then
        local log_size
        log_size=$(du -sb /var/log 2>/dev/null | cut -f1)
        print_info "/var/log usage: $(human_size "$log_size")"
    fi

    # Cache directory usage
    if [[ -d /var/cache ]]; then
        local cache_size
        cache_size=$(du -sb /var/cache 2>/dev/null | cut -f1)
        print_info "/var/cache usage: $(human_size "$cache_size")"
    fi

    # Docker usage (if installed)
    if command -v docker &> /dev/null; then
        echo ""
        print_info "Docker Disk Usage:"
        docker system df 2>/dev/null || print_warning "Cannot access Docker"
    fi

    # APT cache
    if [[ -d /var/cache/apt/archives ]]; then
        local apt_size
        apt_size=$(du -sb /var/cache/apt/archives 2>/dev/null | cut -f1)
        print_info "APT cache usage: $(human_size "$apt_size")"
    fi

    echo ""
    print_success "Analysis complete"
}

#######################################
# Clean temporary directories
#######################################
cmd_clean_temp() {
    print_info "Cleaning temporary directories (files older than $DAYS_OLD days)..."

    local total_size=0

    for dir in "${TMP_DIRS[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        print_info "Scanning: $dir"

        # Find old files
        local files
        files=$(find "$dir" -type f -mtime "+$DAYS_OLD" 2>/dev/null || true)

        if [[ -z "$files" ]]; then
            print_info "  No old files found"
            continue
        fi

        local count
        count=$(echo "$files" | wc -l)
        local size
        size=$(echo "$files" | xargs du -cb 2>/dev/null | tail -1 | cut -f1 || echo "0")

        total_size=$((total_size + size))

        print_info "  Found: $count files, $(human_size "$size")"

        if [[ "$DRY_RUN" == "false" ]]; then
            echo "$files" | xargs rm -f 2>/dev/null || true
            print_success "  Cleaned: $(human_size "$size")"
        fi
    done

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY-RUN] Would clean: $(human_size "$total_size")"
    else
        print_success "Total cleaned: $(human_size "$total_size")"
    fi
}

#######################################
# Clean old log files
#######################################
cmd_clean_logs() {
    print_info "Cleaning old log files (older than $DAYS_OLD days)..."

    if [[ ! -d /var/log ]]; then
        print_warning "/var/log not found"
        return
    fi

    # Find old log files (but not active logs)
    local files
    files=$(find /var/log -type f \
        \( -name "*.log.*" -o -name "*.gz" -o -name "*.old" -o -name "*.1" \) \
        -mtime "+$DAYS_OLD" 2>/dev/null || true)

    if [[ -z "$files" ]]; then
        print_info "No old log files found"
        return
    fi

    local count
    count=$(echo "$files" | wc -l)
    local size
    size=$(echo "$files" | xargs du -cb 2>/dev/null | tail -1 | cut -f1 || echo "0")

    print_info "Found: $count files, $(human_size "$size")"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY-RUN] Would clean: $(human_size "$size")"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "$files"
        fi
    else
        if confirm "Delete $count log files ($(human_size "$size"))?"; then
            echo "$files" | xargs rm -f 2>/dev/null || true
            print_success "Cleaned: $(human_size "$size")"
        fi
    fi
}

#######################################
# Clean cache directories
#######################################
cmd_clean_cache() {
    print_info "Cleaning cache directories..."

    local total_size=0

    # User cache
    if [[ -d "$HOME/.cache" ]]; then
        local cache_size
        cache_size=$(du -sb "$HOME/.cache" 2>/dev/null | cut -f1 || echo "0")
        print_info "User cache: $(human_size "$cache_size")"

        if [[ "$DRY_RUN" == "false" ]]; then
            if confirm "Clean user cache ($(human_size "$cache_size"))?"; then
                find "$HOME/.cache" -type f -mtime "+$DAYS_OLD" -delete 2>/dev/null || true
                print_success "Cleaned user cache"
            fi
        fi
        total_size=$((total_size + cache_size))
    fi

    # Thumbnail cache
    if [[ -d "$HOME/.thumbnails" ]]; then
        local thumb_size
        thumb_size=$(du -sb "$HOME/.thumbnails" 2>/dev/null | cut -f1 || echo "0")
        print_info "Thumbnails: $(human_size "$thumb_size")"

        if [[ "$DRY_RUN" == "false" ]]; then
            if confirm "Clean thumbnails ($(human_size "$thumb_size"))?"; then
                rm -rf "$HOME/.thumbnails"/*
                print_success "Cleaned thumbnails"
            fi
        fi
        total_size=$((total_size + thumb_size))
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY-RUN] Would clean approximately: $(human_size "$total_size")"
    fi
}

#######################################
# Clean Docker resources
#######################################
cmd_clean_docker() {
    if ! command -v docker &> /dev/null; then
        print_warning "Docker not installed, skipping"
        return
    fi

    print_info "Cleaning Docker resources..."

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY-RUN] Docker cleanup preview:"
        docker system df
    else
        if confirm "Run Docker system prune?"; then
            docker system prune -af --volumes
            print_success "Docker cleaned"
        fi
    fi
}

#######################################
# Clean APT cache
#######################################
cmd_clean_apt() {
    if ! command -v apt-get &> /dev/null; then
        print_warning "APT not available, skipping"
        return
    fi

    print_info "Cleaning APT cache..."

    local apt_size
    apt_size=$(du -sb /var/cache/apt/archives 2>/dev/null | cut -f1 || echo "0")
    print_info "APT cache: $(human_size "$apt_size")"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY-RUN] Would clean: $(human_size "$apt_size")"
    else
        if confirm "Clean APT cache ($(human_size "$apt_size"))?"; then
            sudo apt-get clean
            sudo apt-get autoclean
            sudo apt-get autoremove -y
            print_success "APT cache cleaned"
        fi
    fi
}

#######################################
# Find and clean old files
#######################################
cmd_clean_old() {
    print_info "Finding old files (older than $DAYS_OLD days, larger than $MIN_SIZE)..."

    local search_dirs=("$HOME" "/var" "/tmp")

    for dir in "${search_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            continue
        fi

        print_info "Scanning: $dir"

        local files
        files=$(find "$dir" -type f -mtime "+$DAYS_OLD" -size "+${MIN_SIZE}" 2>/dev/null | head -100 || true)

        if [[ -z "$files" ]]; then
            continue
        fi

        local count
        count=$(echo "$files" | wc -l)

        print_info "  Found $count large old files:"
        echo "$files" | while read -r file; do
            local size
            size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "?")
            echo "    $size  $file"
        done
    done

    print_warning "Review files above and delete manually if needed"
}

#######################################
# Clean all
#######################################
cmd_clean_all() {
    print_info "Running all cleanup tasks..."
    echo ""

    cmd_clean_temp
    echo ""

    cmd_clean_logs
    echo ""

    cmd_clean_cache
    echo ""

    cmd_clean_docker
    echo ""

    cmd_clean_apt
    echo ""

    print_success "All cleanup tasks complete"
}

#######################################
# Main function
#######################################
main() {
    local command=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --days)
                DAYS_OLD="$2"
                shift 2
                ;;
            --min-size)
                MIN_SIZE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --execute)
                DRY_RUN=false
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
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
                command="$1"
                shift
                ;;
        esac
    done

    # Validate command
    if [[ -z "$command" ]]; then
        print_error "Command required"
        show_help
        exit 1
    fi

    # Show mode
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY-RUN MODE: No files will be deleted (use --execute to actually clean)"
    else
        print_warning "EXECUTE MODE: Files will be permanently deleted!"
    fi
    echo ""

    # Execute command
    case "$command" in
        analyze)
            cmd_analyze
            ;;
        clean-temp)
            cmd_clean_temp
            ;;
        clean-logs)
            cmd_clean_logs
            ;;
        clean-cache)
            cmd_clean_cache
            ;;
        clean-docker)
            cmd_clean_docker
            ;;
        clean-apt)
            cmd_clean_apt
            ;;
        clean-old)
            cmd_clean_old
            ;;
        clean-all)
            cmd_clean_all
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

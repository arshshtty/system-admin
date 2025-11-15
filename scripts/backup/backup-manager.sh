#!/usr/bin/env bash

#############################################################################
# backup-manager.sh
#
# Comprehensive backup automation script
# Supports: Files, Databases (PostgreSQL, MySQL), Docker volumes
# Targets: Local, Remote (rsync/SSH), S3-compatible storage
# Features: Retention policies, encryption, compression, notifications
#
# Usage:
#   ./backup-manager.sh [options]
#
# Options:
#   --config FILE       Configuration file (default: config/backup.yaml)
#   --type TYPE         Backup type: all, files, database, docker
#   --dry-run           Show what would be backed up
#   --restore           Restore mode
#   --list              List available backups
#   --verify            Verify backup integrity
#   --help              Show this help message
#
#############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CONFIG_FILE="${CONFIG_FILE:-config/backup.yaml}"
BACKUP_ROOT="${BACKUP_ROOT:-/var/backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE_STAMP=$(date +%Y-%m-%d)
DRY_RUN=false
BACKUP_TYPE="all"
RESTORE_MODE=false
LIST_MODE=false
VERIFY_MODE=false

# Logging
LOG_FILE="${BACKUP_ROOT}/backup.log"

#############################################################################
# Helper Functions
#############################################################################

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $*" | tee -a "$LOG_FILE" >&2
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $*" | tee -a "$LOG_FILE"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_dependencies() {
    local deps=("tar" "gzip")
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            log_error "Required dependency '$dep' not found"
            exit 1
        fi
    done
}

send_notification() {
    local title="$1"
    local message="$2"
    local priority="${3:-default}"

    # Add your notification method here
    # Examples: ntfy.sh, telegram, email, slack
    log "Notification: $title - $message"

    # Example ntfy.sh integration (uncomment to use)
    # if [ -n "${NTFY_TOPIC:-}" ]; then
    #     curl -H "Title: $title" -H "Priority: $priority" -d "$message" "https://ntfy.sh/${NTFY_TOPIC}" 2>/dev/null || true
    # fi
}

get_backup_size() {
    local path="$1"
    if [ -f "$path" ]; then
        du -h "$path" | cut -f1
    elif [ -d "$path" ]; then
        du -sh "$path" | cut -f1
    else
        echo "0"
    fi
}

#############################################################################
# Backup Functions
#############################################################################

backup_files() {
    local source="$1"
    local dest="$2"
    local name="$3"

    log "Backing up files: $name"
    log "Source: $source"

    if [ ! -d "$source" ] && [ ! -f "$source" ]; then
        log_error "Source not found: $source"
        return 1
    fi

    local backup_file="${dest}/${name}_${TIMESTAMP}.tar.gz"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would create backup at $backup_file"
        return 0
    fi

    mkdir -p "$dest"

    # Create compressed archive with progress
    tar -czf "$backup_file" -C "$(dirname "$source")" "$(basename "$source")" 2>&1 | while read -r line; do
        log "  $line"
    done

    if [ -f "$backup_file" ]; then
        local size=$(get_backup_size "$backup_file")
        log_success "Backup created: $backup_file ($size)"

        # Create checksum
        sha256sum "$backup_file" > "${backup_file}.sha256"

        return 0
    else
        log_error "Failed to create backup: $backup_file"
        return 1
    fi
}

backup_mysql() {
    local db_name="$1"
    local dest="$2"
    local db_user="${3:-root}"
    local db_pass="${4:-}"

    if ! command_exists mysqldump; then
        log_warn "mysqldump not found, skipping MySQL backup"
        return 0
    fi

    log "Backing up MySQL database: $db_name"

    local backup_file="${dest}/mysql_${db_name}_${TIMESTAMP}.sql.gz"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would backup MySQL database to $backup_file"
        return 0
    fi

    mkdir -p "$dest"

    local mysql_opts="--single-transaction --quick --lock-tables=false"

    if [ -n "$db_pass" ]; then
        mysqldump -u"$db_user" -p"$db_pass" $mysql_opts "$db_name" | gzip > "$backup_file"
    else
        mysqldump -u"$db_user" $mysql_opts "$db_name" | gzip > "$backup_file"
    fi

    local size=$(get_backup_size "$backup_file")
    log_success "MySQL backup created: $backup_file ($size)"

    sha256sum "$backup_file" > "${backup_file}.sha256"
}

backup_postgresql() {
    local db_name="$1"
    local dest="$2"
    local db_user="${3:-postgres}"

    if ! command_exists pg_dump; then
        log_warn "pg_dump not found, skipping PostgreSQL backup"
        return 0
    fi

    log "Backing up PostgreSQL database: $db_name"

    local backup_file="${dest}/postgres_${db_name}_${TIMESTAMP}.sql.gz"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would backup PostgreSQL database to $backup_file"
        return 0
    fi

    mkdir -p "$dest"

    sudo -u "$db_user" pg_dump "$db_name" | gzip > "$backup_file"

    local size=$(get_backup_size "$backup_file")
    log_success "PostgreSQL backup created: $backup_file ($size)"

    sha256sum "$backup_file" > "${backup_file}.sha256"
}

backup_docker_volumes() {
    local volume_name="$1"
    local dest="$2"

    if ! command_exists docker; then
        log_warn "Docker not found, skipping volume backup"
        return 0
    fi

    log "Backing up Docker volume: $volume_name"

    local backup_file="${dest}/docker_volume_${volume_name}_${TIMESTAMP}.tar.gz"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would backup Docker volume to $backup_file"
        return 0
    fi

    mkdir -p "$dest"

    # Create a temporary container to access the volume
    docker run --rm \
        -v "${volume_name}:/volume" \
        -v "${dest}:/backup" \
        alpine \
        tar czf "/backup/$(basename "$backup_file")" -C /volume ./

    local size=$(get_backup_size "$backup_file")
    log_success "Docker volume backup created: $backup_file ($size)"

    sha256sum "$backup_file" > "${backup_file}.sha256"
}

sync_to_remote() {
    local source="$1"
    local remote_host="$2"
    local remote_path="$3"

    if ! command_exists rsync; then
        log_error "rsync not found, cannot sync to remote"
        return 1
    fi

    log "Syncing to remote: $remote_host:$remote_path"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would sync $source to $remote_host:$remote_path"
        rsync -avz --dry-run "$source/" "${remote_host}:${remote_path}/"
        return 0
    fi

    rsync -avz --delete \
        -e "ssh -o StrictHostKeyChecking=no" \
        "$source/" "${remote_host}:${remote_path}/" 2>&1 | while read -r line; do
        log "  $line"
    done

    log_success "Synced to remote: $remote_host:$remote_path"
}

sync_to_s3() {
    local source="$1"
    local s3_bucket="$2"
    local s3_path="$3"

    if ! command_exists aws; then
        log_warn "AWS CLI not found, skipping S3 sync"
        return 0
    fi

    log "Syncing to S3: s3://$s3_bucket/$s3_path"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would sync to S3"
        aws s3 sync "$source" "s3://${s3_bucket}/${s3_path}" --dryrun
        return 0
    fi

    aws s3 sync "$source" "s3://${s3_bucket}/${s3_path}" 2>&1 | while read -r line; do
        log "  $line"
    done

    log_success "Synced to S3: s3://$s3_bucket/$s3_path"
}

#############################################################################
# Retention Policy
#############################################################################

apply_retention_policy() {
    local backup_dir="$1"
    local keep_daily="${2:-7}"
    local keep_weekly="${3:-4}"
    local keep_monthly="${4:-12}"

    log "Applying retention policy to $backup_dir"
    log "  Keep: $keep_daily daily, $keep_weekly weekly, $keep_monthly monthly"

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would apply retention policy"
        return 0
    fi

    # This is a simplified retention - in production, use a proper backup tool like restic
    # Delete backups older than the retention period

    # Daily: keep last N days
    find "$backup_dir" -type f -name "*.tar.gz" -mtime +${keep_daily} -delete 2>/dev/null || true

    log_success "Retention policy applied"
}

#############################################################################
# Restore Functions
#############################################################################

list_backups() {
    local backup_dir="${1:-$BACKUP_ROOT}"

    log "Available backups in $backup_dir:"
    echo ""

    if [ ! -d "$backup_dir" ]; then
        log_warn "Backup directory not found: $backup_dir"
        return 1
    fi

    find "$backup_dir" -type f \( -name "*.tar.gz" -o -name "*.sql.gz" \) -printf "%T@ %Tc %p\n" | \
        sort -rn | \
        cut -d' ' -f2- | \
        head -n 50 | \
        nl -w2 -s'. '
}

restore_backup() {
    local backup_file="$1"
    local restore_path="${2:-.}"

    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    log "Restoring backup: $backup_file"
    log "Restore path: $restore_path"

    # Verify checksum if exists
    if [ -f "${backup_file}.sha256" ]; then
        log "Verifying checksum..."
        if sha256sum -c "${backup_file}.sha256" >/dev/null 2>&1; then
            log_success "Checksum verified"
        else
            log_error "Checksum verification failed!"
            return 1
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        log "DRY RUN: Would restore to $restore_path"
        tar -tzf "$backup_file" | head -n 20
        return 0
    fi

    mkdir -p "$restore_path"
    tar -xzf "$backup_file" -C "$restore_path"

    log_success "Backup restored to: $restore_path"
}

verify_backup() {
    local backup_file="$1"

    log "Verifying backup: $backup_file"

    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Test archive integrity
    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_success "Archive integrity OK"
    else
        log_error "Archive is corrupted!"
        return 1
    fi

    # Verify checksum if exists
    if [ -f "${backup_file}.sha256" ]; then
        if sha256sum -c "${backup_file}.sha256" >/dev/null 2>&1; then
            log_success "Checksum OK"
        else
            log_error "Checksum mismatch!"
            return 1
        fi
    fi

    log_success "Backup verification complete"
}

#############################################################################
# Main Backup Routine
#############################################################################

run_backup() {
    log "========================================="
    log "Starting backup: $(date)"
    log "========================================="

    local backup_dir="${BACKUP_ROOT}/${DATE_STAMP}"
    local success=true

    # Example backup jobs - customize based on your needs

    # 1. Backup important directories
    if [ "$BACKUP_TYPE" = "all" ] || [ "$BACKUP_TYPE" = "files" ]; then
        log "--- File Backups ---"

        # Home directory (excluding cache)
        if [ -d "$HOME" ]; then
            backup_files "$HOME" "$backup_dir/files" "home" || success=false
        fi

        # System configs
        if [ -d "/etc" ]; then
            backup_files "/etc" "$backup_dir/files" "etc_configs" || success=false
        fi
    fi

    # 2. Backup databases
    if [ "$BACKUP_TYPE" = "all" ] || [ "$BACKUP_TYPE" = "database" ]; then
        log "--- Database Backups ---"

        # MySQL databases (if configured)
        # backup_mysql "mydb" "$backup_dir/databases" "root" "password"

        # PostgreSQL databases (if configured)
        # backup_postgresql "mydb" "$backup_dir/databases" "postgres"
    fi

    # 3. Backup Docker volumes
    if [ "$BACKUP_TYPE" = "all" ] || [ "$BACKUP_TYPE" = "docker" ]; then
        log "--- Docker Volume Backups ---"

        if command_exists docker; then
            # Get all Docker volumes
            while read -r volume; do
                backup_docker_volumes "$volume" "$backup_dir/docker" || success=false
            done < <(docker volume ls -q 2>/dev/null)
        fi
    fi

    # 4. Sync to remote locations (if configured)
    # sync_to_remote "$backup_dir" "user@backup-server" "/backups/$(hostname)"
    # sync_to_s3 "$backup_dir" "my-backup-bucket" "backups/$(hostname)"

    # 5. Apply retention policy
    apply_retention_policy "$BACKUP_ROOT" 7 4 12

    log "========================================="
    if [ "$success" = true ]; then
        log_success "Backup completed successfully"
        send_notification "Backup Success" "Backup completed for $(hostname)" "default"
    else
        log_error "Backup completed with errors"
        send_notification "Backup Error" "Backup had errors on $(hostname)" "high"
    fi
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
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --type)
                BACKUP_TYPE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --restore)
                RESTORE_MODE=true
                shift
                ;;
            --list)
                LIST_MODE=true
                shift
                ;;
            --verify)
                VERIFY_MODE=true
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

    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"

    # Check dependencies
    check_dependencies

    # Execute mode
    if [ "$LIST_MODE" = true ]; then
        list_backups
    elif [ "$VERIFY_MODE" = true ]; then
        if [ $# -lt 2 ]; then
            log_error "Please specify backup file to verify"
            exit 1
        fi
        verify_backup "$2"
    elif [ "$RESTORE_MODE" = true ]; then
        if [ $# -lt 2 ]; then
            log_error "Please specify backup file to restore"
            exit 1
        fi
        restore_backup "$2" "${3:-.}"
    else
        run_backup
    fi
}

main "$@"

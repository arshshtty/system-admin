#!/usr/bin/env bash
#
# Dotfiles Synchronizer
# Keep dotfiles in sync across multiple servers
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DOTFILES_DIR="${DOTFILES_DIR:-$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")/dotfiles}"
SERVERS=""
SSH_USER="${USER}"
SSH_PORT=22
DIRECTION="push"  # push or pull
BACKUP=true
DRY_RUN=false
VERBOSE=false
INVENTORY_FILE=""

# Dotfiles to sync
DOTFILES=(
    ".zshrc"
    ".vimrc"
    ".gitconfig"
    ".tmux.conf"
)

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
Dotfiles Synchronizer

Keep dotfiles in sync across multiple servers.

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --servers SERVERS       Comma-separated list of servers (user@host or IP)
                           Example: admin@server1,root@192.168.1.10
    --inventory FILE        Use servers from inventory YAML file
    --direction DIR         Sync direction: push or pull (default: push)
                           push: Local -> Remote servers
                           pull: Remote -> Local (from first server)
    --dotfiles-dir DIR      Local dotfiles directory (default: ./dotfiles)
    --ssh-user USER         SSH username (default: current user)
    --ssh-port PORT         SSH port (default: 22)
    --files FILES           Comma-separated list of dotfiles to sync
                           (default: .zshrc,.vimrc,.gitconfig,.tmux.conf)
    --no-backup             Don't backup existing files before sync
    --dry-run               Show what would be synced without doing it
    --verbose               Show detailed output
    --help                  Show this help message

EXAMPLES:
    # Push dotfiles to multiple servers
    $(basename "$0") --servers admin@server1,admin@server2 --direction push

    # Pull dotfiles from a server
    $(basename "$0") --servers admin@server1 --direction pull

    # Sync using inventory file
    $(basename "$0") --inventory inventory/servers.yaml --direction push

    # Sync specific dotfiles only
    $(basename "$0") --servers admin@server1 --files .vimrc,.tmux.conf

    # Dry run to see what would be synced
    $(basename "$0") --servers admin@server1 --dry-run

FEATURES:
    - Automatic backup of existing files
    - Support for multiple servers simultaneously
    - Pull from or push to servers
    - Dry-run mode for safety
    - Inventory file integration

NOTES:
    - SSH key-based authentication must be configured
    - Dotfiles are synced to user's home directory
    - Existing .local files are preserved
EOF
}

# Function to check if dotfiles directory exists
check_dotfiles_dir() {
    if [ ! -d "$DOTFILES_DIR" ]; then
        print_error "Dotfiles directory not found: $DOTFILES_DIR"
        exit 1
    fi

    if [ "$VERBOSE" = true ]; then
        print_info "Using dotfiles directory: $DOTFILES_DIR"
    fi
}

# Function to parse inventory file
parse_inventory() {
    local inventory=$1

    if [ ! -f "$inventory" ]; then
        print_error "Inventory file not found: $inventory"
        exit 1
    fi

    # Extract server IPs and users from YAML
    local servers_list=""

    # Simple YAML parsing (works for the inventory format)
    while IFS= read -r line; do
        if echo "$line" | grep -q "ip:"; then
            local ip
            ip=$(echo "$line" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')

            # Try to find corresponding ssh_user
            local user="$SSH_USER"

            if [ -n "$ip" ]; then
                servers_list="${servers_list}${user}@${ip},"
            fi
        fi
    done < "$inventory"

    # Remove trailing comma
    servers_list="${servers_list%,}"

    echo "$servers_list"
}

# Function to test SSH connectivity
test_ssh_connection() {
    local server=$1

    if timeout 5 ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p "$SSH_PORT" "$server" "echo ok" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to backup remote file
backup_remote_file() {
    local server=$1
    local file=$2

    local backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"

    if ssh -p "$SSH_PORT" "$server" "[ -f \"$file\" ]" 2>/dev/null; then
        if [ "$DRY_RUN" = false ]; then
            ssh -p "$SSH_PORT" "$server" "cp \"$file\" \"$backup_file\"" 2>/dev/null
            if [ "$VERBOSE" = true ]; then
                print_info "Backed up $file to $backup_file on $server"
            fi
        else
            print_info "[DRY RUN] Would backup $file to $backup_file on $server"
        fi
    fi
}

# Function to push dotfile to server
push_dotfile() {
    local server=$1
    local dotfile=$2
    local local_file="${DOTFILES_DIR}/${dotfile}"

    if [ ! -f "$local_file" ]; then
        print_warning "Local file not found: $local_file (skipping)"
        return
    fi

    # Backup existing file on remote
    if [ "$BACKUP" = true ]; then
        backup_remote_file "$server" "\$HOME/${dotfile}"
    fi

    # Copy file to remote
    if [ "$DRY_RUN" = false ]; then
        if scp -P "$SSH_PORT" "$local_file" "${server}:~/${dotfile}" &>/dev/null; then
            if [ "$VERBOSE" = true ]; then
                print_success "Pushed $dotfile to $server"
            fi
        else
            print_error "Failed to push $dotfile to $server"
        fi
    else
        print_info "[DRY RUN] Would push $dotfile to $server"
    fi
}

# Function to pull dotfile from server
pull_dotfile() {
    local server=$1
    local dotfile=$2
    local local_file="${DOTFILES_DIR}/${dotfile}"

    # Check if file exists on remote
    if ! ssh -p "$SSH_PORT" "$server" "[ -f \"\$HOME/${dotfile}\" ]" 2>/dev/null; then
        print_warning "Remote file not found on $server: ~/${dotfile} (skipping)"
        return
    fi

    # Backup existing local file
    if [ "$BACKUP" = true ] && [ -f "$local_file" ]; then
        local backup_file="${local_file}.backup.$(date +%Y%m%d_%H%M%S)"
        if [ "$DRY_RUN" = false ]; then
            cp "$local_file" "$backup_file"
            if [ "$VERBOSE" = true ]; then
                print_info "Backed up local $dotfile to $backup_file"
            fi
        else
            print_info "[DRY RUN] Would backup local $dotfile"
        fi
    fi

    # Copy file from remote
    if [ "$DRY_RUN" = false ]; then
        if scp -P "$SSH_PORT" "${server}:~/${dotfile}" "$local_file" &>/dev/null; then
            if [ "$VERBOSE" = true ]; then
                print_success "Pulled $dotfile from $server"
            fi
        else
            print_error "Failed to pull $dotfile from $server"
        fi
    else
        print_info "[DRY RUN] Would pull $dotfile from $server"
    fi
}

# Function to sync dotfiles to/from servers
sync_dotfiles() {
    IFS=',' read -ra SERVER_LIST <<< "$SERVERS"

    for server in "${SERVER_LIST[@]}"; do
        # Trim whitespace
        server=$(echo "$server" | xargs)

        print_info "Syncing with: $server"

        # Test SSH connection
        if ! test_ssh_connection "$server"; then
            print_error "Cannot connect to $server via SSH"
            continue
        fi

        # Sync each dotfile
        for dotfile in "${DOTFILES[@]}"; do
            if [ "$DIRECTION" = "push" ]; then
                push_dotfile "$server" "$dotfile"
            else
                pull_dotfile "$server" "$dotfile"
            fi
        done

        print_success "Completed sync with $server"
        echo
    done
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --servers)
            SERVERS="$2"
            shift 2
            ;;
        --inventory)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        --direction)
            DIRECTION="$2"
            if [[ ! "$DIRECTION" =~ ^(push|pull)$ ]]; then
                print_error "Invalid direction. Must be 'push' or 'pull'"
                exit 1
            fi
            shift 2
            ;;
        --dotfiles-dir)
            DOTFILES_DIR="$2"
            shift 2
            ;;
        --ssh-user)
            SSH_USER="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        --files)
            IFS=',' read -ra DOTFILES <<< "$2"
            shift 2
            ;;
        --no-backup)
            BACKUP=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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
    print_info "Dotfiles Synchronizer"
    echo

    # Check dotfiles directory
    check_dotfiles_dir

    # Parse inventory if provided
    if [ -n "$INVENTORY_FILE" ]; then
        print_info "Loading servers from inventory: $INVENTORY_FILE"
        SERVERS=$(parse_inventory "$INVENTORY_FILE")

        if [ -z "$SERVERS" ]; then
            print_error "No servers found in inventory file"
            exit 1
        fi

        if [ "$VERBOSE" = true ]; then
            print_info "Found servers: $SERVERS"
        fi
    fi

    # Validate servers
    if [ -z "$SERVERS" ]; then
        print_error "No servers specified"
        echo
        show_help
        exit 1
    fi

    # Show configuration
    print_info "Configuration:"
    echo "  Direction: $DIRECTION"
    echo "  Servers: $SERVERS"
    echo "  Dotfiles: ${DOTFILES[*]}"
    echo "  Backup: $BACKUP"
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi
    echo

    # Sync dotfiles
    sync_dotfiles

    print_success "Dotfiles synchronization complete!"
}

main

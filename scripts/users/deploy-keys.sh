#!/usr/bin/env bash
#
# SSH Key Deployer - Deploy SSH keys across multiple servers
# Manage SSH access for teams
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Defaults
DRY_RUN=false
KEY_FILE=""
SERVERS_FILE=""
USERNAME=""
REMOVE=false

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
SSH Key Deployer - Deploy SSH public keys across servers

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    -k, --key-file FILE     SSH public key file to deploy
    -s, --servers FILE      File containing list of servers
    -u, --user USER         Username to deploy key for
    -r, --remove            Remove key instead of adding
    --dry-run               Show what would be done
    --help                  Show this help message

FILE FORMATS:

servers.txt:
    user@host1
    user@host2:2222
    192.168.1.100

Or use YAML inventory:
    ./scripts/monitoring/health-check.py --config inventory/servers.yaml

EXAMPLES:
    # Deploy key to servers
    $(basename "$0") --key-file ~/.ssh/id_rsa.pub \\
        --servers servers.txt \\
        --user deploy

    # Remove key from servers
    $(basename "$0") --key-file ~/.ssh/old_key.pub \\
        --servers servers.txt \\
        --user deploy \\
        --remove

    # Dry run
    $(basename "$0") --key-file ~/.ssh/id_rsa.pub \\
        --servers servers.txt \\
        --user deploy \\
        --dry-run

NOTES:
    - Requires SSH access to target servers
    - Uses SSH agent or SSH keys for authentication
    - Creates ~/.ssh directory if it doesn't exist
    - Sets proper permissions (700 for .ssh, 600 for authorized_keys)

EOF
}

#######################################
# Deploy key to server
#######################################
deploy_key() {
    local server="$1"
    local user="$2"
    local key_content="$3"

    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

    print_info "Deploying key to: ${user}@${server}"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY-RUN] Would deploy key to ${user}@${server}"
        return 0
    fi

    # Create .ssh directory if it doesn't exist
    if ! ssh $ssh_opts "${user}@${server}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh"; then
        print_error "Failed to create .ssh directory on ${server}"
        return 1
    fi

    # Add key to authorized_keys
    if ssh $ssh_opts "${user}@${server}" "echo '${key_content}' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && sort -u ~/.ssh/authorized_keys -o ~/.ssh/authorized_keys"; then
        print_success "Key deployed to ${server}"
        return 0
    else
        print_error "Failed to deploy key to ${server}"
        return 1
    fi
}

#######################################
# Remove key from server
#######################################
remove_key() {
    local server="$1"
    local user="$2"
    local key_content="$3"

    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

    print_info "Removing key from: ${user}@${server}"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "[DRY-RUN] Would remove key from ${user}@${server}"
        return 0
    fi

    # Remove key from authorized_keys
    if ssh $ssh_opts "${user}@${server}" "grep -v '${key_content}' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
        print_success "Key removed from ${server}"
        return 0
    else
        print_error "Failed to remove key from ${server}"
        return 1
    fi
}

#######################################
# Main function
#######################################
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--key-file)
                KEY_FILE="$2"
                shift 2
                ;;
            -s|--servers)
                SERVERS_FILE="$2"
                shift 2
                ;;
            -u|--user)
                USERNAME="$2"
                shift 2
                ;;
            -r|--remove)
                REMOVE=true
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
                show_help
                exit 1
                ;;
        esac
    done

    # Validate inputs
    if [[ -z "$KEY_FILE" ]]; then
        print_error "Key file is required"
        show_help
        exit 1
    fi

    if [[ ! -f "$KEY_FILE" ]]; then
        print_error "Key file not found: $KEY_FILE"
        exit 1
    fi

    if [[ -z "$SERVERS_FILE" ]]; then
        print_error "Servers file is required"
        show_help
        exit 1
    fi

    if [[ ! -f "$SERVERS_FILE" ]]; then
        print_error "Servers file not found: $SERVERS_FILE"
        exit 1
    fi

    if [[ -z "$USERNAME" ]]; then
        print_error "Username is required"
        show_help
        exit 1
    fi

    # Read key content
    local key_content
    key_content=$(cat "$KEY_FILE")

    print_info "Key fingerprint: $(ssh-keygen -lf "$KEY_FILE" | awk '{print $2}')"

    # Read servers
    local servers
    mapfile -t servers < "$SERVERS_FILE"

    if [[ ${#servers[@]} -eq 0 ]]; then
        print_error "No servers found in file"
        exit 1
    fi

    print_info "Servers to process: ${#servers[@]}"
    echo ""

    # Process each server
    local success_count=0
    local fail_count=0

    for server in "${servers[@]}"; do
        # Skip empty lines and comments
        [[ -z "$server" || "$server" =~ ^#.*$ ]] && continue

        # Deploy or remove key
        if [[ "$REMOVE" == "true" ]]; then
            if remove_key "$server" "$USERNAME" "$key_content"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        else
            if deploy_key "$server" "$USERNAME" "$key_content"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        fi

        echo ""
    done

    # Summary
    print_info "Summary: $success_count succeeded, $fail_count failed"

    if [[ $fail_count -gt 0 ]]; then
        exit 1
    fi
}

main "$@"

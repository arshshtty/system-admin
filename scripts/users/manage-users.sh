#!/usr/bin/env bash
#
# User Management - Create and manage system users
# Standardized user provisioning with security best practices
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
# Check root
#######################################
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

#######################################
# Show help
#######################################
show_help() {
    cat << EOF
User Management - Create and manage system users

USAGE:
    $(basename "$0") COMMAND [OPTIONS]

COMMANDS:
    create USER             Create new user
    delete USER             Delete user
    lock USER               Lock user account
    unlock USER             Unlock user account
    add-sudo USER           Add user to sudo group
    remove-sudo USER        Remove user from sudo group
    list                    List all users
    list-sudo               List users with sudo access
    audit                   Audit user accounts

CREATE OPTIONS:
    --shell SHELL           Login shell (default: /bin/bash)
    --home DIR              Home directory
    --groups GROUPS         Additional groups (comma-separated)
    --sudo                  Add to sudo group
    --no-password           Disable password login
    --ssh-key FILE          Add SSH public key

EXAMPLES:
    # Create standard user
    $(basename "$0") create john --groups docker,www-data

    # Create admin user with SSH key
    $(basename "$0") create admin \\
        --sudo \\
        --ssh-key ~/.ssh/admin.pub \\
        --no-password

    # Create service account
    $(basename "$0") create appuser \\
        --shell /bin/false \\
        --groups docker

    # Lock inactive user
    $(basename "$0") lock john

    # List all sudo users
    $(basename "$0") list-sudo

    # Audit user accounts
    $(basename "$0") audit

EOF
}

#######################################
# Create user
#######################################
cmd_create() {
    local username="$1"
    shift

    local shell="/bin/bash"
    local home_dir=""
    local groups=""
    local add_sudo=false
    local no_password=false
    local ssh_key=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --shell)
                shell="$2"
                shift 2
                ;;
            --home)
                home_dir="$2"
                shift 2
                ;;
            --groups)
                groups="$2"
                shift 2
                ;;
            --sudo)
                add_sudo=true
                shift
                ;;
            --no-password)
                no_password=true
                shift
                ;;
            --ssh-key)
                ssh_key="$2"
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Check if user exists
    if id "$username" &>/dev/null; then
        print_error "User already exists: $username"
        exit 1
    fi

    print_info "Creating user: $username"

    # Create user
    local create_cmd="useradd"
    create_cmd="$create_cmd -m"  # Create home directory
    create_cmd="$create_cmd -s $shell"

    if [[ -n "$home_dir" ]]; then
        create_cmd="$create_cmd -d $home_dir"
    fi

    if [[ -n "$groups" ]]; then
        create_cmd="$create_cmd -G $groups"
    fi

    create_cmd="$create_cmd $username"

    if $create_cmd; then
        print_success "User created: $username"
    else
        print_error "Failed to create user"
        exit 1
    fi

    # Add to sudo if requested
    if [[ "$add_sudo" == "true" ]]; then
        usermod -aG sudo "$username"
        print_success "Added to sudo group"
    fi

    # Disable password if requested
    if [[ "$no_password" == "true" ]]; then
        passwd -l "$username"
        print_success "Password login disabled"
    else
        # Set password
        print_info "Setting password for $username"
        passwd "$username"
    fi

    # Add SSH key if provided
    if [[ -n "$ssh_key" ]] && [[ -f "$ssh_key" ]]; then
        local user_home
        user_home=$(eval echo "~$username")
        mkdir -p "$user_home/.ssh"
        cat "$ssh_key" >> "$user_home/.ssh/authorized_keys"
        chmod 700 "$user_home/.ssh"
        chmod 600 "$user_home/.ssh/authorized_keys"
        chown -R "$username:$username" "$user_home/.ssh"
        print_success "SSH key added"
    fi

    print_success "User setup complete: $username"
    print_info "Home directory: $(eval echo "~$username")"
}

#######################################
# Delete user
#######################################
cmd_delete() {
    local username="$1"

    if ! id "$username" &>/dev/null; then
        print_error "User does not exist: $username"
        exit 1
    fi

    print_warning "This will delete user: $username"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        exit 0
    fi

    # Kill user processes
    pkill -u "$username" || true

    # Delete user and home directory
    if userdel -r "$username"; then
        print_success "User deleted: $username"
    else
        print_error "Failed to delete user"
        exit 1
    fi
}

#######################################
# Lock user
#######################################
cmd_lock() {
    local username="$1"

    if ! id "$username" &>/dev/null; then
        print_error "User does not exist: $username"
        exit 1
    fi

    passwd -l "$username"
    print_success "User locked: $username"
}

#######################################
# Unlock user
#######################################
cmd_unlock() {
    local username="$1"

    if ! id "$username" &>/dev/null; then
        print_error "User does not exist: $username"
        exit 1
    fi

    passwd -u "$username"
    print_success "User unlocked: $username"
}

#######################################
# Add to sudo
#######################################
cmd_add_sudo() {
    local username="$1"

    if ! id "$username" &>/dev/null; then
        print_error "User does not exist: $username"
        exit 1
    fi

    usermod -aG sudo "$username"
    print_success "User added to sudo group: $username"
}

#######################################
# Remove from sudo
#######################################
cmd_remove_sudo() {
    local username="$1"

    if ! id "$username" &>/dev/null; then
        print_error "User does not exist: $username"
        exit 1
    fi

    deluser "$username" sudo 2>/dev/null || gpasswd -d "$username" sudo
    print_success "User removed from sudo group: $username"
}

#######################################
# List users
#######################################
cmd_list() {
    print_info "System users (UID >= 1000):"
    echo ""
    printf "%-20s %-10s %-30s %-20s\n" "USERNAME" "UID" "HOME" "SHELL"
    echo "--------------------------------------------------------------------------------"

    while IFS=: read -r username _ uid _ _ home shell; do
        if [[ $uid -ge 1000 ]] && [[ $uid -lt 65534 ]]; then
            printf "%-20s %-10s %-30s %-20s\n" "$username" "$uid" "$home" "$shell"
        fi
    done < /etc/passwd
}

#######################################
# List sudo users
#######################################
cmd_list_sudo() {
    print_info "Users with sudo access:"
    echo ""

    if grep -q "^sudo:" /etc/group; then
        grep "^sudo:" /etc/group | cut -d: -f4 | tr ',' '\n'
    elif grep -q "^wheel:" /etc/group; then
        grep "^wheel:" /etc/group | cut -d: -f4 | tr ',' '\n'
    else
        print_warning "No sudo group found"
    fi
}

#######################################
# Audit users
#######################################
cmd_audit() {
    print_info "User Account Audit"
    echo ""

    # Users with empty passwords
    print_info "Users with empty passwords:"
    awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null || print_warning "Cannot access /etc/shadow"
    echo ""

    # Users with UID 0
    print_info "Users with UID 0 (root equivalent):"
    awk -F: '($3 == "0") {print $1}' /etc/passwd
    echo ""

    # Users with no home directory
    print_info "Users with missing home directories:"
    while IFS=: read -r username _ _ _ _ home _; do
        if [[ ! -d "$home" ]]; then
            echo "$username: $home"
        fi
    done < /etc/passwd
    echo ""

    # Locked accounts
    print_info "Locked accounts:"
    passwd -S -a 2>/dev/null | grep " L " | awk '{print $1}'
    echo ""

    # Last login times
    print_info "Last login times (users who never logged in):"
    lastlog | grep "Never"
}

#######################################
# Main function
#######################################
main() {
    check_root

    local command="${1:-}"

    if [[ -z "$command" ]]; then
        show_help
        exit 1
    fi

    shift

    case "$command" in
        create)
            if [[ $# -lt 1 ]]; then
                print_error "Username required"
                exit 1
            fi
            cmd_create "$@"
            ;;
        delete)
            if [[ $# -lt 1 ]]; then
                print_error "Username required"
                exit 1
            fi
            cmd_delete "$@"
            ;;
        lock)
            if [[ $# -lt 1 ]]; then
                print_error "Username required"
                exit 1
            fi
            cmd_lock "$@"
            ;;
        unlock)
            if [[ $# -lt 1 ]]; then
                print_error "Username required"
                exit 1
            fi
            cmd_unlock "$@"
            ;;
        add-sudo)
            if [[ $# -lt 1 ]]; then
                print_error "Username required"
                exit 1
            fi
            cmd_add_sudo "$@"
            ;;
        remove-sudo)
            if [[ $# -lt 1 ]]; then
                print_error "Username required"
                exit 1
            fi
            cmd_remove_sudo "$@"
            ;;
        list)
            cmd_list
            ;;
        list-sudo)
            cmd_list_sudo
            ;;
        audit)
            cmd_audit
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

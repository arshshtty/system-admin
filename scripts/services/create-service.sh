#!/usr/bin/env bash
#
# Systemd Service Generator - Interactive systemd service file creator
# Generate proper systemd service files with best practices
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Service configuration
SERVICE_NAME=""
DESCRIPTION=""
EXEC_START=""
EXEC_STOP=""
WORKING_DIR=""
USER=""
GROUP=""
TYPE="simple"
RESTART="always"
RESTART_SEC="10"
AFTER="network.target"
REQUIRES=""
ENVIRONMENT=""
ENVIRONMENT_FILE=""
LIMIT_NOFILE="65536"
MEMORY_LIMIT=""
CPU_QUOTA=""

# Flags
INTERACTIVE=false
OUTPUT_FILE=""
ENABLE=false
START=false

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
Systemd Service Generator - Create systemd service files interactively

USAGE:
    $(basename "$0") [OPTIONS] [SERVICE_NAME]

OPTIONS:
    -i, --interactive       Interactive mode (ask questions)
    -n, --name NAME         Service name
    -d, --description DESC  Service description
    -e, --exec COMMAND      ExecStart command
    -w, --workdir PATH      Working directory
    -u, --user USER         Run as user
    -g, --group GROUP       Run as group
    -t, --type TYPE         Service type (simple, forking, oneshot, notify)
    -r, --restart POLICY    Restart policy (always, on-failure, no)
    --after TARGET          Start after (default: network.target)
    --requires TARGET       Requires target
    --env KEY=VALUE         Environment variable
    --env-file FILE         Environment file path
    --limit-nofile N        File descriptor limit
    --memory-limit SIZE     Memory limit (e.g., 2G, 512M)
    --cpu-quota PERCENT     CPU quota (e.g., 200% for 2 cores)
    --enable                Enable service after creation
    --start                 Start service after creation
    --output FILE           Output file path
    --help                  Show this help message

EXAMPLES:
    # Interactive mode
    $(basename "$0") --interactive

    # Create web app service
    $(basename "$0") --name myapp \\
        --description "My Web Application" \\
        --exec "/opt/myapp/bin/start" \\
        --workdir /opt/myapp \\
        --user appuser \\
        --restart always \\
        --enable

    # Create Node.js service
    $(basename "$0") --name nodeapp \\
        --exec "node server.js" \\
        --workdir /var/www/nodeapp \\
        --user www-data \\
        --env "NODE_ENV=production" \\
        --env "PORT=3000" \\
        --memory-limit 1G \\
        --enable --start

    # Create Python service with venv
    $(basename "$0") --name pythonapp \\
        --exec "/opt/pythonapp/venv/bin/python app.py" \\
        --workdir /opt/pythonapp \\
        --user pythonapp \\
        --env-file /opt/pythonapp/.env \\
        --enable

SERVICE TYPES:
    simple      - Default. ExecStart is the main process
    forking     - Process forks, parent exits
    oneshot     - Process exits after task completion
    notify      - Service sends notification when ready

RESTART POLICIES:
    always      - Always restart
    on-failure  - Restart on non-zero exit
    on-abnormal - Restart on crash/timeout
    no          - Never restart

EOF
}

#######################################
# Interactive prompts
#######################################
interactive_mode() {
    print_info "Interactive Service Creation"
    echo ""

    # Service name
    read -p "Service name: " SERVICE_NAME
    if [[ -z "$SERVICE_NAME" ]]; then
        print_error "Service name is required"
        exit 1
    fi

    # Description
    read -p "Description: " DESCRIPTION
    if [[ -z "$DESCRIPTION" ]]; then
        DESCRIPTION="$SERVICE_NAME service"
    fi

    # Exec command
    read -p "ExecStart command: " EXEC_START
    if [[ -z "$EXEC_START" ]]; then
        print_error "ExecStart is required"
        exit 1
    fi

    # Working directory
    read -p "Working directory [/opt/$SERVICE_NAME]: " WORKING_DIR
    if [[ -z "$WORKING_DIR" ]]; then
        WORKING_DIR="/opt/$SERVICE_NAME"
    fi

    # User
    read -p "Run as user [root]: " USER
    if [[ -z "$USER" ]]; then
        USER="root"
    fi

    # Group
    read -p "Run as group [$USER]: " GROUP
    if [[ -z "$GROUP" ]]; then
        GROUP="$USER"
    fi

    # Type
    read -p "Service type (simple/forking/oneshot) [simple]: " TYPE
    if [[ -z "$TYPE" ]]; then
        TYPE="simple"
    fi

    # Restart policy
    read -p "Restart policy (always/on-failure/no) [always]: " RESTART
    if [[ -z "$RESTART" ]]; then
        RESTART="always"
    fi

    # Dependencies
    read -p "Start after [network.target]: " AFTER
    if [[ -z "$AFTER" ]]; then
        AFTER="network.target"
    fi

    # Environment file
    read -p "Environment file (optional): " ENVIRONMENT_FILE

    # Resource limits
    read -p "Memory limit (e.g., 2G, 512M) [none]: " MEMORY_LIMIT
    read -p "CPU quota (e.g., 200% for 2 cores) [none]: " CPU_QUOTA

    # Enable and start
    read -p "Enable service on boot? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ENABLE=true
    fi

    read -p "Start service now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        START=true
    fi
}

#######################################
# Generate service file content
#######################################
generate_service_file() {
    cat << EOF
[Unit]
Description=$DESCRIPTION
After=$AFTER
EOF

    if [[ -n "$REQUIRES" ]]; then
        echo "Requires=$REQUIRES"
    fi

    cat << EOF

[Service]
Type=$TYPE
User=$USER
Group=$GROUP
WorkingDirectory=$WORKING_DIR
ExecStart=$EXEC_START
EOF

    if [[ -n "$EXEC_STOP" ]]; then
        echo "ExecStop=$EXEC_STOP"
    fi

    if [[ "$RESTART" != "no" ]]; then
        cat << EOF
Restart=$RESTART
RestartSec=${RESTART_SEC}s
EOF
    fi

    # Environment
    if [[ -n "$ENVIRONMENT" ]]; then
        echo "Environment=\"$ENVIRONMENT\""
    fi

    if [[ -n "$ENVIRONMENT_FILE" ]]; then
        echo "EnvironmentFile=$ENVIRONMENT_FILE"
    fi

    # Standard output/error
    cat << EOF
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME
EOF

    # Resource limits
    if [[ -n "$LIMIT_NOFILE" ]]; then
        echo "LimitNOFILE=$LIMIT_NOFILE"
    fi

    if [[ -n "$MEMORY_LIMIT" ]]; then
        echo "MemoryLimit=$MEMORY_LIMIT"
    fi

    if [[ -n "$CPU_QUOTA" ]]; then
        echo "CPUQuota=$CPU_QUOTA"
    fi

    cat << EOF

[Install]
WantedBy=multi-user.target
EOF
}

#######################################
# Validate service file
#######################################
validate_service() {
    # Check if user exists
    if [[ "$USER" != "root" ]] && ! id "$USER" &>/dev/null; then
        print_warning "User '$USER' does not exist"
        read -p "Create user? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo useradd -r -s /bin/false "$USER"
            print_success "User created: $USER"
        fi
    fi

    # Check if working directory exists
    if [[ ! -d "$WORKING_DIR" ]]; then
        print_warning "Working directory does not exist: $WORKING_DIR"
        read -p "Create directory? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo mkdir -p "$WORKING_DIR"
            sudo chown "$USER:$GROUP" "$WORKING_DIR"
            print_success "Directory created: $WORKING_DIR"
        fi
    fi

    # Check if exec command exists
    local cmd
    cmd=$(echo "$EXEC_START" | awk '{print $1}')
    if [[ ! -f "$cmd" ]] && ! command -v "$cmd" &>/dev/null; then
        print_warning "ExecStart command may not exist: $cmd"
    fi
}

#######################################
# Main function
#######################################
main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interactive)
                INTERACTIVE=true
                shift
                ;;
            -n|--name)
                SERVICE_NAME="$2"
                shift 2
                ;;
            -d|--description)
                DESCRIPTION="$2"
                shift 2
                ;;
            -e|--exec)
                EXEC_START="$2"
                shift 2
                ;;
            -w|--workdir)
                WORKING_DIR="$2"
                shift 2
                ;;
            -u|--user)
                USER="$2"
                shift 2
                ;;
            -g|--group)
                GROUP="$2"
                shift 2
                ;;
            -t|--type)
                TYPE="$2"
                shift 2
                ;;
            -r|--restart)
                RESTART="$2"
                shift 2
                ;;
            --after)
                AFTER="$2"
                shift 2
                ;;
            --requires)
                REQUIRES="$2"
                shift 2
                ;;
            --env)
                ENVIRONMENT="$ENVIRONMENT $2"
                shift 2
                ;;
            --env-file)
                ENVIRONMENT_FILE="$2"
                shift 2
                ;;
            --limit-nofile)
                LIMIT_NOFILE="$2"
                shift 2
                ;;
            --memory-limit)
                MEMORY_LIMIT="$2"
                shift 2
                ;;
            --cpu-quota)
                CPU_QUOTA="$2"
                shift 2
                ;;
            --enable)
                ENABLE=true
                shift
                ;;
            --start)
                START=true
                shift
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
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
                SERVICE_NAME="$1"
                shift
                ;;
        esac
    done

    # Run interactive mode if requested
    if [[ "$INTERACTIVE" == "true" ]]; then
        interactive_mode
    fi

    # Validate required fields
    if [[ -z "$SERVICE_NAME" ]]; then
        print_error "Service name is required"
        show_help
        exit 1
    fi

    if [[ -z "$EXEC_START" ]]; then
        print_error "ExecStart command is required"
        show_help
        exit 1
    fi

    # Set defaults
    if [[ -z "$DESCRIPTION" ]]; then
        DESCRIPTION="$SERVICE_NAME service"
    fi

    if [[ -z "$WORKING_DIR" ]]; then
        WORKING_DIR="/opt/$SERVICE_NAME"
    fi

    if [[ -z "$USER" ]]; then
        USER="root"
    fi

    if [[ -z "$GROUP" ]]; then
        GROUP="$USER"
    fi

    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    fi

    # Validate
    validate_service

    # Generate service file
    print_info "Generating service file: $OUTPUT_FILE"
    local content
    content=$(generate_service_file)

    # Show preview
    echo ""
    print_info "Service file content:"
    echo "---"
    echo "$content"
    echo "---"
    echo ""

    # Confirm
    read -p "Create this service file? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cancelled"
        exit 0
    fi

    # Write file
    echo "$content" | sudo tee "$OUTPUT_FILE" > /dev/null
    print_success "Service file created: $OUTPUT_FILE"

    # Reload systemd
    sudo systemctl daemon-reload
    print_success "Systemd daemon reloaded"

    # Enable if requested
    if [[ "$ENABLE" == "true" ]]; then
        sudo systemctl enable "$SERVICE_NAME"
        print_success "Service enabled: $SERVICE_NAME"
    fi

    # Start if requested
    if [[ "$START" == "true" ]]; then
        sudo systemctl start "$SERVICE_NAME"
        print_success "Service started: $SERVICE_NAME"

        # Show status
        echo ""
        sudo systemctl status "$SERVICE_NAME" --no-pager -l
    fi

    # Next steps
    echo ""
    print_info "Next steps:"
    echo "  1. Review the service file: sudo nano $OUTPUT_FILE"
    if [[ "$ENABLE" != "true" ]]; then
        echo "  2. Enable on boot: sudo systemctl enable $SERVICE_NAME"
    fi
    if [[ "$START" != "true" ]]; then
        echo "  3. Start service: sudo systemctl start $SERVICE_NAME"
    fi
    echo "  4. Check status: sudo systemctl status $SERVICE_NAME"
    echo "  5. View logs: sudo journalctl -u $SERVICE_NAME -f"
}

main "$@"

#!/usr/bin/env bash
#
# Alert Notification System - Multi-channel alerting
# Send alerts via ntfy.sh, email, Slack, Discord, and more
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration (can be overridden via environment variables)
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
NTFY_TOPIC="${NTFY_TOPIC:-}"
SLACK_WEBHOOK="${SLACK_WEBHOOK:-}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-}"
EMAIL_TO="${EMAIL_TO:-}"
EMAIL_FROM="${EMAIL_FROM:-alerts@$(hostname)}"

# Alert levels
LEVEL_INFO="info"
LEVEL_WARNING="warning"
LEVEL_ERROR="error"
LEVEL_CRITICAL="critical"

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
Alert Notification System - Multi-channel alerting

USAGE:
    $(basename "$0") [OPTIONS] MESSAGE

OPTIONS:
    -t, --title TITLE       Alert title
    -l, --level LEVEL       Alert level (info, warning, error, critical)
    -c, --channel CHANNEL   Notification channel (ntfy, slack, discord, email, all)
    -p, --priority PRIORITY Priority (1-5, default: 3)
    --tag TAG               Add tag to notification
    --config FILE           Load configuration from file
    --test                  Test notification channels
    --help                  Show this help message

CONFIGURATION:
    Set via environment variables or config file:

    NTFY_SERVER             ntfy.sh server URL (default: https://ntfy.sh)
    NTFY_TOPIC              ntfy.sh topic name
    SLACK_WEBHOOK           Slack webhook URL
    DISCORD_WEBHOOK         Discord webhook URL
    EMAIL_TO                Email recipient
    EMAIL_FROM              Email sender (default: alerts@hostname)

EXAMPLES:
    # Send info notification via ntfy
    $(basename "$0") -c ntfy -l info "Backup completed successfully"

    # Send critical alert to all channels
    $(basename "$0") -c all -l critical -t "Disk Full" "Root partition is 95% full"

    # Send warning to Slack
    $(basename "$0") -c slack -l warning "High CPU usage detected"

    # Load config and send alert
    $(basename "$0") --config /etc/notify.conf -c all "Service restarted"

    # Test all notification channels
    $(basename "$0") --test

CONFIG FILE FORMAT:
    Create /etc/notify.conf or ~/.notify.conf:

    NTFY_TOPIC="myserver-alerts"
    SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR/WEBHOOK"
    EMAIL_TO="admin@example.com"

ALERT LEVELS:
    info      - Informational message (🔵)
    warning   - Warning message (🟡)
    error     - Error message (🔴)
    critical  - Critical alert (🚨)

CHANNELS:
    ntfy      - ntfy.sh push notifications
    slack     - Slack webhook
    discord   - Discord webhook
    email     - Email via sendmail/mail command
    all       - Send to all configured channels

EOF
}

#######################################
# Load configuration file
#######################################
load_config() {
    local config_file="$1"

    if [[ -f "$config_file" ]]; then
        print_info "Loading configuration from: $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
    else
        print_warning "Config file not found: $config_file"
    fi
}

#######################################
# Get emoji for level
#######################################
get_emoji() {
    local level="$1"

    case "$level" in
        info)
            echo "🔵"
            ;;
        warning)
            echo "🟡"
            ;;
        error)
            echo "🔴"
            ;;
        critical)
            echo "🚨"
            ;;
        *)
            echo "ℹ️"
            ;;
    esac
}

#######################################
# Get ntfy priority from level
#######################################
get_ntfy_priority() {
    local level="$1"

    case "$level" in
        info)
            echo "3"
            ;;
        warning)
            echo "4"
            ;;
        error)
            echo "4"
            ;;
        critical)
            echo "5"
            ;;
        *)
            echo "3"
            ;;
    esac
}

#######################################
# Send notification via ntfy.sh
#######################################
send_ntfy() {
    local title="$1"
    local message="$2"
    local level="$3"
    local tags="$4"

    if [[ -z "$NTFY_TOPIC" ]]; then
        print_warning "NTFY_TOPIC not configured, skipping ntfy notification"
        return 1
    fi

    local priority
    priority=$(get_ntfy_priority "$level")
    local emoji
    emoji=$(get_emoji "$level")

    local url="${NTFY_SERVER}/${NTFY_TOPIC}"

    print_info "Sending notification to ntfy: $url"

    if curl -f -s \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags,$level" \
        -d "${emoji} ${message}" \
        "$url" > /dev/null; then
        print_success "Sent to ntfy"
        return 0
    else
        print_error "Failed to send to ntfy"
        return 1
    fi
}

#######################################
# Send notification via Slack
#######################################
send_slack() {
    local title="$1"
    local message="$2"
    local level="$3"

    if [[ -z "$SLACK_WEBHOOK" ]]; then
        print_warning "SLACK_WEBHOOK not configured, skipping Slack notification"
        return 1
    fi

    local emoji
    emoji=$(get_emoji "$level")
    local color

    case "$level" in
        info)
            color="good"
            ;;
        warning)
            color="warning"
            ;;
        error|critical)
            color="danger"
            ;;
        *)
            color="#808080"
            ;;
    esac

    local payload
    payload=$(cat <<EOF
{
    "attachments": [{
        "color": "$color",
        "title": "$emoji $title",
        "text": "$message",
        "footer": "$(hostname)",
        "ts": $(date +%s)
    }]
}
EOF
)

    print_info "Sending notification to Slack"

    if curl -f -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$SLACK_WEBHOOK" > /dev/null; then
        print_success "Sent to Slack"
        return 0
    else
        print_error "Failed to send to Slack"
        return 1
    fi
}

#######################################
# Send notification via Discord
#######################################
send_discord() {
    local title="$1"
    local message="$2"
    local level="$3"

    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        print_warning "DISCORD_WEBHOOK not configured, skipping Discord notification"
        return 1
    fi

    local emoji
    emoji=$(get_emoji "$level")
    local color_decimal

    case "$level" in
        info)
            color_decimal=3447003  # Blue
            ;;
        warning)
            color_decimal=16776960  # Yellow
            ;;
        error)
            color_decimal=15158332  # Red
            ;;
        critical)
            color_decimal=10038562  # Dark red
            ;;
        *)
            color_decimal=8421504  # Gray
            ;;
    esac

    local payload
    payload=$(cat <<EOF
{
    "embeds": [{
        "title": "$emoji $title",
        "description": "$message",
        "color": $color_decimal,
        "footer": {
            "text": "$(hostname)"
        },
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
    }]
}
EOF
)

    print_info "Sending notification to Discord"

    if curl -f -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$DISCORD_WEBHOOK" > /dev/null; then
        print_success "Sent to Discord"
        return 0
    else
        print_error "Failed to send to Discord"
        return 1
    fi
}

#######################################
# Send notification via email
#######################################
send_email() {
    local title="$1"
    local message="$2"
    local level="$3"

    if [[ -z "$EMAIL_TO" ]]; then
        print_warning "EMAIL_TO not configured, skipping email notification"
        return 1
    fi

    local emoji
    emoji=$(get_emoji "$level")
    local subject="$emoji $title - $(hostname)"

    print_info "Sending email to: $EMAIL_TO"

    local email_body
    email_body=$(cat <<EOF
Alert Level: $level
Server: $(hostname)
Time: $(date)

$message

--
Sent by System Admin Toolkit
EOF
)

    if command -v sendmail &> /dev/null; then
        echo "$email_body" | sendmail -f "$EMAIL_FROM" -t "$EMAIL_TO" -s "$subject"
        print_success "Sent email via sendmail"
        return 0
    elif command -v mail &> /dev/null; then
        echo "$email_body" | mail -s "$subject" -r "$EMAIL_FROM" "$EMAIL_TO"
        print_success "Sent email via mail"
        return 0
    else
        print_error "No mail command available (install mailutils or sendmail)"
        return 1
    fi
}

#######################################
# Test all notification channels
#######################################
test_notifications() {
    print_info "Testing notification channels..."
    echo ""

    local test_title="Test Notification"
    local test_message="This is a test notification from $(hostname)"
    local test_level="info"
    local test_tags="test"

    local success_count=0
    local total_count=0

    # Test ntfy
    echo "Testing ntfy.sh..."
    ((total_count++))
    if send_ntfy "$test_title" "$test_message" "$test_level" "$test_tags"; then
        ((success_count++))
    fi
    echo ""

    # Test Slack
    echo "Testing Slack..."
    ((total_count++))
    if send_slack "$test_title" "$test_message" "$test_level"; then
        ((success_count++))
    fi
    echo ""

    # Test Discord
    echo "Testing Discord..."
    ((total_count++))
    if send_discord "$test_title" "$test_message" "$test_level"; then
        ((success_count++))
    fi
    echo ""

    # Test Email
    echo "Testing Email..."
    ((total_count++))
    if send_email "$test_title" "$test_message" "$test_level"; then
        ((success_count++))
    fi
    echo ""

    print_info "Test complete: $success_count/$total_count channels working"
}

#######################################
# Main function
#######################################
main() {
    local title=""
    local message=""
    local level="info"
    local channel="all"
    local tags=""
    local config_file=""
    local test_mode=false

    # Try to load default config files
    for default_config in "/etc/notify.conf" "$HOME/.notify.conf" ".notify.conf"; do
        if [[ -f "$default_config" ]]; then
            load_config "$default_config"
            break
        fi
    done

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--title)
                title="$2"
                shift 2
                ;;
            -l|--level)
                level="$2"
                shift 2
                ;;
            -c|--channel)
                channel="$2"
                shift 2
                ;;
            --tag)
                tags="$2"
                shift 2
                ;;
            --config)
                load_config "$2"
                shift 2
                ;;
            --test)
                test_mode=true
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
                message="$1"
                shift
                ;;
        esac
    done

    # Handle test mode
    if [[ "$test_mode" == "true" ]]; then
        test_notifications
        exit 0
    fi

    # Validate inputs
    if [[ -z "$message" ]]; then
        print_error "Message is required"
        show_help
        exit 1
    fi

    # Use message as title if no title provided
    if [[ -z "$title" ]]; then
        title="${level^^}: ${message:0:50}"
    fi

    # Send to requested channels
    case "$channel" in
        ntfy)
            send_ntfy "$title" "$message" "$level" "$tags"
            ;;
        slack)
            send_slack "$title" "$message" "$level"
            ;;
        discord)
            send_discord "$title" "$message" "$level"
            ;;
        email)
            send_email "$title" "$message" "$level"
            ;;
        all)
            send_ntfy "$title" "$message" "$level" "$tags" || true
            send_slack "$title" "$message" "$level" || true
            send_discord "$title" "$message" "$level" || true
            send_email "$title" "$message" "$level" || true
            ;;
        *)
            print_error "Unknown channel: $channel"
            exit 1
            ;;
    esac
}

main "$@"

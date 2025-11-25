#!/usr/bin/env bash
#
# Timezone and Locale Configuration Tool
# Standardize time and locale settings across servers
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TIMEZONE=""
LOCALE=""
NTP_ENABLED=false
SET_HARDWARE_CLOCK=false
INTERACTIVE=false
DRY_RUN=false
VERBOSE=false

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
Timezone and Locale Configuration Tool

Standardize timezone and locale settings across servers.

USAGE:
    $(basename "$0") [OPTIONS]

OPTIONS:
    --timezone TZ           Set timezone (e.g., America/New_York, UTC, Europe/London)
    --locale LOCALE         Set system locale (e.g., en_US.UTF-8)
    --enable-ntp            Enable NTP time synchronization
    --set-hwclock           Sync hardware clock with system time
    --interactive           Interactive mode to select timezone/locale
    --list-timezones        List all available timezones
    --list-locales          List all available locales
    --dry-run               Show what would be changed without doing it
    --verbose               Show detailed output
    --help                  Show this help message

EXAMPLES:
    # Set timezone to UTC
    sudo $(basename "$0") --timezone UTC

    # Set timezone and enable NTP
    sudo $(basename "$0") --timezone America/New_York --enable-ntp

    # Set locale
    sudo $(basename "$0") --locale en_US.UTF-8

    # Set both timezone and locale
    sudo $(basename "$0") --timezone Europe/London --locale en_GB.UTF-8

    # Interactive mode
    sudo $(basename "$0") --interactive

    # Dry run to see what would change
    $(basename "$0") --timezone UTC --dry-run

COMMON TIMEZONES:
    America/New_York     - Eastern Time (US)
    America/Chicago      - Central Time (US)
    America/Denver       - Mountain Time (US)
    America/Los_Angeles  - Pacific Time (US)
    Europe/London        - UK
    Europe/Paris         - Central Europe
    Asia/Tokyo           - Japan
    Asia/Shanghai        - China
    UTC                  - Coordinated Universal Time

NOTES:
    - Requires root/sudo privileges
    - Changes take effect immediately
    - Existing services may need restart to pick up changes
    - NTP synchronization recommended for production servers
EOF
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then
        print_error "This script must be run as root"
        print_info "Try: sudo $0 $*"
        exit 1
    fi
}

# Function to list timezones
list_timezones() {
    print_info "Available timezones:"
    echo
    timedatectl list-timezones
    exit 0
}

# Function to list locales
list_locales() {
    print_info "Available locales:"
    echo
    locale -a
    exit 0
}

# Function to get current timezone
get_current_timezone() {
    if command -v timedatectl &>/dev/null; then
        timedatectl | grep "Time zone" | awk '{print $3}'
    else
        cat /etc/timezone 2>/dev/null || echo "Unknown"
    fi
}

# Function to get current locale
get_current_locale() {
    echo "$LANG"
}

# Function to validate timezone
validate_timezone() {
    local tz=$1

    if timedatectl list-timezones | grep -q "^${tz}$"; then
        return 0
    else
        return 1
    fi
}

# Function to validate locale
validate_locale() {
    local loc=$1

    if locale -a | grep -qi "^${loc}$"; then
        return 0
    else
        # Check if locale exists but needs to be generated
        if grep -q "^# *${loc}" /etc/locale.gen 2>/dev/null; then
            return 0  # Can be generated
        fi
        return 1
    fi
}

# Function to set timezone
set_timezone() {
    local tz=$1

    print_info "Setting timezone to: $tz"

    # Validate timezone
    if ! validate_timezone "$tz"; then
        print_error "Invalid timezone: $tz"
        print_info "Use --list-timezones to see available timezones"
        exit 1
    fi

    if [ "$DRY_RUN" = false ]; then
        # Use timedatectl if available (systemd)
        if command -v timedatectl &>/dev/null; then
            timedatectl set-timezone "$tz"
            print_success "Timezone set to: $tz"
        else
            # Fallback for non-systemd systems
            echo "$tz" > /etc/timezone
            ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime
            print_success "Timezone set to: $tz (non-systemd method)"
        fi

        # Verify
        local new_tz
        new_tz=$(get_current_timezone)
        print_info "Current timezone: $new_tz"
        print_info "Current time: $(date)"
    else
        print_info "[DRY RUN] Would set timezone to: $tz"
        print_info "[DRY RUN] Current timezone: $(get_current_timezone)"
    fi
}

# Function to set locale
set_locale() {
    local loc=$1

    print_info "Setting locale to: $loc"

    # Validate locale
    if ! validate_locale "$loc"; then
        print_error "Locale not available: $loc"
        print_info "Use --list-locales to see available locales"
        exit 1
    fi

    if [ "$DRY_RUN" = false ]; then
        # Generate locale if needed
        if ! locale -a | grep -qi "^${loc}$"; then
            print_info "Generating locale: $loc"

            # Uncomment locale in locale.gen
            if [ -f /etc/locale.gen ]; then
                sed -i "s/^# *${loc}/${loc}/" /etc/locale.gen
                locale-gen
            fi
        fi

        # Set as default locale
        if command -v update-locale &>/dev/null; then
            update-locale LANG="$loc"
            print_success "Locale set to: $loc"
        else
            # Fallback method
            cat > /etc/default/locale << EOF
LANG=$loc
LANGUAGE=$loc
LC_ALL=$loc
EOF
            print_success "Locale set to: $loc (manual method)"
        fi

        print_info "Current locale: $(get_current_locale)"
        print_warning "Logout and login again for locale changes to take full effect"
    else
        print_info "[DRY RUN] Would set locale to: $loc"
        print_info "[DRY RUN] Current locale: $(get_current_locale)"
    fi
}

# Function to enable NTP
enable_ntp() {
    print_info "Enabling NTP time synchronization"

    if [ "$DRY_RUN" = false ]; then
        if command -v timedatectl &>/dev/null; then
            timedatectl set-ntp true
            print_success "NTP synchronization enabled"

            # Wait a moment and check status
            sleep 2
            if timedatectl | grep -q "NTP.*yes"; then
                print_success "NTP is active"
            else
                print_warning "NTP may not be working properly"
            fi
        else
            # Install and enable NTP service
            print_info "Installing NTP service..."
            if command -v apt-get &>/dev/null; then
                apt-get update -qq
                apt-get install -y -qq ntp
                systemctl enable ntp
                systemctl start ntp
                print_success "NTP service installed and started"
            else
                print_warning "Cannot automatically install NTP on this system"
                print_info "Please install NTP manually: sudo apt install ntp"
            fi
        fi
    else
        print_info "[DRY RUN] Would enable NTP synchronization"
    fi
}

# Function to sync hardware clock
sync_hardware_clock() {
    print_info "Synchronizing hardware clock with system time"

    if [ "$DRY_RUN" = false ]; then
        if command -v hwclock &>/dev/null; then
            hwclock --systohc
            print_success "Hardware clock synchronized"
        else
            print_warning "hwclock command not available"
        fi
    else
        print_info "[DRY RUN] Would synchronize hardware clock"
    fi
}

# Function for interactive mode
interactive_mode() {
    print_info "Interactive Timezone and Locale Configuration"
    echo

    # Current settings
    echo "Current Settings:"
    echo "  Timezone: $(get_current_timezone)"
    echo "  Locale: $(get_current_locale)"
    echo "  Time: $(date)"
    echo

    # Timezone selection
    read -p "Do you want to change the timezone? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        echo "Popular timezones:"
        echo "  1) UTC"
        echo "  2) America/New_York"
        echo "  3) America/Chicago"
        echo "  4) America/Denver"
        echo "  5) America/Los_Angeles"
        echo "  6) Europe/London"
        echo "  7) Europe/Paris"
        echo "  8) Asia/Tokyo"
        echo "  9) Custom (type manually)"
        echo
        read -p "Select timezone (1-9): " tz_choice

        case $tz_choice in
            1) TIMEZONE="UTC" ;;
            2) TIMEZONE="America/New_York" ;;
            3) TIMEZONE="America/Chicago" ;;
            4) TIMEZONE="America/Denver" ;;
            5) TIMEZONE="America/Los_Angeles" ;;
            6) TIMEZONE="Europe/London" ;;
            7) TIMEZONE="Europe/Paris" ;;
            8) TIMEZONE="Asia/Tokyo" ;;
            9)
                read -p "Enter timezone: " TIMEZONE
                ;;
            *)
                print_warning "Invalid selection, skipping timezone change"
                TIMEZONE=""
                ;;
        esac

        if [ -n "$TIMEZONE" ]; then
            set_timezone "$TIMEZONE"
        fi
    fi

    echo

    # Locale selection
    read -p "Do you want to change the locale? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        echo "Common locales:"
        echo "  1) en_US.UTF-8"
        echo "  2) en_GB.UTF-8"
        echo "  3) de_DE.UTF-8"
        echo "  4) fr_FR.UTF-8"
        echo "  5) es_ES.UTF-8"
        echo "  6) Custom (type manually)"
        echo
        read -p "Select locale (1-6): " loc_choice

        case $loc_choice in
            1) LOCALE="en_US.UTF-8" ;;
            2) LOCALE="en_GB.UTF-8" ;;
            3) LOCALE="de_DE.UTF-8" ;;
            4) LOCALE="fr_FR.UTF-8" ;;
            5) LOCALE="es_ES.UTF-8" ;;
            6)
                read -p "Enter locale: " LOCALE
                ;;
            *)
                print_warning "Invalid selection, skipping locale change"
                LOCALE=""
                ;;
        esac

        if [ -n "$LOCALE" ]; then
            set_locale "$LOCALE"
        fi
    fi

    echo

    # NTP
    read -p "Do you want to enable NTP time synchronization? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        enable_ntp
    fi

    echo

    # Hardware clock
    read -p "Do you want to sync the hardware clock? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sync_hardware_clock
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --timezone)
            TIMEZONE="$2"
            shift 2
            ;;
        --locale)
            LOCALE="$2"
            shift 2
            ;;
        --enable-ntp)
            NTP_ENABLED=true
            shift
            ;;
        --set-hwclock)
            SET_HARDWARE_CLOCK=true
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --list-timezones)
            list_timezones
            ;;
        --list-locales)
            list_locales
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
    print_info "Timezone and Locale Configuration Tool"
    echo

    # Check root
    check_root "$@"

    # Show current settings
    if [ "$VERBOSE" = true ]; then
        print_info "Current timezone: $(get_current_timezone)"
        print_info "Current locale: $(get_current_locale)"
        print_info "Current time: $(date)"
        echo
    fi

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN MODE - No changes will be made"
        echo
    fi

    # Interactive mode
    if [ "$INTERACTIVE" = true ]; then
        interactive_mode
    else
        # Non-interactive mode
        if [ -z "$TIMEZONE" ] && [ -z "$LOCALE" ] && [ "$NTP_ENABLED" = false ] && [ "$SET_HARDWARE_CLOCK" = false ]; then
            print_error "No options specified"
            echo
            show_help
            exit 1
        fi

        # Set timezone
        if [ -n "$TIMEZONE" ]; then
            set_timezone "$TIMEZONE"
            echo
        fi

        # Set locale
        if [ -n "$LOCALE" ]; then
            set_locale "$LOCALE"
            echo
        fi

        # Enable NTP
        if [ "$NTP_ENABLED" = true ]; then
            enable_ntp
            echo
        fi

        # Sync hardware clock
        if [ "$SET_HARDWARE_CLOCK" = true ]; then
            sync_hardware_clock
            echo
        fi
    fi

    print_success "Configuration complete!"

    # Show final settings
    if [ "$DRY_RUN" = false ]; then
        echo
        print_info "Final settings:"
        echo "  Timezone: $(get_current_timezone)"
        echo "  Locale: $(get_current_locale)"
        echo "  Current time: $(date)"

        if command -v timedatectl &>/dev/null; then
            echo
            timedatectl status
        fi
    fi
}

main

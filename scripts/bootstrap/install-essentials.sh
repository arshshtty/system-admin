#!/usr/bin/env bash

#############################################################################
# install-essentials.sh
#
# Comprehensive setup script for Ubuntu/Debian servers
# Installs development tools, modern CLI utilities, Docker, shells, and more
#
# Usage:
#   ./install-essentials.sh [options]
#
# Options:
#   --all           Install everything (default)
#   --core          Only core tools (git, curl, vim, etc.)
#   --docker        Docker Engine + Compose (rootless)
#   --shell         Zsh + oh-my-zsh + plugins
#   --languages     Node.js, Python tooling
#   --modern-cli    Modern CLI tools (bat, exa, fd, etc.)
#   --dotfiles      Setup dotfiles
#   --help          Show this help message
#
#############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DOTFILES_DIR="${HOME}/.dotfiles"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Installation flags
INSTALL_ALL=false
INSTALL_CORE=false
INSTALL_DOCKER=false
INSTALL_SHELL=false
INSTALL_LANGUAGES=false
INSTALL_MODERN_CLI=false
INSTALL_DOTFILES=false

#############################################################################
# Helper Functions
#############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_debian_based() {
    [ -f /etc/debian_version ]
}

show_help() {
    grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# \?//'
    exit 0
}

#############################################################################
# Installation Functions
#############################################################################

install_core_tools() {
    log_info "Installing core tools..."

    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        curl \
        wget \
        git \
        vim \
        htop \
        tmux \
        ncdu \
        tree \
        jq \
        unzip \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common \
        apt-transport-https \
        openssh-server \
        net-tools \
        dnsutils \
        rsync \
        zip

    log_success "Core tools installed"
}

install_docker() {
    log_info "Installing Docker Engine + Compose..."

    if command_exists docker; then
        log_warn "Docker already installed, skipping..."
        return
    fi

    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install Docker GPG key and repository
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Add current user to docker group
    sudo usermod -aG docker "$USER" || true

    log_success "Docker installed"

    # Setup rootless Docker
    log_info "Setting up rootless Docker..."

    # Install uidmap if not present
    sudo apt-get install -y uidmap dbus-user-session

    # Disable system Docker daemon for rootless setup
    sudo systemctl disable --now docker.service docker.socket || true

    # Install rootless Docker
    if ! command_exists dockerd-rootless-setuptool.sh; then
        log_warn "Rootless Docker tools not found in PATH, installing..."
    fi

    # Run rootless setup
    if ! dockerd-rootless-setuptool.sh check 2>/dev/null; then
        log_info "Installing rootless Docker prerequisites..."
        dockerd-rootless-setuptool.sh install || log_warn "Rootless Docker setup may require logout/login"
    fi

    log_success "Docker rootless setup complete (may require logout/login to take effect)"
    log_info "To enable Docker rootless: systemctl --user enable --now docker"
}

install_shell_environment() {
    log_info "Installing Zsh and oh-my-zsh..."

    # Install Zsh
    sudo apt-get install -y zsh

    # Install oh-my-zsh
    if [ ! -d "${HOME}/.oh-my-zsh" ]; then
        log_info "Installing oh-my-zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        log_warn "oh-my-zsh already installed, skipping..."
    fi

    # Install zsh-autosuggestions
    local ZSH_CUSTOM="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"

    if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-autosuggestions" ]; then
        log_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
    fi

    # Install zsh-syntax-highlighting
    if [ ! -d "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting" ]; then
        log_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"
    fi

    # Install fzf
    if [ ! -d "${HOME}/.fzf" ]; then
        log_info "Installing fzf..."
        git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf"
        "${HOME}/.fzf/install" --all --no-bash --no-fish
    else
        log_warn "fzf already installed, skipping..."
    fi

    # Change default shell to zsh
    if [ "$SHELL" != "$(which zsh)" ]; then
        log_info "Changing default shell to zsh..."
        sudo chsh -s "$(which zsh)" "$USER" || log_warn "Could not change default shell, run: chsh -s \$(which zsh)"
    fi

    log_success "Shell environment installed"
}

install_language_tools() {
    log_info "Installing language tools (Node.js, Python)..."

    # Install Node.js via nvm
    if [ ! -d "${HOME}/.nvm" ]; then
        log_info "Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

        # Load nvm
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        # Install latest LTS Node.js
        log_info "Installing Node.js LTS..."
        nvm install --lts
        nvm use --lts
        nvm alias default 'lts/*'
    else
        log_warn "nvm already installed, skipping..."
    fi

    # Install Python3 and tools
    log_info "Installing Python3 and tools..."
    sudo apt-get install -y python3 python3-pip python3-venv

    # Install pipx
    if ! command_exists pipx; then
        log_info "Installing pipx..."
        python3 -m pip install --user pipx
        python3 -m pipx ensurepath
    fi

    # Install uv (fast Python package installer)
    if ! command_exists uv; then
        log_info "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi

    log_success "Language tools installed"
}

install_modern_cli_tools() {
    log_info "Installing modern CLI tools..."

    # bat (better cat)
    if ! command_exists bat; then
        log_info "Installing bat..."
        sudo apt-get install -y bat
        # Create symlink if batcat is installed instead of bat
        if command_exists batcat && ! command_exists bat; then
            mkdir -p "${HOME}/.local/bin"
            ln -sf /usr/bin/batcat "${HOME}/.local/bin/bat"
        fi
    fi

    # exa (better ls)
    if ! command_exists exa; then
        log_info "Installing exa..."
        # exa is not in default repos, install from GitHub releases
        EXA_VERSION="0.10.1"
        wget -q "https://github.com/ogham/exa/releases/download/v${EXA_VERSION}/exa-linux-x86_64-v${EXA_VERSION}.zip" -O /tmp/exa.zip
        sudo unzip -q /tmp/exa.zip -d /usr/local/bin/
        sudo chmod +x /usr/local/bin/exa
        rm /tmp/exa.zip
    fi

    # fd (better find)
    if ! command_exists fd; then
        log_info "Installing fd..."
        sudo apt-get install -y fd-find
        # Create symlink if fdfind is installed instead of fd
        if command_exists fdfind && ! command_exists fd; then
            mkdir -p "${HOME}/.local/bin"
            ln -sf /usr/bin/fdfind "${HOME}/.local/bin/fd"
        fi
    fi

    # ripgrep (better grep) - useful companion tool
    if ! command_exists rg; then
        log_info "Installing ripgrep..."
        sudo apt-get install -y ripgrep
    fi

    # lazydocker
    if ! command_exists lazydocker; then
        log_info "Installing lazydocker..."
        curl -sSL https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash
    fi

    # lazygit
    if ! command_exists lazygit; then
        log_info "Installing lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin
        rm lazygit lazygit.tar.gz
    fi

    log_success "Modern CLI tools installed"
}

install_dotfiles() {
    log_info "Setting up dotfiles..."

    local DOTFILES_SOURCE="${REPO_ROOT}/dotfiles"

    # Backup existing dotfiles
    for file in .zshrc .vimrc .gitconfig .tmux.conf; do
        if [ -f "${HOME}/${file}" ]; then
            log_info "Backing up existing ${file} to ${file}.backup"
            mv "${HOME}/${file}" "${HOME}/${file}.backup"
        fi
    done

    # Symlink dotfiles
    if [ -f "${DOTFILES_SOURCE}/.zshrc" ]; then
        ln -sf "${DOTFILES_SOURCE}/.zshrc" "${HOME}/.zshrc"
        log_info "Linked .zshrc"
    fi

    if [ -f "${DOTFILES_SOURCE}/.vimrc" ]; then
        ln -sf "${DOTFILES_SOURCE}/.vimrc" "${HOME}/.vimrc"
        log_info "Linked .vimrc"
    fi

    if [ -f "${DOTFILES_SOURCE}/.gitconfig" ]; then
        # Don't overwrite gitconfig, copy it as template
        if [ ! -f "${HOME}/.gitconfig" ]; then
            cp "${DOTFILES_SOURCE}/.gitconfig" "${HOME}/.gitconfig"
            log_info "Copied .gitconfig template (edit with your details)"
        fi
    fi

    if [ -f "${DOTFILES_SOURCE}/.tmux.conf" ]; then
        ln -sf "${DOTFILES_SOURCE}/.tmux.conf" "${HOME}/.tmux.conf"
        log_info "Linked .tmux.conf"
    fi

    log_success "Dotfiles installed"
}

#############################################################################
# Main Execution
#############################################################################

main() {
    # Check if running on Debian/Ubuntu
    if ! is_debian_based; then
        log_error "This script only supports Debian/Ubuntu systems"
        exit 1
    fi

    # Parse arguments
    if [ $# -eq 0 ]; then
        INSTALL_ALL=true
    else
        while [[ $# -gt 0 ]]; do
            case $1 in
                --all)
                    INSTALL_ALL=true
                    shift
                    ;;
                --core)
                    INSTALL_CORE=true
                    shift
                    ;;
                --docker)
                    INSTALL_DOCKER=true
                    shift
                    ;;
                --shell)
                    INSTALL_SHELL=true
                    shift
                    ;;
                --languages)
                    INSTALL_LANGUAGES=true
                    shift
                    ;;
                --modern-cli)
                    INSTALL_MODERN_CLI=true
                    shift
                    ;;
                --dotfiles)
                    INSTALL_DOTFILES=true
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
    fi

    # If --all is set, enable everything
    if [ "$INSTALL_ALL" = true ]; then
        INSTALL_CORE=true
        INSTALL_DOCKER=true
        INSTALL_SHELL=true
        INSTALL_LANGUAGES=true
        INSTALL_MODERN_CLI=true
        INSTALL_DOTFILES=true
    fi

    log_info "Starting installation..."
    log_info "This may take several minutes..."
    echo ""

    # Run installations in order
    [ "$INSTALL_CORE" = true ] && install_core_tools
    [ "$INSTALL_DOCKER" = true ] && install_docker
    [ "$INSTALL_SHELL" = true ] && install_shell_environment
    [ "$INSTALL_LANGUAGES" = true ] && install_language_tools
    [ "$INSTALL_MODERN_CLI" = true ] && install_modern_cli_tools
    [ "$INSTALL_DOTFILES" = true ] && install_dotfiles

    echo ""
    log_success "Installation complete!"
    echo ""
    log_info "Next steps:"
    echo "  1. Logout and login again (or run: exec zsh)"
    echo "  2. For Docker rootless: systemctl --user enable --now docker"
    echo "  3. For nvm/node: source ~/.zshrc or restart terminal"
    echo "  4. Edit ~/.gitconfig with your name and email"
    echo ""
}

main "$@"

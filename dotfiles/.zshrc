# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    docker
    docker-compose
    node
    npm
    python
    pip
    sudo
    colored-man-pages
    command-not-found
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

#############################################################################
# Personal Aliases
#############################################################################

# Modern CLI tool aliases
if command -v exa &> /dev/null; then
    alias ls='exa'
    alias ll='exa -l'
    alias la='exa -la'
    alias lt='exa --tree'
else
    alias ll='ls -lh'
    alias la='ls -lah'
fi

if command -v bat &> /dev/null; then
    alias cat='bat'
fi

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'

# Lazy tools
alias lzd='lazydocker'
alias lzg='lazygit'

# Docker aliases
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'

# System aliases
alias update='sudo apt update && sudo apt upgrade -y'
alias cleanup='sudo apt autoremove -y && sudo apt autoclean'
alias ports='sudo netstat -tulpn'
alias myip='curl -s ifconfig.me'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# Utilities
alias h='history'
alias hgrep='history | grep'
alias pgrep='ps aux | grep'
alias mkdir='mkdir -pv'
alias wget='wget -c'
alias df='df -h'
alias du='du -h'
alias free='free -h'

#############################################################################
# Environment Variables
#############################################################################

# Add local bin to PATH
export PATH="$HOME/.local/bin:$PATH"

# NVM configuration
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Python pipx configuration
export PATH="$HOME/.local/bin:$PATH"

# uv configuration
if [ -d "$HOME/.cargo/bin" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# Rust cargo (often installed with uv)
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# Go configuration (if you install it later)
export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

#############################################################################
# FZF Configuration
#############################################################################

# Source fzf keybindings and completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# FZF settings
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# Use fd instead of find for fzf if available
if command -v fd &> /dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

#############################################################################
# Custom Functions
#############################################################################

# Create a directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Extract various archive types
extract() {
    if [ -f "$1" ] ; then
        case $1 in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Find a file by name
ff() {
    if command -v fd &> /dev/null; then
        fd "$1"
    else
        find . -type f -name "$1"
    fi
}

# Search for text in files
search() {
    if command -v rg &> /dev/null; then
        rg "$1"
    else
        grep -r "$1" .
    fi
}

# Docker cleanup
docker-cleanup() {
    docker system prune -af --volumes
}

# Show disk usage of current directory
dush() {
    du -sh * | sort -hr | head -n ${1:-10}
}

#############################################################################
# Starship Prompt (optional - uncomment to use)
#############################################################################
# If you prefer starship prompt over oh-my-zsh themes:
# eval "$(starship init zsh)"

#############################################################################
# Local customizations
#############################################################################
# Source local zshrc if it exists (for machine-specific configurations)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

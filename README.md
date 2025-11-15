# System Admin Toolkit

A comprehensive collection of scripts, configurations, and tools for managing home servers, bare metal machines, and VPS instances.

## Overview

This repository provides ready-to-use automation scripts for:
- **Server bootstrapping** - Get new servers production-ready in minutes
- **Development environment setup** - Install essential tools and productivity software
- **Monitoring & health checks** - Keep track of your infrastructure
- **Backup & recovery** - Protect your data
- **Security hardening** - Follow best practices
- **Docker management** - Container orchestration and cleanup
- **Batch operations** - Manage multiple servers efficiently

## Quick Start

### Clone the Repository

```bash
git clone https://github.com/arshshtty/system-admin.git
cd system-admin
```

### Install Essential Tools

The fastest way to set up a new server with all essential development tools:

```bash
# Install everything (recommended for first-time setup)
./scripts/bootstrap/install-essentials.sh

# Or install specific components
./scripts/bootstrap/install-essentials.sh --core --docker --shell
```

This will install:
- **Core tools**: git, vim, tmux, htop, ncdu, jq, etc.
- **Docker**: Docker Engine + Compose (with rootless setup)
- **Shell**: Zsh + oh-my-zsh with plugins (autosuggestions, syntax-highlighting, fzf)
- **Languages**: Node.js (via nvm), Python3, pip, pipx, uv
- **Modern CLI tools**: bat, exa, fd, ripgrep, lazydocker, lazygit
- **Dotfiles**: Pre-configured .zshrc, .vimrc, .gitconfig, .tmux.conf

### Available Options

```bash
./scripts/bootstrap/install-essentials.sh [options]

Options:
  --all           Install everything (default)
  --core          Only core tools (git, curl, vim, etc.)
  --docker        Docker Engine + Compose (rootless)
  --shell         Zsh + oh-my-zsh + plugins
  --languages     Node.js, Python tooling
  --modern-cli    Modern CLI tools (bat, exa, fd, etc.)
  --dotfiles      Setup dotfiles
  --help          Show help message
```

## Repository Structure

```
system-admin/
├── scripts/
│   ├── bootstrap/          # Initial server setup scripts
│   │   └── install-essentials.sh
│   ├── monitoring/         # Health checks and monitoring
│   ├── backup/            # Backup and recovery scripts
│   ├── security/          # Security hardening tools
│   ├── docker/            # Docker management scripts
│   └── utils/             # Utility scripts
├── configs/
│   ├── templates/         # Configuration templates
│   └── examples/          # Example configurations
├── dotfiles/              # Dotfiles for development
│   ├── .zshrc
│   ├── .vimrc
│   ├── .gitconfig
│   └── .tmux.conf
├── ansible/               # Ansible playbooks (future)
├── terraform/             # Infrastructure as Code (future)
├── runbooks/              # Operational runbooks
├── inventory/             # Server inventory files
└── docs/                  # Documentation
```

## Detailed Guide

### Post-Installation Steps

After running the installation script:

1. **Logout and login again** (or run `exec zsh`) to apply shell changes
2. **Configure Git** with your details:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```
3. **Enable Docker rootless mode**:
   ```bash
   systemctl --user enable --now docker
   ```
4. **Verify installations**:
   ```bash
   docker --version
   node --version
   python3 --version
   ```

### Dotfiles

The repository includes starter dotfiles with sensible defaults:

#### .zshrc Features
- oh-my-zsh with curated plugins
- zsh-autosuggestions (suggest commands as you type)
- zsh-syntax-highlighting (highlight commands)
- fzf integration (fuzzy finder for files and history)
- Useful aliases for git, docker, and system management
- Modern CLI tool integration (exa, bat, fd)
- Custom functions (mkcd, extract, docker-cleanup, etc.)

#### .vimrc Features
- Syntax highlighting and line numbers
- Smart indentation for multiple languages
- Useful key mappings (space as leader key)
- Split window navigation with Ctrl+hjkl
- System clipboard integration
- Persistent undo history
- File explorer with netrw

#### .gitconfig Features
- Comprehensive git aliases for common workflows
- Better log formatting and colors
- Automatic branch setup and pruning
- Merge and rebase helpers

#### .tmux.conf Features
- Ctrl+a as prefix (more ergonomic than Ctrl+b)
- Mouse support enabled
- Vim-style pane navigation
- Better status bar with date/time
- Copy mode with vi keybindings

### Customization

Each dotfile supports local customization without modifying the originals:

- `.zshrc.local` - Machine-specific zsh configuration
- `.vimrc.local` - Machine-specific vim configuration
- `.gitconfig.local` - Machine-specific git configuration (included automatically)

Create these files to add your custom settings.

## Useful Aliases and Functions

After installation, you'll have access to these convenient aliases:

### File Operations
```bash
ls      # Uses exa with colors and icons
ll      # Long listing
la      # Show all files including hidden
lt      # Tree view
cat     # Uses bat with syntax highlighting
```

### Git Shortcuts
```bash
gs      # git status
ga      # git add
gc      # git commit
gp      # git push
gl      # git log (pretty format)
gco     # git checkout
```

### Docker
```bash
d       # docker
dc      # docker compose
dps     # docker ps
di      # docker images
lzd     # lazydocker (TUI for Docker)
```

### System Management
```bash
update  # Update all packages
cleanup # Remove unused packages
ports   # Show listening ports
myip    # Show public IP address
```

### Custom Functions
```bash
mkcd <dir>          # Create directory and cd into it
extract <file>      # Extract any archive format
ff <name>           # Find files by name (uses fd if available)
search <text>       # Search for text in files (uses ripgrep if available)
docker-cleanup      # Clean up Docker resources
dush [n]            # Show largest directories (top n, default 10)
```

## Platform Support

Currently supports:
- Ubuntu (20.04+)
- Debian (10+)

## Security Considerations

The installation script:
- ✅ Uses official package repositories
- ✅ Verifies GPG keys for Docker installation
- ✅ Sets up Docker rootless mode for better security
- ✅ Does not require sudo for most operations (except package installation)
- ✅ Backs up existing dotfiles before replacing them

## Roadmap

Future additions planned:
- [ ] Server health check script
- [ ] Multi-server inventory management
- [ ] Backup automation scripts
- [ ] Security baseline audit script
- [ ] SSL certificate management
- [ ] Monitoring stack setup (Prometheus + Grafana)
- [ ] Ansible playbooks for common tasks
- [ ] Network diagnostics and testing tools
- [ ] Database backup and restore helpers
- [ ] Log aggregation setup

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - see LICENSE file for details

## Troubleshooting

### Docker rootless setup fails
If Docker rootless setup fails, you may need to:
1. Ensure your user has a valid subuid/subgid range: `grep $USER /etc/subuid /etc/subgid`
2. Install prerequisites: `sudo apt install uidmap dbus-user-session`
3. Logout and login again
4. Run: `dockerd-rootless-setuptool.sh install`

### nvm not found after installation
This is expected. Either:
- Logout and login again
- Run: `source ~/.zshrc`
- Or: `exec zsh`

### Shell doesn't change to zsh
Run manually: `chsh -s $(which zsh)`
Then logout and login again.

### Plugins not loading in zsh
Make sure oh-my-zsh is fully installed:
```bash
ls -la ~/.oh-my-zsh
```
If missing, the script will reinstall it on next run.

## Support

For issues, questions, or suggestions:
- Create an issue in this repository
- Check existing documentation in `docs/`
- Review runbooks in `runbooks/`

---

**Happy server managing!** 🚀

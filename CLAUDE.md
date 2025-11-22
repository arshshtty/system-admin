# CLAUDE.md - AI Assistant Guide

This document provides context for AI assistants working with the System Admin Toolkit repository.

## Project Overview

**Purpose**: A comprehensive collection of scripts, configurations, and tools for managing home servers, bare metal machines, and VPS instances.

**Tech Stack**:
- Shell scripts (Bash) for automation
- Python for monitoring and web interfaces
- YAML for configuration management
- Systemd for service management

**Target Users**: System administrators, DevOps engineers, homelab enthusiasts managing one or multiple servers.

## Repository Structure

```
system-admin/
├── scripts/                    # All automation scripts
│   ├── bootstrap/              # Server setup and initialization
│   │   └── install-essentials.sh  # Main setup script for new servers
│   ├── monitoring/             # Health monitoring system
│   │   ├── health-check.py     # Metrics collector
│   │   ├── web-dashboard.py    # Web UI for monitoring
│   │   └── start-monitoring.sh # Quick start script
│   ├── backup/                 # Backup and recovery
│   │   └── backup-manager.sh   # Full-featured backup tool
│   ├── docker/                 # Docker management
│   │   └── docker-cleanup.sh   # Intelligent cleanup script
│   ├── security/               # Security hardening (planned)
│   └── utils/                  # Utility scripts
├── configs/
│   ├── templates/              # Configuration templates
│   └── examples/               # Example configurations (systemd services, etc.)
├── dotfiles/                   # Pre-configured dotfiles
│   ├── .zshrc                  # Zsh with oh-my-zsh
│   ├── .vimrc                  # Vim configuration
│   ├── .gitconfig              # Git aliases and settings
│   └── .tmux.conf              # Tmux configuration
├── inventory/                  # Server inventory files (YAML)
│   └── example.yaml            # Template for server definitions
├── requirements.txt            # Python dependencies for monitoring
└── README.md                   # User-facing documentation
```

## Core Components

### 1. Install Essentials Script (`scripts/bootstrap/install-essentials.sh`)

**Purpose**: Bootstrap new servers with essential development tools and configurations.

**What it installs**:
- Core tools: git, curl, vim, tmux, htop, ncdu, jq
- Docker Engine + Docker Compose (with rootless setup)
- Zsh + oh-my-zsh with plugins
- Node.js (via nvm), Python tooling
- Modern CLI tools: bat, exa, fd, ripgrep, lazydocker, lazygit
- Dotfiles from the repository

**Key patterns**:
- Modular installation (can install specific components)
- Idempotent (can be run multiple times safely)
- Backs up existing files before modification
- Uses official package repositories only

### 2. Health Monitoring System (`scripts/monitoring/`)

**Purpose**: Real-time multi-server health monitoring with web dashboard.

**Architecture**:
- `health-check.py`: Collects metrics from servers via SSH
- `web-dashboard.py`: Flask-based web UI to display metrics
- Data flow: SSH -> JSON files -> Web UI

**Metrics collected**:
- System: CPU, memory, disk usage, uptime, load average
- Docker: Container status and resource usage
- Services: Systemd service status

**Configuration**: Uses `inventory/servers.yaml` for server definitions

**Key features**:
- Auto-refresh dashboard
- Color-coded health indicators
- Historical data tracking
- Alert thresholds (CPU >80%, Memory >85%, Disk >85%)

### 3. Backup Manager (`scripts/backup/backup-manager.sh`)

**Purpose**: Comprehensive backup solution for files, databases, and Docker volumes.

**Supports**:
- Backup types: files, MySQL/PostgreSQL databases, Docker volumes
- Destinations: local, remote (rsync), S3-compatible storage
- Retention policies: daily, weekly, monthly
- Verification: SHA256 checksums

**Key patterns**:
- Dry-run mode for testing
- Restore capability
- Configurable via script variables

### 4. Docker Cleanup (`scripts/docker/docker-cleanup.sh`)

**Purpose**: Intelligent cleanup of Docker resources with safety features.

**Features**:
- Clean containers, images, volumes, networks
- Retention policies (keep items from last N days)
- Dry-run mode
- Disk usage reporting
- Safe confirmation prompts
- Cron scheduling support

## Development Guidelines

### Shell Scripts

**Standards**:
- Use `#!/usr/bin/env bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use long-form flags for readability: `--verbose` over `-v`
- Add help text with `--help` flag
- Include dry-run mode for destructive operations
- Use colors for output (red for errors, green for success, yellow for warnings)

**Error handling**:
```bash
if ! command; then
    echo "ERROR: command failed" >&2
    exit 1
fi
```

**User confirmations**:
```bash
read -p "Are you sure? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi
```

### Python Scripts

**Standards**:
- Use Python 3.8+ features
- Follow PEP 8 style guide
- Include argument parsing with `argparse`
- Use type hints where appropriate
- Add logging for debugging

**Dependencies**:
- Keep dependencies minimal
- List in `requirements.txt`
- Use standard library when possible

### Configuration Files

**YAML format** for server inventory:
```yaml
servers:
  group_name:
    - name: server-name
      ip: 192.168.1.100
      ssh_user: username
      type: bare-metal | vps
      tags:
        - tag1
        - tag2
```

### Dotfiles

**Principles**:
- Include sensible defaults
- Support local customization via `.*.local` files
- Document key mappings and aliases
- Cross-platform compatibility where possible

## Common Tasks

### Adding a New Script

1. Choose appropriate directory under `scripts/`
2. Create script with proper shebang and strict mode
3. Add help text and argument parsing
4. Include dry-run mode for destructive operations
5. Test on clean system
6. Document in README.md

### Adding Monitoring Metrics

1. Edit `health-check.py` to collect new metric
2. Update JSON output structure
3. Modify `web-dashboard.py` to display new metric
4. Update thresholds if needed
5. Test with multiple servers

### Modifying Dotfiles

1. Edit file in `dotfiles/` directory
2. Test changes locally
3. Ensure backward compatibility
4. Document new features or aliases
5. Consider impact on existing users

### Adding Dependencies

**Shell scripts**:
- Check if tool is available before use
- Provide installation instructions in comments
- Consider adding to `install-essentials.sh`

**Python scripts**:
- Add to `requirements.txt`
- Update installation documentation
- Pin versions for stability

## Testing Guidelines

### Shell Scripts

**Manual testing checklist**:
- Run with `--help` to verify help text
- Test with invalid arguments
- Test dry-run mode
- Test actual execution
- Verify idempotency (run twice)
- Test on fresh system if possible

**Edge cases to test**:
- Missing dependencies
- Missing configuration files
- Invalid permissions
- Network failures
- Disk space issues

### Python Scripts

**Testing approach**:
- Test with various server configurations
- Test SSH connection failures
- Test with missing data
- Test web UI in different browsers
- Verify JSON output format

## Important Patterns

### Idempotency

Scripts should be safe to run multiple times:
```bash
# Good: Check before creating
if [ ! -d "$DIR" ]; then
    mkdir -p "$DIR"
fi

# Good: Backup before overwriting
if [ -f "$FILE" ]; then
    cp "$FILE" "$FILE.backup"
fi
```

### Safe Defaults

- Require explicit flags for destructive operations
- Default to dry-run mode when possible
- Ask for confirmation before major changes
- Provide clear output about what will happen

### Configuration

- Use environment variables for customization
- Provide example configurations
- Document all configuration options
- Use sane defaults

### Output

- Use consistent formatting
- Color-code: red (errors), yellow (warnings), green (success), blue (info)
- Include timestamps for long-running operations
- Provide progress indicators

## Security Considerations

### Best Practices

- Never commit secrets or credentials
- Use SSH keys, not passwords
- Implement least-privilege principle
- Validate all user inputs
- Use official package repositories
- Verify checksums and signatures

### Docker Security

- Prefer rootless Docker
- Don't run containers as root unnecessarily
- Keep images updated
- Use specific image tags, not `latest`

### SSH Operations

- Use key-based authentication
- Configure SSH properly in inventory
- Handle connection failures gracefully
- Don't log sensitive information

## Common Pitfalls

1. **Not testing on clean systems**: Scripts might work with your setup but fail elsewhere
2. **Assuming tools exist**: Always check for dependencies
3. **Hardcoded paths**: Use variables and make paths configurable
4. **No error handling**: Always handle failures gracefully
5. **Missing backups**: Back up before modifying system files
6. **Ignoring platform differences**: Test on Ubuntu and Debian

## Useful Commands

### Development

```bash
# Test a shell script
bash -n script.sh                    # Syntax check
shellcheck script.sh                 # Linting

# Test monitoring system locally
python3 scripts/monitoring/health-check.py --config inventory/example.yaml --once

# Run backup in dry-run mode
./scripts/backup/backup-manager.sh --dry-run

# Clean Docker safely
./scripts/docker/docker-cleanup.sh --all --dry-run
```

### Debugging

```bash
# Run script with debug output
bash -x script.sh

# Check systemd service logs
journalctl -u service-name -f

# Monitor Python script output
tail -f /tmp/health-monitor/*.json
```

## Future Enhancements

Planned additions:
- Security baseline audit script
- SSL certificate management
- Prometheus + Grafana setup automation
- Ansible playbooks
- Network diagnostics tools
- Log aggregation setup
- Automated security updates
- Container orchestration helpers

## Working with Claude Code

### When Modifying Scripts

1. Read the entire script first to understand context
2. Maintain existing code style and patterns
3. Test changes in dry-run mode when available
4. Update documentation if behavior changes
5. Consider backward compatibility

### When Adding Features

1. Check if similar functionality exists
2. Follow existing patterns and conventions
3. Add appropriate error handling
4. Include help text and documentation
5. Test thoroughly before committing

### When Debugging

1. Check script exit codes
2. Review logs and error messages
3. Test with verbose/debug flags
4. Verify dependencies are installed
5. Check file permissions and paths

## Questions to Ask

Before implementing changes, consider:

1. **Scope**: Does this fit the project's purpose?
2. **Compatibility**: Will this work on Ubuntu and Debian?
3. **Dependencies**: Are new dependencies necessary?
4. **Safety**: Is this safe to run on production servers?
5. **Idempotency**: Can this be run multiple times safely?
6. **Documentation**: Is this adequately documented?
7. **Testing**: How can this be tested safely?

## Support Resources

- Main documentation: `README.md`
- Example configurations: `configs/examples/`
- Server inventory template: `inventory/example.yaml`
- Platform: Linux (Ubuntu 20.04+, Debian 10+)
- Repository: https://github.com/arshshtty/system-admin

---

**Last Updated**: 2025-11-22

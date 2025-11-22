# Ansible Playbooks

This directory contains Ansible playbooks for automating common server management tasks.

## Prerequisites

```bash
# Install Ansible
sudo apt update
sudo apt install ansible

# Or with pip
pip install ansible
```

## Directory Structure

```
ansible/
├── playbooks/          # Playbook files
├── roles/              # Ansible roles
├── inventories/        # Inventory files
└── README.md           # This file
```

## Available Playbooks

### 1. Server Setup (`playbooks/server-setup.yml`)
Sets up a new server with essential packages and configuration.

```bash
ansible-playbook -i inventories/hosts.yml playbooks/server-setup.yml
```

### 2. Security Hardening (`playbooks/security-hardening.yml`)
Applies security best practices to servers.

```bash
ansible-playbook -i inventories/hosts.yml playbooks/security-hardening.yml
```

### 3. Docker Installation (`playbooks/install-docker.yml`)
Installs Docker and Docker Compose on target servers.

```bash
ansible-playbook -i inventories/hosts.yml playbooks/install-docker.yml
```

### 4. Update All Servers (`playbooks/update-servers.yml`)
Updates all packages on target servers.

```bash
ansible-playbook -i inventories/hosts.yml playbooks/update-servers.yml
```

## Quick Start

1. **Create your inventory file**:
```bash
cp inventories/hosts.example.yml inventories/hosts.yml
# Edit with your server details
```

2. **Test connectivity**:
```bash
ansible all -i inventories/hosts.yml -m ping
```

3. **Run a playbook**:
```bash
ansible-playbook -i inventories/hosts.yml playbooks/server-setup.yml
```

## Inventory File Format

```yaml
all:
  children:
    webservers:
      hosts:
        web1:
          ansible_host: 192.168.1.10
          ansible_user: admin
        web2:
          ansible_host: 192.168.1.11
          ansible_user: admin

    databases:
      hosts:
        db1:
          ansible_host: 192.168.1.20
          ansible_user: admin
```

## Common Options

```bash
# Check mode (dry run)
ansible-playbook playbook.yml --check

# Limit to specific hosts
ansible-playbook playbook.yml --limit webservers

# Use specific user
ansible-playbook playbook.yml --user admin

# Ask for sudo password
ansible-playbook playbook.yml --ask-become-pass

# Verbose output
ansible-playbook playbook.yml -v
```

## Tips

1. Always test playbooks with `--check` first
2. Use `--limit` to target specific hosts
3. Keep sensitive data in Ansible Vault
4. Use tags to run specific tasks
5. Document your playbooks and roles

## Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Galaxy](https://galaxy.ansible.com/) - Community roles
- [Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

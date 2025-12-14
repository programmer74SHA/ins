# Usage Examples with main_inventory.yml

This directory contains example playbooks and inventory for the nvidia-gpu-setup role.

## Files

- `main_inventory.yml` - Main inventory file (YAML format)
- `playbook_interactive.yml` - Interactive driver selection
- `playbook_auto_recommended.yml` - Auto-install recommended driver
- `playbook_specific_driver.yml` - Install specific driver version
- `playbook_multi_server.yml` - Multi-server deployment

---

## Quick Start

### 1. Update Inventory

Edit `main_inventory.yml` and update with your server details:

```yaml
all:
  children:
    gpu_servers:
      hosts:
        gpu-server-01:
          ansible_host: 172.25.7.99    # Your server IP
          ansible_user: root            # Your SSH user
```

### 2. Test Connection

```bash
ansible -i main_inventory.yml gpu_servers -m ping
```

### 3. Run a Playbook

```bash
# Interactive mode
ansible-playbook -i main_inventory.yml playbook_interactive.yml

# Auto-install recommended driver
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml

# Multi-server deployment
ansible-playbook -i main_inventory.yml playbook_multi_server.yml
```

---

## Inventory Configuration

### Basic Configuration

The inventory includes default variables for all GPU servers:

```yaml
gpu_servers:
  vars:
    # Ansible connection settings
    ansible_python_interpreter: /usr/bin/python3
    ansible_become: yes
    
    # NVIDIA driver settings
    nvidia_driver_interactive: false          # Set to true for interactive selection
    nvidia_driver_version: ""                 # Empty = recommended, or specify version
    nvidia_install_cuda: true                 # Install CUDA toolkit
    nvidia_enable_persistence: true           # Enable persistence mode
    nvidia_reboot_after_install: true         # Auto-reboot after installation
```

### Per-Host Configuration

You can override settings per host:

```yaml
gpu_servers:
  hosts:
    gpu-server-01:
      ansible_host: 172.25.7.99
      ansible_user: root
      nvidia_driver_version: "nvidia-driver-580-open"  # Specific driver for this host
    
    gpu-server-02:
      ansible_host: 172.25.7.100
      ansible_user: ubuntu
      nvidia_install_cuda: false  # Don't install CUDA on this host
```

### Multiple Environments

Separate development and production:

```yaml
all:
  children:
    gpu_servers:
      children:
        production:
          hosts:
            gpu-prod-01:
              ansible_host: 172.25.7.99
          vars:
            nvidia_reboot_after_install: true
            
        development:
          hosts:
            gpu-dev-01:
              ansible_host: 172.25.7.200
          vars:
            nvidia_driver_interactive: true
            nvidia_reboot_after_install: false
```

Run specific environment:
```bash
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml --limit production
ansible-playbook -i main_inventory.yml playbook_interactive.yml --limit development
```

---

## Example Commands

### Run on All GPU Servers

```bash
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml
```

### Run on Specific Server

```bash
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml --limit gpu-server-01
```

### Run on Multiple Specific Servers

```bash
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml --limit "gpu-server-01,gpu-server-02"
```

### Override Variables

```bash
# Override driver version
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml \
  -e "nvidia_driver_version=nvidia-driver-550-server"

# Disable CUDA installation
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml \
  -e "nvidia_install_cuda=false"

# Disable auto-reboot
ansible-playbook -i main_inventory.yml playbook_multi_server.yml \
  -e "nvidia_reboot_after_install=false"
```

### Check Mode (Dry Run)

```bash
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml --check
```

### Verbose Output

```bash
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml -vvv
```

---

## Inventory Variables Reference

### Connection Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `ansible_host` | IP address or hostname | `172.25.7.99` |
| `ansible_user` | SSH user | `root` or `ubuntu` |
| `ansible_become` | Use sudo | `yes` |
| `ansible_python_interpreter` | Python path | `/usr/bin/python3` |
| `ansible_port` | SSH port | `22` (default) |
| `ansible_ssh_private_key_file` | SSH key path | `~/.ssh/id_rsa` |

### NVIDIA Driver Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `nvidia_driver_interactive` | Prompt for driver selection | `true` | `false` |
| `nvidia_driver_version` | Specific driver version | `""` (recommended) | `nvidia-driver-580-open` |
| `nvidia_install_cuda` | Install CUDA toolkit | `true` | `false` |
| `nvidia_enable_persistence` | Enable persistence mode | `true` | `false` |
| `nvidia_reboot_after_install` | Auto-reboot | `false` | `true` |
| `nvidia_reboot_timeout` | Reboot timeout (seconds) | `600` | `300` |

---

## Complete Example Inventory

```yaml
---
# Complete GPU Infrastructure Inventory

all:
  children:
    # Production GPU Servers
    gpu_production:
      hosts:
        gpu-prod-01:
          ansible_host: 172.25.7.99
          ansible_user: root
        gpu-prod-02:
          ansible_host: 172.25.7.100
          ansible_user: root
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: yes
        app_environment: production
        nvidia_driver_interactive: false
        nvidia_driver_version: ""  # Recommended
        nvidia_install_cuda: true
        nvidia_enable_persistence: true
        nvidia_reboot_after_install: true

    # Development GPU Servers
    gpu_development:
      hosts:
        gpu-dev-01:
          ansible_host: 172.25.7.200
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/dev_key
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: yes
        app_environment: development
        nvidia_driver_interactive: true  # Interactive selection
        nvidia_install_cuda: true
        nvidia_enable_persistence: false
        nvidia_reboot_after_install: false

    # Special GPU Server (specific driver)
    gpu_special:
      hosts:
        gpu-ml-01:
          ansible_host: 172.25.7.150
          ansible_user: mluser
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: yes
        nvidia_driver_version: "nvidia-driver-550-server"  # Specific version
        nvidia_install_cuda: true
        nvidia_reboot_after_install: true
```

Usage:
```bash
# Deploy to all groups
ansible-playbook -i main_inventory.yml playbook_multi_server.yml

# Deploy to production only
ansible-playbook -i main_inventory.yml playbook_multi_server.yml --limit gpu_production

# Deploy to development only
ansible-playbook -i main_inventory.yml playbook_interactive.yml --limit gpu_development

# Deploy to specific server
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml --limit gpu-ml-01
```

---

## Testing

### Verify Inventory

```bash
# List all hosts
ansible-inventory -i main_inventory.yml --list

# Show specific group
ansible-inventory -i main_inventory.yml --graph gpu_servers

# Verify connection to all hosts
ansible -i main_inventory.yml all -m ping

# Check specific group
ansible -i main_inventory.yml gpu_servers -m ping

# Test sudo access
ansible -i main_inventory.yml gpu_servers -m shell -a "whoami" --become
```

### Gather Facts

```bash
# Gather all facts
ansible -i main_inventory.yml gpu_servers -m setup

# Check GPU info
ansible -i main_inventory.yml gpu_servers -m shell -a "lspci | grep -i nvidia"

# Check OS version
ansible -i main_inventory.yml gpu_servers -m shell -a "cat /etc/os-release"
```

---

## Troubleshooting

### Connection Issues

```bash
# Test SSH connection
ssh root@172.25.7.99

# Test with specific key
ssh -i ~/.ssh/id_rsa root@172.25.7.99

# Debug Ansible connection
ansible -i main_inventory.yml gpu_servers -m ping -vvv
```

### Permission Issues

```bash
# Check sudo
ansible -i main_inventory.yml gpu_servers -m shell -a "sudo whoami"

# Check Python
ansible -i main_inventory.yml gpu_servers -m shell -a "which python3"
```

### Inventory Issues

```bash
# Validate YAML syntax
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml --syntax-check

# Check inventory parsing
ansible-inventory -i main_inventory.yml --list --yaml
```

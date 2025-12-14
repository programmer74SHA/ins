# Installation and Usage Guide

## Installation

### Method 1: Manual Copy

```bash
# Copy role to Ansible roles directory
sudo cp -r nvidia-gpu-setup /etc/ansible/roles/

# Or to user roles directory
mkdir -p ~/.ansible/roles
cp -r nvidia-gpu-setup ~/.ansible/roles/
```

### Method 2: Direct from Git (if you push to repository)

```bash
# Install from Git
ansible-galaxy install git+https://github.com/your-username/nvidia-gpu-setup.git

# Or add to requirements.yml
cat >> requirements.yml <<EOF
- src: https://github.com/your-username/nvidia-gpu-setup.git
  name: nvidia-gpu-setup
EOF

ansible-galaxy install -r requirements.yml
```

### Method 3: Ansible Galaxy (if published)

```bash
ansible-galaxy install your-username.nvidia-gpu-setup
```

---

## Basic Usage

### 1. Interactive Installation (Recommended for first-time users)

Create `install.yml`:
```yaml
---
- hosts: all
  become: yes
  roles:
    - nvidia-gpu-setup
```

Run:
```bash
ansible-playbook install.yml
```

You'll be prompted to select a driver version.

### 2. Automated Installation (Recommended for CI/CD)

Create `install.yml`:
```yaml
---
- hosts: all
  become: yes
  roles:
    - role: nvidia-gpu-setup
      vars:
        nvidia_driver_interactive: false
        nvidia_reboot_after_install: true
```

Run:
```bash
ansible-playbook install.yml
```

---

## Configuration Options

### All Available Variables

```yaml
roles:
  - role: nvidia-gpu-setup
    vars:
      # Interactive driver selection
      nvidia_driver_interactive: true          # true/false
      
      # Specific driver (when interactive=false)
      nvidia_driver_version: ""                # Empty for recommended, or specify version
      
      # CUDA installation
      nvidia_install_cuda: true                # true/false
      
      # Persistence mode
      nvidia_enable_persistence: true          # true/false
      
      # Auto-reboot
      nvidia_reboot_after_install: false       # true/false
      
      # Reboot timeout
      nvidia_reboot_timeout: 600               # seconds
```

### Common Scenarios

#### Scenario 1: Development Workstation
```yaml
vars:
  nvidia_driver_interactive: true        # Choose driver interactively
  nvidia_install_cuda: true             # Need CUDA for development
  nvidia_enable_persistence: false      # Not needed for workstation
  nvidia_reboot_after_install: false    # Reboot manually
```

#### Scenario 2: Production Server
```yaml
vars:
  nvidia_driver_interactive: false       # Automate everything
  nvidia_driver_version: ""             # Use recommended
  nvidia_install_cuda: true             # For ML workloads
  nvidia_enable_persistence: true       # Better performance
  nvidia_reboot_after_install: true     # Auto-reboot
```

#### Scenario 3: Specific Driver for Compatibility
```yaml
vars:
  nvidia_driver_interactive: false
  nvidia_driver_version: "nvidia-driver-550-server"  # Specific version
  nvidia_install_cuda: false            # Don't need CUDA
  nvidia_enable_persistence: true
  nvidia_reboot_after_install: false
```

#### Scenario 4: Multiple GPU Servers
```yaml
---
- hosts: gpu_cluster
  become: yes
  serial: 2                            # Install 2 servers at a time
  roles:
    - role: nvidia-gpu-setup
      vars:
        nvidia_driver_interactive: false
        nvidia_install_cuda: true
        nvidia_reboot_after_install: true
```

---

## Advanced Usage

### With Ansible Tags

Add tags to playbook:
```yaml
---
- hosts: all
  become: yes
  roles:
    - role: nvidia-gpu-setup
      tags: ['nvidia', 'gpu']
```

Run specific parts:
```bash
# Only run nvidia tasks
ansible-playbook install.yml --tags nvidia

# Skip nvidia tasks
ansible-playbook install.yml --skip-tags nvidia
```

### With Ansible Vault for Sensitive Data

If you need to store sensitive information:

```bash
# Create encrypted vars
ansible-vault create vault.yml

# Add to playbook
---
- hosts: all
  become: yes
  vars_files:
    - vault.yml
  roles:
    - nvidia-gpu-setup

# Run with vault
ansible-playbook install.yml --ask-vault-pass
```

### Pre and Post Tasks

```yaml
---
- hosts: all
  become: yes
  
  pre_tasks:
    - name: Check disk space
      shell: df -h /
      register: disk_space
    
    - name: Display disk space
      debug:
        var: disk_space.stdout_lines
  
  roles:
    - nvidia-gpu-setup
  
  post_tasks:
    - name: Verify installation
      command: nvidia-smi
      register: nvidia_check
      changed_when: false
      
    - name: Send notification
      debug:
        msg: "NVIDIA drivers installed successfully"
```

### Integration with Other Roles

```yaml
---
- hosts: ml_servers
  become: yes
  
  roles:
    # Install NVIDIA drivers first
    - nvidia-gpu-setup
    
    # Then install other tools
    - docker
    - nvidia-docker
    - kubernetes
```

---

## Inventory Management

### Static Inventory

`main_inventory.yml`:
```yaml
---
all:
  children:
    gpu_servers:
      hosts:
        ml-server-1:
          ansible_host: 172.25.7.101
        ml-server-2:
          ansible_host: 172.25.7.102
      vars:
        ansible_user: root
        ansible_become: yes
        ansible_python_interpreter: /usr/bin/python3
    
    development:
      hosts:
        dev-gpu:
          ansible_host: 172.25.7.200
          ansible_user: ubuntu
    
    production:
      hosts:
        prod-gpu-1:
          ansible_host: 10.0.1.10
        prod-gpu-2:
          ansible_host: 10.0.1.11
      vars:
        ansible_user: root
```

Usage:
```bash
# All GPU servers
ansible-playbook -i main_inventory.yml install.yml

# Only development
ansible-playbook -i main_inventory.yml install.yml --limit development

# Only production
ansible-playbook -i main_inventory.yml install.yml --limit production
```

### Dynamic Inventory

For cloud environments:
```bash
# AWS
ansible-playbook install.yml -i aws_ec2.yml

# GCP
ansible-playbook install.yml -i gcp_compute.yml

# Azure
ansible-playbook install.yml -i azure_rm.yml
```

---

## Command Line Examples

### Override Variables

```bash
# Install without CUDA
ansible-playbook install.yml -e "nvidia_install_cuda=false"

# Use specific driver
ansible-playbook install.yml \
  -e "nvidia_driver_interactive=false" \
  -e "nvidia_driver_version=nvidia-driver-580-open"

# Enable auto-reboot
ansible-playbook install.yml -e "nvidia_reboot_after_install=true"

# Multiple overrides
ansible-playbook install.yml \
  -e "nvidia_driver_interactive=false" \
  -e "nvidia_install_cuda=true" \
  -e "nvidia_enable_persistence=true" \
  -e "nvidia_reboot_after_install=true"
```

### Limit to Specific Hosts

```bash
# Single host
ansible-playbook -i main_inventory.yml install.yml --limit ml-server-1

# Multiple hosts
ansible-playbook -i main_inventory.yml install.yml --limit "ml-server-1,ml-server-2"

# By group
ansible-playbook -i main_inventory.yml install.yml --limit production
```

### Dry Run

```bash
# Check mode (no changes)
ansible-playbook install.yml --check

# Diff mode (show what would change)
ansible-playbook install.yml --check --diff

# List tasks
ansible-playbook install.yml --list-tasks

# List hosts
ansible-playbook -i main_inventory.yml install.yml --list-hosts
```

### Verbose Output

```bash
# Normal verbosity
ansible-playbook install.yml -v

# More verbose
ansible-playbook install.yml -vv

# Debug level
ansible-playbook install.yml -vvv

# Maximum verbosity
ansible-playbook install.yml -vvvv
```

---

## Continuous Integration

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    stages {
        stage('Install NVIDIA Drivers') {
            steps {
                ansiblePlaybook(
                    playbook: 'install.yml',
                    inventory: 'main_inventory.yml',
                    extras: '-e "nvidia_driver_interactive=false"'
                )
            }
        }
    }
}
```

### GitLab CI

```yaml
# .gitlab-ci.yml
install_nvidia:
  stage: deploy
  script:
    - ansible-playbook install.yml -i main_inventory.yml
  only:
    - main
```

### GitHub Actions

```yaml
# .github/workflows/install-nvidia.yml
name: Install NVIDIA Drivers

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Ansible
        run: |
          ansible-playbook install.yml -i main_inventory.yml
```

---

## Maintenance

### Updating Drivers

To update to a newer driver version:

```bash
# Interactive - choose new version
ansible-playbook install.yml

# Non-interactive - specify version
ansible-playbook install.yml \
  -e "nvidia_driver_version=nvidia-driver-590-open"
```

### Rollback

To rollback to previous driver:

```bash
# Remove current driver
sudo apt remove --purge nvidia-*

# Run playbook with older version
ansible-playbook install.yml \
  -e "nvidia_driver_version=nvidia-driver-550-server"
```

---

## Troubleshooting

See README.md for detailed troubleshooting steps.

Quick checks:
```bash
# Check connection
ansible -i main_inventory.yml all -m ping

# Check privileges
ansible -i main_inventory.yml all -m shell -a "whoami" --become

# Gather facts
ansible -i main_inventory.yml all -m setup | grep -i gpu

# Test playbook syntax
ansible-playbook install.yml --syntax-check
```

---

## Support

- Check README.md for full documentation
- Review QUICKSTART.md for quick examples
- Examine example playbooks in `examples/` directory
- File issues on GitHub (if applicable)

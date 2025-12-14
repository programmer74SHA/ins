# Quick Start Guide - install_dependencies Role

## 📋 What This Role Does

This Ansible role installs:
- ✅ Essential system packages (curl, wget, git, vim, etc.)
- ✅ Development tools (Python, GCC, Make, etc.)
- ✅ Network utilities (net-tools, nmap, ssh, etc.)
- ✅ Monitoring tools (htop, sysstat, etc.)
- ✅ Security tools (ufw, fail2ban, etc.)
- ✅ Docker CE (latest stable)
- ✅ Docker Compose Plugin

## 🚀 Quick Usage

### 1. Copy Role to Your Project

```bash
# Copy to your roles directory
cp -r install_dependencies /path/to/your/ansible/project/roles/
```

### 2. Create a Simple Playbook

```yaml
# playbook.yml
---
- hosts: servers
  become: true
  roles:
    - install_dependencies
```

### 3. Create Inventory

```yaml
# inventory.yml
---
all:
  hosts:
    server1:
      ansible_host: 192.168.1.10
      ansible_user: ubuntu
```

### 4. Run the Playbook

```bash
# Test connectivity
ansible all -i inventory.yml -m ping

# Run the playbook
ansible-playbook -i inventory.yml playbook.yml

# Run with specific tags (Docker only)
ansible-playbook -i inventory.yml playbook.yml --tags docker
```

## 🎯 Common Usage Examples

### Example 1: Basic Installation

```yaml
- hosts: servers
  become: true
  roles:
    - install_dependencies
```

### Example 2: Add Users to Docker Group

```yaml
- hosts: servers
  become: true
  roles:
    - role: install_dependencies
      vars:
        docker_users:
          - ubuntu
          - developer
```

### Example 3: Custom Configuration

```yaml
- hosts: servers
  become: true
  roles:
    - role: install_dependencies
      vars:
        docker_users:
          - ubuntu
        perform_full_upgrade: true
        docker_log_max_size: "100m"
        docker_log_max_file: "5"
```

### Example 4: Install Only Specific Components

```bash
# Only install essential packages
ansible-playbook playbook.yml --tags essential

# Only install Docker
ansible-playbook playbook.yml --tags docker

# Install packages and Docker, skip monitoring
ansible-playbook playbook.yml --skip-tags monitoring
```

## 📝 File Structure

```
install_dependencies/
├── defaults/
│   └── main.yml          # Default variables (packages, Docker config)
├── files/                # (empty - for future use)
├── handlers/
│   └── main.yml          # Service handlers (restart docker, etc.)
├── tasks/
│   └── main.yml          # Main task list
├── templates/
│   └── daemon.json.j2    # Docker daemon configuration template
├── vars/
│   └── main.yml          # Role variables
├── README.md             # Detailed documentation
└── example-playbook.yml  # Example usage
```

## ⚙️ Key Variables to Customize

Edit `defaults/main.yml` or override in your playbook:

```yaml
# Add users to docker group
docker_users:
  - username1
  - username2

# Docker daemon settings
docker_log_max_size: "10m"
docker_log_max_file: "3"

# System settings
perform_full_upgrade: false  # Set true to upgrade all packages
cleanup_apt_cache: true
```

## 🏷️ Useful Tags

| Tag | Description |
|-----|-------------|
| `packages` | All package installations |
| `essential` | Essential packages only |
| `development` | Development tools |
| `docker` | All Docker tasks |
| `docker-config` | Docker configuration only |
| `verify` | Verification tasks |

## ✅ Verification

After running the role:

```bash
# SSH into server
ssh ubuntu@192.168.1.10

# Check Docker
docker --version
docker compose version
docker ps

# Test Docker
docker run hello-world

# Check installed packages
which git curl wget vim htop
```

## 🔧 Troubleshooting

### Issue: Docker permission denied

**Solution:** Log out and back in, or run:
```bash
newgrp docker
```

### Issue: Packages not found

**Solution:** Update apt cache:
```bash
ansible-playbook playbook.yml --tags update
```

### Issue: Docker service not starting

**Solution:** Check logs:
```bash
sudo systemctl status docker
sudo journalctl -u docker
```

## 📚 Advanced Usage

### Custom Package List

Create your own playbook with additional packages:

```yaml
- hosts: servers
  become: true
  
  pre_tasks:
    - name: Install custom packages
      apt:
        name:
          - nginx
          - postgresql
          - redis-server
        state: present
  
  roles:
    - install_dependencies
```

### Multiple Environments

```yaml
# production.yml
- hosts: production_servers
  become: true
  roles:
    - role: install_dependencies
      vars:
        perform_full_upgrade: false
        docker_users:
          - appuser

# development.yml  
- hosts: dev_servers
  become: true
  roles:
    - role: install_dependencies
      vars:
        perform_full_upgrade: true
        docker_users:
          - developer
          - tester
```

## 🎓 Next Steps

1. Customize package lists in `defaults/main.yml`
2. Add your users to `docker_users` list
3. Configure Docker daemon settings as needed
4. Run the playbook with tags for selective installation
5. Verify installation with `docker --version`

---

**Ready to install? Run:**

```bash
ansible-playbook -i inventory.yml playbook.yml
```

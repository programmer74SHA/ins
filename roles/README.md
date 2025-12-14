# Ansible Role: install_dependencies

This role installs essential packages and Docker on Ubuntu servers.

## Requirements

- Ubuntu 24.04
- Ansible 2.9+
- Sudo privileges on target host

## Role Variables

### Package Lists

Available in `defaults/main.yml`:

- `essential_packages`: Core system utilities (curl, wget, git, vim, etc.)
- `development_packages`: Development tools (python3, gcc, make, etc.)
- `network_packages`: Network utilities (net-tools, nmap, ssh, etc.)
- `monitoring_packages`: System monitoring tools (htop, sysstat, etc.)
- `security_packages`: Security tools (ufw, fail2ban, etc.)

### Docker Configuration

```yaml
# Docker Compose version
docker_compose_version: "v2.23.0"

# Install standalone docker-compose binary
install_docker_compose_standalone: false

# Configure Docker daemon settings
configure_docker_daemon: true

# Users to add to docker group
docker_users:
  - username1
  - username2

# Docker daemon settings
docker_log_driver: "json-file"
docker_log_max_size: "10m"
docker_log_max_file: "3"
docker_storage_driver: "overlay2"
```

### System Settings

```yaml
# Perform full system upgrade
perform_full_upgrade: false

# Clean apt cache after installation
cleanup_apt_cache: true
```

## Dependencies

None.

## Example Playbook

### Basic Usage

```yaml
- hosts: servers
  become: true
  roles:
    - install_dependencies
```

### With Custom Variables

```yaml
- hosts: servers
  become: true
  roles:
    - role: install_dependencies
      vars:
        docker_users:
          - developer
          - jenkins
        perform_full_upgrade: true
        docker_log_max_size: "50m"
```

### Using Tags

```yaml
# Install only essential packages
ansible-playbook playbook.yml --tags packages,essential

# Install only Docker
ansible-playbook playbook.yml --tags docker

# Install everything except monitoring tools
ansible-playbook playbook.yml --skip-tags monitoring
```

## Available Tags

- `packages` - All package installations
- `essential` - Essential packages only
- `development` - Development tools only
- `network` - Network tools only
- `monitoring` - Monitoring tools only
- `security` - Security tools only
- `docker` - All Docker-related tasks
- `docker-prereqs` - Docker prerequisites
- `docker-users` - Add users to docker group
- `docker-compose` - Install Docker Compose
- `docker-config` - Configure Docker daemon
- `verify` - Verification tasks
- `cleanup` - Cleanup tasks
- `update` - Update apt cache
- `upgrade` - System upgrade

## Post-Installation

### Verify Docker Installation

```bash
# Check Docker version
docker --version

# Check Docker Compose version
docker compose version

# Test Docker
docker run hello-world

# Check Docker service status
systemctl status docker
```

### Verify Package Installation

```bash
# Check installed packages
dpkg -l | grep docker-ce
dpkg -l | grep git

# Verify user in docker group
groups username
```

## Customization

### Add Custom Packages

In your playbook:

```yaml
- hosts: servers
  become: true
  vars:
    additional_custom_packages:
      - postgresql-client
      - redis-tools
      - nginx
  tasks:
    - name: Install additional packages
      apt:
        name: "{{ additional_custom_packages }}"
        state: present
  roles:
    - install_dependencies
```

### Override Package Lists

```yaml
- hosts: servers
  become: true
  roles:
    - role: install_dependencies
      vars:
        essential_packages:
          - curl
          - wget
          - git
          # Your custom list
```

## Handlers

- `restart docker` - Restart Docker service
- `reload systemd` - Reload systemd daemon
- `restart ssh` - Restart SSH service
- `restart fail2ban` - Restart Fail2Ban service

## Templates

- `daemon.json.j2` - Docker daemon configuration

## Files

None.

## Author Information

APO DevOps Team

## License

Internal Use Only

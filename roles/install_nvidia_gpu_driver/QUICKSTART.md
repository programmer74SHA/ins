# Quick Start Guide - NVIDIA GPU Setup

## 1. Single Server - Interactive Mode

**Step 1:** Copy the role to your Ansible directory
```bash
cp -r nvidia-gpu-setup /etc/ansible/roles/
# or
cp -r nvidia-gpu-setup ~/.ansible/roles/
```

**Step 2:** Create a simple playbook
```bash
cat > install_nvidia.yml <<'EOF'
---
- name: Install NVIDIA Drivers
  hosts: localhost
  connection: local
  become: yes
  roles:
    - nvidia-gpu-setup
EOF
```

**Step 3:** Run it
```bash
ansible-playbook install_nvidia.yml
```

**Step 4:** Follow the interactive prompts to select your driver

**Step 5:** Reboot when prompted
```bash
sudo reboot
```

**Step 6:** Verify after reboot
```bash
nvidia-smi
```

---

## 2. Single Server - Non-Interactive (Recommended Driver)

```bash
# Create playbook
cat > install_nvidia.yml <<'EOF'
---
- name: Install NVIDIA Drivers
  hosts: localhost
  connection: local
  become: yes
  roles:
    - role: nvidia-gpu-setup
      vars:
        nvidia_driver_interactive: false
        nvidia_reboot_after_install: true
EOF

# Run it
ansible-playbook install_nvidia.yml
```

Server will reboot automatically and driver will be ready.

---

## 3. Remote Server Setup

**Step 1:** Create inventory file
```bash
cat > main_inventory.yml <<'EOF'
---
all:
  children:
    servers:
      hosts:
        your-server:
          ansible_host: 172.25.7.99
          ansible_user: root
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: yes
EOF
```

**Step 2:** Use example playbook
```bash
cp nvidia-gpu-setup/examples/playbook_auto_recommended.yml .
```

**Step 3:** Run it
```bash
ansible-playbook -i main_inventory.yml playbook_auto_recommended.yml
```

---

## 4. Multiple Servers

**Step 1:** Update inventory
```bash
cat > main_inventory.yml <<'EOF'
---
all:
  children:
    servers:
      hosts:
        gpu-node-1:
          ansible_host: 172.25.7.101
          ansible_user: root
        gpu-node-2:
          ansible_host: 172.25.7.102
          ansible_user: root
        gpu-node-3:
          ansible_host: 172.25.7.103
          ansible_user: ubuntu
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: yes
EOF
```

**Step 2:** Use multi-server playbook
```bash
cp nvidia-gpu-setup/examples/playbook_multi_server.yml .
```

**Step 3:** Run it
```bash
ansible-playbook -i main_inventory.yml playbook_multi_server.yml
```

This will install drivers on all servers, one at a time, with automatic reboots.

---

## 5. Testing Without Installation

To see what would happen without making changes:

```bash
ansible-playbook install_nvidia.yml --check
```

---

## 6. Specific Driver Version

```bash
ansible-playbook install_nvidia.yml \
  -e "nvidia_driver_interactive=false" \
  -e "nvidia_driver_version=nvidia-driver-580-open"
```

---

## Common Options

```bash
# Without CUDA
ansible-playbook install_nvidia.yml -e "nvidia_install_cuda=false"

# Without persistence mode
ansible-playbook install_nvidia.yml -e "nvidia_enable_persistence=false"

# With auto-reboot
ansible-playbook install_nvidia.yml -e "nvidia_reboot_after_install=true"

# Combine multiple options
ansible-playbook install_nvidia.yml \
  -e "nvidia_driver_interactive=false" \
  -e "nvidia_install_cuda=true" \
  -e "nvidia_reboot_after_install=true"
```

---

## Verification Commands

After installation and reboot:

```bash
# Check driver
nvidia-smi

# Check CUDA
nvcc --version

# Check modules
lsmod | grep nvidia

# Check persistence
nvidia-smi -q | grep Persistence

# Detailed GPU info
nvidia-smi -q
```

---

## Troubleshooting

### Check Ansible can connect
```bash
ansible -i main_inventory.yml servers -m ping
```

### Check sudo works
```bash
ansible -i main_inventory.yml servers -m shell -a "whoami" --become
```

### View detailed output
```bash
ansible-playbook install_nvidia.yml -vvv
```

### Check logs on target server
```bash
ssh your-server
dmesg | grep -i nvidia
journalctl -xe
```

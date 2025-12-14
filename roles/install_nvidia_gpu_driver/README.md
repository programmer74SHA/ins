# NVIDIA GPU Setup - Ansible Role

This Ansible role automates the installation and configuration of NVIDIA GPU drivers and CUDA toolkit on Ubuntu Server.

## Features

- ✅ Interactive driver selection (or automated)
- ✅ Detects available NVIDIA drivers
- ✅ Installs NVIDIA drivers and utilities
- ✅ Installs CUDA toolkit (optional)
- ✅ Enables NVIDIA persistence mode
- ✅ Supports multiple GPU configurations
- ✅ Handles system reboot if required

## Requirements

- Ubuntu 20.04, 22.04, or 24.04
- NVIDIA GPU installed
- Root/sudo privileges
- Ansible 2.10+

## Role Variables

### Default Variables (`defaults/main.yml`)

```yaml
# Interactive mode: prompt user to select driver version
nvidia_driver_interactive: true

# Specific driver version (used when nvidia_driver_interactive is false)
# Leave empty to use recommended driver
nvidia_driver_version: ""

# Install CUDA toolkit
nvidia_install_cuda: true

# Enable NVIDIA persistence mode (recommended for servers)
nvidia_enable_persistence: true

# Automatically reboot after installation if required
nvidia_reboot_after_install: false

# Reboot timeout in seconds
nvidia_reboot_timeout: 600
```

## Directory Structure

```
nvidia-gpu-setup/
├── tasks/
│   ├── main.yml              # Main task orchestration
│   ├── validate.yml          # Prerequisites validation
│   ├── detect_gpu.yml        # GPU detection
│   ├── get_drivers.yml       # Get available drivers
│   ├── select_driver.yml     # Interactive driver selection
│   ├── install_driver.yml    # Driver installation
│   ├── install_cuda.yml      # CUDA toolkit installation
│   ├── configure.yml         # NVIDIA configuration
│   └── verify.yml            # Installation verification
├── handlers/
│   └── main.yml              # Reboot and service handlers
├── templates/
│   └── nvidia-persistenced-override.conf.j2
├── files/                     # (currently empty)
├── vars/
│   └── main.yml              # Role-specific variables
├── defaults/
│   └── main.yml              # Default variables
└── meta/
    └── main.yml              # Role metadata
```

## Example Playbooks

### 1. Interactive Mode (Default)

```yaml
---
- name: Install NVIDIA GPU Drivers - Interactive
  hosts: servers
  become: yes
  roles:
    - nvidia-gpu-setup
```

### 2. Non-Interactive with Recommended Driver

```yaml
---
- name: Install NVIDIA GPU Drivers - Auto Recommended
  hosts: servers
  become: yes
  roles:
    - role: nvidia-gpu-setup
      vars:
        nvidia_driver_interactive: false
        nvidia_install_cuda: true
        nvidia_reboot_after_install: true
```

### 3. Non-Interactive with Specific Driver

```yaml
---
- name: Install NVIDIA GPU Drivers - Specific Version
  hosts: servers
  become: yes
  roles:
    - role: nvidia-gpu-setup
      vars:
        nvidia_driver_interactive: false
        nvidia_driver_version: "nvidia-driver-580-open"
        nvidia_install_cuda: true
        nvidia_enable_persistence: true
        nvidia_reboot_after_install: false
```

### 4. Without CUDA Toolkit

```yaml
---
- name: Install NVIDIA GPU Drivers - No CUDA
  hosts: servers
  become: yes
  roles:
    - role: nvidia-gpu-setup
      vars:
        nvidia_install_cuda: false
```

### 5. Complete Example with Inventory

**main_inventory.yml:**
```yaml
---
all:
  children:
    servers:
      hosts:
        gpu-node-1:
          ansible_host: 172.25.7.99
          ansible_user: root
        gpu-node-2:
          ansible_host: 172.25.7.100
          ansible_user: root
      vars:
        ansible_python_interpreter: /usr/bin/python3
        ansible_become: yes
```

**playbook.yml:**
```yaml
---
- name: Setup NVIDIA GPUs on Multiple Servers
  hosts: servers
  roles:
    - role: nvidia-gpu-setup
      vars:
        nvidia_driver_interactive: false
        nvidia_driver_version: "nvidia-driver-580-open"
        nvidia_install_cuda: true
        nvidia_enable_persistence: true
        nvidia_reboot_after_install: true
```

**Run:**
```bash
ansible-playbook -i main_inventory.yml playbook.yml
```

## Usage

### Running the Role

1. **Clone or copy the role to your Ansible roles directory:**
   ```bash
   cp -r nvidia-gpu-setup /path/to/ansible/roles/
   ```

2. **Create a playbook:**
   ```bash
   cat > install_nvidia.yml <<'EOF'
   ---
   - name: Install NVIDIA GPU Drivers
     hosts: all
     become: yes
     roles:
       - nvidia-gpu-setup
   EOF
   ```

3. **Run the playbook:**
   ```bash
   # Interactive mode
   ansible-playbook install_nvidia.yml

   # Non-interactive mode
   ansible-playbook install_nvidia.yml -e "nvidia_driver_interactive=false"

   # With specific driver
   ansible-playbook install_nvidia.yml -e "nvidia_driver_interactive=false nvidia_driver_version=nvidia-driver-580-open"
   ```

## Interactive Driver Selection

When `nvidia_driver_interactive: true`, the role will:

1. Detect your GPU(s)
2. Show all available drivers
3. Highlight the recommended driver
4. Prompt you to:
   - Press ENTER for recommended driver
   - Enter a driver name (e.g., `nvidia-driver-580-open`)
   - Enter a number from the list

Example prompt:
```
╔═══════════════════════════════════════════════════════════╗
║          NVIDIA Driver Selection                          ║
╚═══════════════════════════════════════════════════════════╝

Recommended driver: nvidia-driver-580-open

Available drivers:
  1. nvidia-driver-470
  2. nvidia-driver-535
  3. nvidia-driver-550-server
  4. nvidia-driver-580 (recommended)
  5. nvidia-driver-580-open

Your choice:
```

## Verification

After installation, the role will:

1. Run `nvidia-smi` to verify driver installation
2. Show loaded NVIDIA kernel modules
3. Display CUDA version (if installed)
4. Indicate if a reboot is required

## Post-Installation

After reboot, verify installation:

```bash
# Check driver
nvidia-smi

# Check CUDA (if installed)
nvcc --version

# Check loaded modules
lsmod | grep nvidia

# Check persistence mode
nvidia-smi -q | grep Persistence
```

## Troubleshooting

### Secure Boot Issues

If Secure Boot is enabled, you may need to:

1. Disable Secure Boot in BIOS, or
2. Sign the NVIDIA kernel modules

### Driver Not Loading After Reboot

```bash
# Check for errors
dmesg | grep -i nvidia

# Reinstall driver
sudo apt install --reinstall nvidia-driver-XXX
```

### Multiple Playbook Runs

The role is idempotent - you can run it multiple times safely. It will:
- Skip already installed drivers
- Only make changes when necessary
- Not reboot if driver is already loaded

## License

MIT

## Author

Your Name / Your Company

# NVIDIA GPU Setup - Directory Structure

```
nvidia-gpu-setup/
│
├── README.md                          # Main documentation
├── QUICKSTART.md                      # Quick start guide
├── USAGE.md                           # Detailed usage guide
│
├── tasks/                             # Main task directory
│   ├── main.yml                       # Main task orchestration
│   ├── validate.yml                   # Prerequisites validation
│   ├── detect_gpu.yml                 # GPU detection
│   ├── get_drivers.yml                # Get available drivers
│   ├── select_driver.yml              # Interactive driver selection
│   ├── install_driver.yml             # Driver installation
│   ├── install_cuda.yml               # CUDA toolkit installation
│   ├── configure.yml                  # NVIDIA configuration
│   └── verify.yml                     # Installation verification
│
├── handlers/                          # Event handlers
│   └── main.yml                       # Reboot and service handlers
│
├── templates/                         # Jinja2 templates
│   └── nvidia-persistenced-override.conf.j2
│
├── files/                             # Static files
│   └── .gitkeep                       # Keep directory in git
│
├── vars/                              # Role-specific variables
│   └── main.yml                       # Variable definitions
│
├── defaults/                          # Default variables
│   └── main.yml                       # Default values
│
├── meta/                              # Role metadata
│   └── main.yml                       # Galaxy info and dependencies
│
└── examples/                          # Example playbooks
    ├── inventory.ini                  # Example inventory
    ├── playbook_interactive.yml       # Interactive mode example
    ├── playbook_auto_recommended.yml  # Auto recommended driver
    ├── playbook_specific_driver.yml   # Specific driver version
    └── playbook_multi_server.yml      # Multi-server deployment
```

## File Count Summary

- **Tasks**: 9 files
- **Handlers**: 1 file
- **Templates**: 1 file
- **Vars**: 1 file
- **Defaults**: 1 file
- **Meta**: 1 file
- **Examples**: 5 files
- **Documentation**: 3 files

**Total**: 22 files across 7 standard Ansible role directories

## Key Features

### 1. Standard Ansible Structure ✓
All 7 standard directories included:
- `tasks/` - Task definitions
- `handlers/` - Event handlers  
- `templates/` - Jinja2 templates
- `files/` - Static files
- `vars/` - Role variables
- `defaults/` - Default variables
- `meta/` - Role metadata

### 2. Modular Task Organization ✓
Tasks split into logical modules:
- Validation
- Detection
- Selection
- Installation
- Configuration
- Verification

### 3. Interactive & Non-Interactive Modes ✓
Supports both user interaction and automation

### 4. Comprehensive Documentation ✓
- README.md - Full documentation
- QUICKSTART.md - Quick examples
- USAGE.md - Advanced usage

### 5. Example Playbooks ✓
Multiple example scenarios included

## Usage

Place this role in one of these locations:

```bash
# System-wide
/etc/ansible/roles/nvidia-gpu-setup/

# User-specific
~/.ansible/roles/nvidia-gpu-setup/

# Project-specific
./roles/nvidia-gpu-setup/
```

Then reference in your playbook:

```yaml
roles:
  - nvidia-gpu-setup
```

Or with Galaxy:

```yaml
roles:
  - name: nvidia-gpu-setup
    src: https://github.com/your-user/nvidia-gpu-setup
```

# System Hardening Role

This Ansible role hardens the system by configuring SSH, fail2ban, GRUB, and lshell with security best practices.

## Features

### SSH Hardening
- Configures secure ciphers (aes256-ctr, aes128-ctr)
- Sets strong key exchange algorithms (ECDH SHA2 NISTP variants)
- Configures secure MACs (HMAC-SHA2-256, HMAC-SHA2-512)
- Enforces modern public key types (RSA-SHA2-256, RSA-SHA2-512)
- Sets rekey limits for enhanced security
- Configures client alive settings to prevent hanging connections
- Disables version banners to reduce information disclosure
- Adds security banner warning unauthorized users
- Disables root login and password authentication by default

### Fail2ban Configuration
- Installs and configures fail2ban
- Sets up SSH jail to prevent brute force attacks
- Configurable ban times and retry limits
- Email notifications for security events

### GRUB Security Hardening
- Password protection for GRUB bootloader
- Kernel hardening parameters
- Disables recovery mode and submenus
- Audit logging configuration

### lshell (Limited Shell)
- Installs and configures lshell for restricted shell access
- Restricts commands and paths available to users
- Configures command logging for audit purposes
- Provides role-based access control (default, support, admin)
- Session timeout and idle timeout enforcement
- Command aliasing and execution monitoring

## Variables

See `defaults/main.yml` for all configurable variables.

### Key SSH Variables:
- `ssh_ciphers`: Allowed encryption ciphers
- `ssh_kex_algorithms`: Key exchange algorithms
- `ssh_macs`: Message authentication codes
- `ssh_permit_root_login`: Allow root login (default: no)
- `ssh_password_authentication`: Allow password auth (default: no)

### Key Fail2ban Variables:
- `fail2ban_enabled`: Enable fail2ban (default: true)
- `fail2ban_bantime`: Ban duration in seconds (default: 3600)
- `fail2ban_maxretry`: Max retries before ban (default: 5)
- `fail2ban_ssh_maxretry`: SSH-specific max retries (default: 3)

### Key lshell Variables:
- `lshell_enabled`: Enable lshell installation (default: true)
- `lshell_log_path`: Path for lshell logs (default: /var/log/siem/shell/)
- `lshell_config_path`: Path to lshell configuration (default: /etc/lshell.conf)

## Usage

The role is included in the main playbook:

```yaml
- name: "APK AI Infrastructure Installer"
  hosts: all
  gather_facts: yes
  roles:
    - system_hardening
```

## Tags

- `ssh`: Run only SSH hardening tasks
- `fail2ban`: Run only fail2ban tasks
- `grub`: Run only GRUB hardening tasks
- `lshell`: Run only lshell installation and configuration tasks
- `shell`: Shell-related hardening tasks
- `hardening`: Run all hardening tasks

## Security Notes

**WARNING**: This role modifies SSH configuration. Ensure you have:
1. Console access to the server in case SSH becomes inaccessible
2. SSH key-based authentication configured before disabling password auth
3. Tested the configuration in a non-production environment first

The role validates SSH configuration before restarting the service to prevent lockouts.

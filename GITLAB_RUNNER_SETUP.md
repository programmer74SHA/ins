# GitLab Runner Setup Guide

This guide explains how to set up a GitLab Runner for the AI Installer project.

## Prerequisites

### System Requirements
- Ubuntu 20.04 or newer (or compatible Linux distribution)
- Minimum 4GB RAM
- Minimum 20GB free disk space
- Network access to:
  - GitLab server
  - `repo.apk-group.net` (internal package repository)
  - `registry.apk-group.net` (internal Docker registry)

### Required Tools

Install the following tools on the GitLab runner machine:

```bash
# Update package list
sudo apt update

# Install required packages
sudo apt install -y \
  wget \
  curl \
  dpkg-dev \
  pigz \
  tar \
  git \
  skopeo \
  jq

# Verify installations
wget --version
dpkg-scanpackages --version
pigz --version
skopeo --version
```

## GitLab Runner Installation

### 1. Install GitLab Runner

```bash
# Download the GitLab Runner binary
curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64

# Give it execute permissions
chmod +x /usr/local/bin/gitlab-runner

# Create GitLab CI user
useradd --comment 'GitLab Runner' --create-home gitlab-runner --shell /bin/bash

# Install and run as service
gitlab-runner install --user=gitlab-runner --working-directory=/home/gitlab-runner
gitlab-runner start
```

### 2. Register the Runner

Get your registration token from GitLab:
- Go to your GitLab project
- Settings → CI/CD → Runners → Expand
- Copy the registration token

Register the runner:

```bash
gitlab-runner register
```

When prompted, provide:
- **GitLab instance URL**: Your GitLab server URL
- **Registration token**: The token from GitLab
- **Description**: `Point-Runner` (or any descriptive name)
- **Tags**: `shell` (required for this project)
- **Executor**: `shell`

### 3. Configure the Runner

Edit the runner configuration:

```bash
sudo nano /etc/gitlab-runner/config.toml
```

Ensure the configuration includes:

```toml
concurrent = 1

[[runners]]
  name = "Point-Runner"
  url = "https://your-gitlab-instance.com/"
  token = "YOUR_RUNNER_TOKEN"
  executor = "shell"

  [runners.custom_build_dir]
    enabled = true

  [runners.cache]
    Type = "local"
    Shared = false

    [runners.cache.local]
      MaxUploadedArchiveSize = 0
```

Restart the runner:

```bash
gitlab-runner restart
```

## Network Configuration

### Critical: Repository Access

The runner **MUST** have network access to `repo.apk-group.net`. This is an internal repository that requires:

1. **DNS Resolution**: Ensure `repo.apk-group.net` resolves correctly
   ```bash
   nslookup repo.apk-group.net
   ```

2. **Network Connectivity**: The runner must be on the internal network or have VPN access
   ```bash
   ping repo.apk-group.net
   curl -I https://repo.apk-group.net/repository/ubuntu/packages/
   ```

3. **Firewall Rules**: Ensure outbound HTTPS (port 443) is allowed

### Setting Up DNS (if needed)

If the domain doesn't resolve, add it to `/etc/hosts`:

```bash
# Example - replace with actual IP address
echo "192.168.1.100  repo.apk-group.net" | sudo tee -a /etc/hosts
```

### Setting Up VPN (if needed)

If the repository requires VPN access:

1. Install VPN client (e.g., OpenVPN)
2. Configure VPN to auto-connect
3. Ensure VPN starts before GitLab runner service

Example systemd service override:

```bash
sudo systemctl edit gitlab-runner
```

Add:

```ini
[Unit]
After=openvpn@client.service
Requires=openvpn@client.service
```

## Testing the Setup

### Test Network Access

```bash
# Test repository access
curl -I https://repo.apk-group.net/repository/ubuntu/packages/

# Should return HTTP 200 OK
# If you get 403 Forbidden or DNS errors, network is not properly configured
```

### Test Build Locally

```bash
# Clone the repository
git clone <your-repo-url>
cd ins

# Test the build_repo target
make build_repo

# This should download packages and build the repository
# If it fails with "No packages downloaded", check network access
```

### Trigger a Pipeline

Push a change or create a tag to trigger the CI/CD pipeline:

```bash
git tag 0.0.1-test
git push origin 0.0.1-test
```

Monitor the pipeline in GitLab UI:
- Go to CI/CD → Pipelines
- Check the running job logs
- Verify that packages are being downloaded

## Troubleshooting

### Issue: "No packages were downloaded"

**Cause**: Runner cannot access `repo.apk-group.net`

**Solutions**:
1. Verify DNS resolution: `nslookup repo.apk-group.net`
2. Check network connectivity: `curl -I https://repo.apk-group.net/`
3. Ensure VPN is connected (if required)
4. Check firewall rules
5. Verify /etc/hosts entry (if using local DNS override)

### Issue: "dpkg-scanpackages: command not found"

**Cause**: Missing `dpkg-dev` package

**Solution**:
```bash
sudo apt install dpkg-dev
```

### Issue: "pigz: command not found"

**Cause**: Missing `pigz` package

**Solution**:
```bash
sudo apt install pigz
```

### Issue: "skopeo: command not found"

**Cause**: Missing `skopeo` for Docker image downloads

**Solution**:
```bash
# Ubuntu 20.10+
sudo apt install skopeo

# Ubuntu 20.04 or earlier
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
curl -L "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key" | sudo apt-key add -
sudo apt update
sudo apt install skopeo
```

### Issue: Pipeline stuck or timeout

**Cause**: Large downloads or slow network

**Solution**:
- Increase timeout in `.gitlab-ci.yml`:
  ```yaml
  timeout: 2h
  ```
- Use caching for artifacts
- Consider pre-downloading packages to runner

### Issue: Permission denied errors

**Cause**: Runner user doesn't have necessary permissions

**Solution**:
```bash
# Ensure gitlab-runner user has write access
sudo chown -R gitlab-runner:gitlab-runner /home/gitlab-runner
sudo chmod 755 /home/gitlab-runner

# For Docker operations (if needed)
sudo usermod -aG docker gitlab-runner
```

## Monitoring and Maintenance

### Check Runner Status

```bash
# Check if runner is running
gitlab-runner status

# View runner logs
sudo journalctl -u gitlab-runner -f

# List registered runners
gitlab-runner list
```

### Clean Up Build Artifacts

Periodically clean up old builds:

```bash
# Clean GitLab runner cache
gitlab-runner cache-clean

# Clean temporary build directories
sudo rm -rf /tmp/ai_installer/*

# Clean old builds in runner workspace
sudo find /home/gitlab-runner/builds -type f -mtime +7 -delete
```

### Update GitLab Runner

```bash
# Stop runner
gitlab-runner stop

# Download latest version
curl -L --output /usr/local/bin/gitlab-runner https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64

# Restart runner
gitlab-runner start
```

## Security Considerations

1. **Runner Isolation**: Use dedicated runners for sensitive builds
2. **Access Control**: Limit who can modify `.gitlab-ci.yml`
3. **Secrets Management**: Use GitLab CI/CD variables for sensitive data
4. **Network Security**: Ensure runner is on a secure network
5. **Regular Updates**: Keep runner and dependencies updated

## Additional Resources

- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [GitLab CI/CD Documentation](https://docs.gitlab.com/ee/ci/)
- [Shell Executor Documentation](https://docs.gitlab.com/runner/executors/shell.html)

## Support

For issues specific to this project:
1. Check the Makefile for build requirements
2. Review CI/CD pipeline logs in GitLab
3. Verify network access to internal repositories
4. Contact your network team for VPN/DNS issues

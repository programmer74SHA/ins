# GitLab Runner Setup Guide

This document explains how to configure your GitLab runner to authenticate with the private container registry for the AI Installer project.

## Problem

The build process requires downloading Docker images from a private registry (`registry.apk-group.net`). Without proper authentication, the runner will fail with:

```
unauthorized: unauthorized to access repository: automation/modules/elasticsearch, action: pull
```

## Prerequisites

- GitLab Runner installed and registered
- Shell executor configured
- `skopeo` installed on the runner machine
- Access credentials for `registry.apk-group.net`

## Solution Options

### Option 1: GitLab CI/CD Variables (Recommended)

This method stores credentials securely in GitLab and makes them available to the CI/CD pipeline.

1. **Navigate to your GitLab project**:
   - Go to `Settings` → `CI/CD` → `Variables`

2. **Add the following variables**:

   | Variable Name | Value | Type | Protected | Masked |
   |---------------|-------|------|-----------|---------|
   | `REGISTRY_USERNAME` | Your registry username | Variable | ✓ | ✓ |
   | `REGISTRY_PASSWORD` | Your registry password | Variable | ✓ | ✓ |

3. **Save the variables**

The `.gitlab-ci.yml` file will automatically use these credentials to authenticate before downloading images.

### Option 2: Configure Skopeo Auth on Runner Machine

If you prefer to configure authentication directly on the runner machine:

1. **SSH into the GitLab runner machine**

2. **Login to the registry as the gitlab-runner user**:
   ```bash
   sudo -u gitlab-runner skopeo login registry.apk-group.net
   ```

   Enter your username and password when prompted.

3. **Verify the authentication**:
   ```bash
   sudo -u gitlab-runner skopeo inspect docker://registry.apk-group.net/automation/modules/elasticsearch:8.15.5
   ```

4. **Check the auth file** (optional):
   ```bash
   sudo cat /home/gitlab-runner/.config/containers/auth.json
   ```

### Option 3: Use Docker Credentials (if Docker is installed)

If the runner machine has Docker installed:

1. **Login as gitlab-runner user**:
   ```bash
   sudo -u gitlab-runner docker login registry.apk-group.net
   ```

2. **Skopeo will automatically use Docker credentials** from `~/.docker/config.json`

## Verification

After configuring authentication, verify it works:

1. **Test skopeo manually**:
   ```bash
   sudo -u gitlab-runner skopeo copy \
     docker://registry.apk-group.net/automation/modules/elasticsearch:8.15.5 \
     docker-archive:/tmp/test-elasticsearch.tar.gz
   ```

2. **If successful, clean up the test file**:
   ```bash
   rm /tmp/test-elasticsearch.tar.gz
   ```

3. **Trigger a new pipeline** in GitLab to verify the CI/CD job works

## Troubleshooting

### Issue: "unauthorized: unauthorized to access repository"

**Causes**:
- Invalid credentials
- Credentials not set in GitLab CI/CD variables
- gitlab-runner user doesn't have access to auth config

**Solutions**:
- Verify credentials are correct
- Check that `REGISTRY_USERNAME` and `REGISTRY_PASSWORD` are set in GitLab
- Ensure auth file permissions: `chown -R gitlab-runner:gitlab-runner /home/gitlab-runner/.config`

### Issue: "skopeo: command not found"

**Solution**: Install skopeo on the runner machine

**For Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install -y skopeo
```

**For RHEL/CentOS**:
```bash
sudo yum install -y skopeo
```

### Issue: Runner job fails with "make: No such file or directory"

**Solution**: The Makefile expects to be copied to a temporary directory. Ensure the `tmp_path` variable is set correctly in `.gitlab-ci.yml` and the repository contents are available.

Update the download job in `.gitlab-ci.yml`:
```yaml
download:
  script:
    - echo "Running make file with $MakeTarget target"
    - mkdir -p $tmp_path
    - cp -r . $tmp_path/
    - make -C $tmp_path $MakeTarget
```

## Security Best Practices

1. **Never commit credentials** to the repository
2. **Use masked and protected variables** in GitLab CI/CD settings
3. **Rotate credentials regularly**
4. **Limit registry access** to only necessary users/service accounts
5. **Use read-only credentials** for the CI/CD pipeline if possible

## Additional Resources

- [GitLab CI/CD Variables Documentation](https://docs.gitlab.com/ee/ci/variables/)
- [Skopeo Documentation](https://github.com/containers/skopeo)
- [GitLab Runner Configuration](https://docs.gitlab.com/runner/configuration/)

## Need Help?

If you continue to experience issues:
1. Check the GitLab runner logs: `sudo journalctl -u gitlab-runner -f`
2. Verify runner registration: `sudo gitlab-runner verify`
3. Check runner status: `sudo gitlab-runner status`
4. Review the job logs in the GitLab UI for specific error messages

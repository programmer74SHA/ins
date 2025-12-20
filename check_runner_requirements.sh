#!/bin/bash

# GitLab Runner Requirements Diagnostic Script
# This script checks if all requirements for running the AI Installer build are met

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}GitLab Runner Requirements Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if a command exists
check_command() {
    local cmd="$1"
    local package="$2"
    local required="$3"

    printf "Checking %-20s ... " "$cmd"

    if command -v "$cmd" >/dev/null 2>&1; then
        version=$($cmd --version 2>&1 | head -1)
        echo -e "${GREEN}✓ OK${NC} ($version)"
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}✗ MISSING (REQUIRED)${NC}"
            echo -e "   ${YELLOW}Install with: sudo apt install $package${NC}"
            return 1
        else
            echo -e "${YELLOW}✗ MISSING (OPTIONAL)${NC}"
            echo -e "   ${YELLOW}Install with: sudo apt install $package${NC}"
            return 0
        fi
    fi
}

# Track errors
ERRORS=0

echo -e "${YELLOW}1. Checking Required Tools${NC}"
echo "----------------------------"

check_command "wget" "wget" "required" || ERRORS=$((ERRORS + 1))
check_command "curl" "curl" "required" || ERRORS=$((ERRORS + 1))
check_command "git" "git" "required" || ERRORS=$((ERRORS + 1))
check_command "tar" "tar" "required" || ERRORS=$((ERRORS + 1))
check_command "pigz" "pigz" "required" || ERRORS=$((ERRORS + 1))
check_command "dpkg-scanpackages" "dpkg-dev" "required" || ERRORS=$((ERRORS + 1))
check_command "skopeo" "skopeo" "required" || ERRORS=$((ERRORS + 1))
check_command "jq" "jq" "optional"

echo ""
echo -e "${YELLOW}2. Checking Network Access${NC}"
echo "----------------------------"

# Check DNS resolution
printf "DNS Resolution (repo.apk-group.net) ... "
if nslookup repo.apk-group.net >/dev/null 2>&1; then
    IP=$(nslookup repo.apk-group.net | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    echo -e "${GREEN}✓ OK${NC} (resolves to $IP)"
else
    echo -e "${RED}✗ FAILED${NC}"
    echo -e "   ${YELLOW}DNS does not resolve. Check /etc/hosts or DNS configuration${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check network connectivity
printf "Network Ping (repo.apk-group.net) ... "
if ping -c 1 -W 2 repo.apk-group.net >/dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}✗ FAILED (may be blocked by firewall)${NC}"
fi

# Check HTTP access to ubuntu repository
printf "HTTP Access (ubuntu repo) ... "
HTTP_STATUS=$(curl -s -I -L --max-time 10 https://repo.apk-group.net/repository/ubuntu/packages/ 2>/dev/null | head -1)
if echo "$HTTP_STATUS" | grep -q "200 OK"; then
    echo -e "${GREEN}✓ OK${NC} (HTTP 200)"
elif echo "$HTTP_STATUS" | grep -q "403"; then
    echo -e "${RED}✗ FAILED (HTTP 403 Forbidden)${NC}"
    echo -e "   ${YELLOW}Access denied. Check network access, VPN, or authentication${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${RED}✗ FAILED${NC} ($HTTP_STATUS)"
    echo -e "   ${YELLOW}Cannot access repository. Check network/VPN${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check HTTP access to ubuntu-security repository
printf "HTTP Access (ubuntu-security repo) ... "
HTTP_STATUS=$(curl -s -I -L --max-time 10 https://repo.apk-group.net/repository/ubuntu-security/packages/ 2>/dev/null | head -1)
if echo "$HTTP_STATUS" | grep -q "200 OK"; then
    echo -e "${GREEN}✓ OK${NC} (HTTP 200)"
elif echo "$HTTP_STATUS" | grep -q "403"; then
    echo -e "${RED}✗ FAILED (HTTP 403 Forbidden)${NC}"
    echo -e "   ${YELLOW}Access denied. Check network access, VPN, or authentication${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${RED}✗ FAILED${NC} ($HTTP_STATUS)"
    echo -e "   ${YELLOW}Cannot access repository. Check network/VPN${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check HTTP access to Docker registry
printf "HTTP Access (Docker registry) ... "
HTTP_STATUS=$(curl -s -I -L --max-time 10 https://registry.apk-group.net/ 2>/dev/null | head -1)
if echo "$HTTP_STATUS" | grep -q -E "200 OK|401"; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${YELLOW}✗ WARNING${NC} ($HTTP_STATUS)"
    echo -e "   ${YELLOW}Docker registry may not be accessible${NC}"
fi

echo ""
echo -e "${YELLOW}3. Checking System Resources${NC}"
echo "----------------------------"

# Check disk space
printf "Disk Space (/tmp) ... "
DISK_AVAIL=$(df -h /tmp | tail -1 | awk '{print $4}')
DISK_AVAIL_GB=$(df -BG /tmp | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$DISK_AVAIL_GB" -ge 10 ]; then
    echo -e "${GREEN}✓ OK${NC} ($DISK_AVAIL available)"
else
    echo -e "${YELLOW}✗ WARNING${NC} ($DISK_AVAIL available)"
    echo -e "   ${YELLOW}Less than 10GB available. Build may fail.${NC}"
fi

# Check memory
printf "Available Memory ... "
MEM_AVAIL=$(free -h | grep "Mem:" | awk '{print $7}')
MEM_AVAIL_MB=$(free -m | grep "Mem:" | awk '{print $7}')
if [ "$MEM_AVAIL_MB" -ge 2048 ]; then
    echo -e "${GREEN}✓ OK${NC} ($MEM_AVAIL available)"
else
    echo -e "${YELLOW}✗ WARNING${NC} ($MEM_AVAIL available)"
    echo -e "   ${YELLOW}Less than 2GB available. Build may be slow.${NC}"
fi

echo ""
echo -e "${YELLOW}4. Checking GitLab Runner${NC}"
echo "----------------------------"

# Check if GitLab runner is installed
printf "GitLab Runner Installed ... "
if command -v gitlab-runner >/dev/null 2>&1; then
    RUNNER_VERSION=$(gitlab-runner --version 2>&1 | head -1)
    echo -e "${GREEN}✓ OK${NC} ($RUNNER_VERSION)"
else
    echo -e "${RED}✗ MISSING${NC}"
    echo -e "   ${YELLOW}Install GitLab Runner: https://docs.gitlab.com/runner/install/${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check if GitLab runner is running
if command -v gitlab-runner >/dev/null 2>&1; then
    printf "GitLab Runner Status ... "
    if gitlab-runner status 2>&1 | grep -q "running"; then
        echo -e "${GREEN}✓ RUNNING${NC}"
    else
        echo -e "${YELLOW}✗ NOT RUNNING${NC}"
        echo -e "   ${YELLOW}Start with: sudo gitlab-runner start${NC}"
    fi

    # List registered runners
    printf "Registered Runners ... "
    RUNNER_COUNT=$(gitlab-runner list 2>&1 | grep -c "Executor:" || echo 0)
    if [ "$RUNNER_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✓ OK${NC} ($RUNNER_COUNT registered)"
        echo ""
        echo -e "   ${BLUE}Registered runners:${NC}"
        gitlab-runner list 2>&1 | grep -E "Executor:|Token:" | sed 's/^/   /'
    else
        echo -e "${YELLOW}✗ NO RUNNERS${NC}"
        echo -e "   ${YELLOW}Register a runner: gitlab-runner register${NC}"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All requirements are met!${NC}"
    echo ""
    echo "You can now run the build with:"
    echo "  make build_repo"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
    echo ""
    echo "Please fix the issues above before running the build."
    echo ""
    echo "Common solutions:"
    echo "  1. Install missing packages: sudo apt update && sudo apt install wget curl git tar pigz dpkg-dev skopeo"
    echo "  2. Configure network access to repo.apk-group.net (VPN, DNS, firewall)"
    echo "  3. Install and register GitLab Runner"
    echo ""
    echo "See GITLAB_RUNNER_SETUP.md for detailed instructions."
    echo ""
    exit 1
fi

#!/bin/bash

# Nexus Repository .deb Downloader
# This script downloads all .deb files from a Nexus repository

# Configuration
NEXUS_URL="https://repo.apk-group.net"

# Define repositories to download (repository_name:folder_name)
declare -a REPOSITORIES=(
    "ubuntu:ubuntu"
    "ubuntu-security:ubuntu-security"
)

BASE_DOWNLOAD_DIR="./deb_packages"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Nexus Repository .deb Downloader ===${NC}"
echo "Repository: $NEXUS_URL"
echo "Base Directory: $BASE_DOWNLOAD_DIR"
echo "Repositories to download: ${#REPOSITORIES[@]}"
for repo_entry in "${REPOSITORIES[@]}"; do
    IFS=':' read -r repo_name folder_name <<< "$repo_entry"
    echo "  - $repo_name -> $folder_name/"
done
echo ""

# Function to download .deb files using Nexus API
download_via_api() {
    local REPO_NAME="$1"
    local DOWNLOAD_DIR="$2"

    echo -e "${YELLOW}Attempting to download via Nexus API...${NC}"

    # Get list of assets from repository
    CONTINUATION_TOKEN=""
    PAGE=1

    while true; do
        echo "Fetching page $PAGE..."

        if [ -z "$CONTINUATION_TOKEN" ]; then
            API_URL="${NEXUS_URL}/service/rest/v1/assets?repository=${REPO_NAME}"
        else
            API_URL="${NEXUS_URL}/service/rest/v1/assets?repository=${REPO_NAME}&continuationToken=${CONTINUATION_TOKEN}"
        fi

        RESPONSE=$(curl -s "$API_URL")

        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to fetch assets from API${NC}"
            return 1
        fi

        # Extract .deb file URLs and download
        echo "$RESPONSE" | jq -r '.items[] | select(.path | endswith(".deb")) | .downloadUrl' 2>/dev/null | while read -r DEB_URL; do
            if [ -n "$DEB_URL" ]; then
                FILENAME=$(basename "$DEB_URL")
                echo -e "${GREEN}Downloading: $FILENAME${NC}"
                curl -f -L -o "$DOWNLOAD_DIR/$FILENAME" "$DEB_URL"

                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✓ Successfully downloaded: $FILENAME${NC}"
                else
                    echo -e "${RED}✗ Failed to download: $FILENAME${NC}"
                fi
            fi
        done

        # Check for continuation token (pagination)
        CONTINUATION_TOKEN=$(echo "$RESPONSE" | jq -r '.continuationToken // empty' 2>/dev/null)

        if [ -z "$CONTINUATION_TOKEN" ] || [ "$CONTINUATION_TOKEN" = "null" ]; then
            echo "No more pages to fetch"
            break
        fi

        PAGE=$((PAGE + 1))
    done

    return 0
}

# Function to download using repository browser
download_via_browse() {
    local REPO_NAME="$1"
    local DOWNLOAD_DIR="$2"

    echo -e "${YELLOW}Attempting to download via repository browse...${NC}"

    # FIXED: Include /packages/ path where actual packages are stored
    BASE_URL="${NEXUS_URL}/repository/${REPO_NAME}/packages"

    # Function to recursively download from directory
    download_recursive() {
        local URL="$1"
        local DEPTH="$2"

        # FIXED: Increased max depth from 20 to 25 to handle deeply nested structures
        if [ $DEPTH -gt 25 ]; then
            echo "Max depth reached, skipping..."
            return
        fi

        echo "Scanning: $URL (depth: $DEPTH)"

        # Get directory listing
        CONTENT=$(curl -s "$URL/")

        if [ $? -ne 0 ]; then
            return
        fi

        # Find .deb files
        echo "$CONTENT" | grep -oP 'href="[^"]*\.deb"' | sed 's/href="//;s/"//' | while read -r HREF; do
            if [[ "$HREF" == http* ]]; then
                DEB_URL="$HREF"
            else
                DEB_URL="${URL}/${HREF}"
            fi

            FILENAME=$(basename "$DEB_URL" | sed 's/%2B/+/g;s/%20/ /g')

            echo -e "${GREEN}Downloading: $FILENAME${NC}"
            curl -f -L -o "$DOWNLOAD_DIR/$FILENAME" "$DEB_URL"

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Successfully downloaded: $FILENAME${NC}"
            else
                echo -e "${RED}✗ Failed to download: $FILENAME${NC}"
            fi
        done

        # Find subdirectories and recurse
        echo "$CONTENT" | grep -oP 'href="[^"]*/"' | grep -v '\.\.' | sed 's/href="//;s/"//' | while read -r HREF; do
            if [[ "$HREF" != http* ]] && [[ "$HREF" != /* ]]; then
                SUBDIR="${URL}/${HREF%/}"
                download_recursive "$SUBDIR" $((DEPTH + 1))
            fi
        done
    }

    download_recursive "$BASE_URL" 0
}

# Function to download using wget mirror
download_via_wget() {
    local REPO_NAME="$1"
    local DOWNLOAD_DIR="$2"

    echo -e "${YELLOW}Attempting to download via wget mirror...${NC}"

    # FIXED: Include /packages/ path where actual packages are stored
    BASE_URL="${NEXUS_URL}/repository/${REPO_NAME}/packages/"

    # FIXED: Added proper wget options to handle deep directory structures
    # -l 15: Increase recursion depth to 15 (default is 5, but packages are 8-9 levels deep)
    # --timeout=60: Connection timeout
    # --tries=3: Retry failed downloads 3 times
    # --waitretry=5: Wait 5 seconds between retries
    # -e robots=off: Disable robots.txt checking for better crawling
    wget --recursive \
         --no-parent \
         --no-host-directories \
         --cut-dirs=3 \
         --accept "*.deb" \
         --directory-prefix="$DOWNLOAD_DIR" \
         -l 15 \
         --timeout=60 \
         --tries=3 \
         --waitretry=5 \
         -e robots=off \
         "$BASE_URL"

    return $?
}

# Process each repository
for repo_entry in "${REPOSITORIES[@]}"; do
    IFS=':' read -r REPO_NAME FOLDER_NAME <<< "$repo_entry"
    DOWNLOAD_DIR="${BASE_DOWNLOAD_DIR}/${FOLDER_NAME}"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Processing Repository: ${REPO_NAME}${NC}"
    echo -e "${BLUE}Download Directory: ${DOWNLOAD_DIR}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"

    # Check if jq is available for API method
    if command -v jq &> /dev/null; then
        echo -e "${GREEN}jq found, using API method${NC}"
        download_via_api "$REPO_NAME" "$DOWNLOAD_DIR"

        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}API method failed, trying alternative methods...${NC}"
            download_via_browse "$REPO_NAME" "$DOWNLOAD_DIR"
        fi
    else
        echo -e "${YELLOW}jq not found, skipping API method${NC}"
        echo "Install jq for better performance: sudo apt install jq"
        download_via_browse "$REPO_NAME" "$DOWNLOAD_DIR"
    fi

    # Summary for this repository
    DEB_COUNT=$(find "$DOWNLOAD_DIR" -name "*.deb" 2>/dev/null | wc -l)
    REPO_SIZE=$(du -sh "$DOWNLOAD_DIR" 2>/dev/null | cut -f1)
    echo ""
    echo -e "${GREEN}Repository ${REPO_NAME} complete:${NC}"
    echo "  Files downloaded: $DEB_COUNT"
    echo "  Size: $REPO_SIZE"
done

# Overall Summary
echo ""
echo -e "${GREEN}=== Overall Download Complete ===${NC}"
echo "Base Directory: $BASE_DOWNLOAD_DIR"
echo ""
echo "Summary by repository:"
for repo_entry in "${REPOSITORIES[@]}"; do
    IFS=':' read -r REPO_NAME FOLDER_NAME <<< "$repo_entry"
    DOWNLOAD_DIR="${BASE_DOWNLOAD_DIR}/${FOLDER_NAME}"
    DEB_COUNT=$(find "$DOWNLOAD_DIR" -name "*.deb" 2>/dev/null | wc -l)
    REPO_SIZE=$(du -sh "$DOWNLOAD_DIR" 2>/dev/null | cut -f1)
    echo "  ${FOLDER_NAME}: $DEB_COUNT files ($REPO_SIZE)"
done

echo ""
TOTAL_DEB_COUNT=$(find "$BASE_DOWNLOAD_DIR" -name "*.deb" 2>/dev/null | wc -l)
TOTAL_SIZE=$(du -sh "$BASE_DOWNLOAD_DIR" 2>/dev/null | cut -f1)
echo "Total .deb files downloaded: $TOTAL_DEB_COUNT"
echo "Total size: $TOTAL_SIZE"

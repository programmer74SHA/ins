#!/bin/bash
[[ -z "$NEXTCLOUD_USERNAME" || -z "$NEXTCLOUD_PASSWORD" ]] && {
    echo "Error: NEXTCLOUD_USERNAME and NEXTCLOUD_PASSWORD environment variables are not set."
    echo "Set them using:"
    echo "export NEXTCLOUD_USERNAME=\"username\""
    echo "export NEXTCLOUD_PASSWORD=\"password\""
    exit 1
}

[[ $# -lt 1 || $# -gt 2 ]] && {
    echo "Usage: $0 <file-to-upload> [remote-directory]"
    exit 1
}
FILE_TO_UPLOAD="$1"
[[ ! -f "$FILE_TO_UPLOAD" ]] && {
    echo "Error: File \"$FILE_TO_UPLOAD\" does not exist or is not a regular file."
    exit 1
}
REMOTE_DIR="${2:-}"
USER_UUID=$(curl -k -u "$NEXTCLOUD_USERNAME:$NEXTCLOUD_PASSWORD" -H "OCS-APIRequest: true" "https://drive.apk-group.net/apps/dashboard/" -s | grep -o 'data-user="[^"]*"' | sed 's/data-user="//;s/"$//' | tr -d '\n')
[[ -z "$USER_UUID" ]] && {
    echo "Error: Failed to retrieve user UUID. Check your credentials and Nextcloud URL."
    exit 1
}
NEXTCLOUD_URL="https://drive.apk-group.net/remote.php/dav/files/${USER_UUID}/${REMOTE_DIR}"
curl -k -u "$NEXTCLOUD_USERNAME:$NEXTCLOUD_PASSWORD" -T "$FILE_TO_UPLOAD" "$NEXTCLOUD_URL/" || {
    echo "Error: Failed to upload file \"$FILE_TO_UPLOAD\" to Nextcloud."
    exit 1
}

echo "File \"$FILE_TO_UPLOAD\" uploaded successfully to Nextcloud."

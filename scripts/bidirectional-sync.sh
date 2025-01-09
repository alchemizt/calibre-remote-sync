#!/bin/bash

# Load environment variables
if [ -f "$(dirname "$0")/../config/config.env" ]; then
    source "$(dirname "$0")/../config/config.env"
else
    echo "Environment file not found. Please create config/config.env."
    exit 1
fi

# Ensure the log file exists
mkdir -p "$(dirname "$LOG_FILE")"
if [ ! -f "$LOG_FILE" ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Creating log file at $LOG_FILE" >> "$LOG_FILE"
    touch "$LOG_FILE"
fi

# Function to unmount on exit
cleanup() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Unmounting remote directory..." | tee -a "$LOG_FILE"
    fusermount -u "$MOUNT_DIR"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Remote unmounted. Exiting." | tee -a "$LOG_FILE"
    exit
}
trap cleanup SIGINT SIGTERM

# Create the mount directory if it doesn't exist
mkdir -p "$MOUNT_DIR"

# Mount the remote directory
echo "$(date +'%Y-%m-%d %H:%M:%S') - Mounting remote directory..." | tee -a "$LOG_FILE"
rclone mount "$REMOTE_NAME" "$MOUNT_DIR" --vfs-cache-mode full --poll-interval "${POLL_INTERVAL}s" &
RCLONE_PID=$!

# Wait for the mount to initialize
sleep 5

# Check if the mount was successful
if ! mountpoint -q "$MOUNT_DIR"; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Failed to mount remote directory. Exiting." | tee -a "$LOG_FILE"
    exit 1
fi

echo "$(date +'%Y-%m-%d %H:%M:%S') - Remote directory mounted at $MOUNT_DIR." | tee -a "$LOG_FILE"

# Sync changes from local to remote when local files are modified
inotifywait -m -r -e modify,create,delete,move --format '%w%f' "$LOCAL_DIR" | while read LOCAL_CHANGE
do
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Local change detected: $LOCAL_CHANGE" | tee -a "$LOG_FILE"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Syncing local changes to remote..." | tee -a "$LOG_FILE"
    rclone sync "$LOCAL_DIR" "$REMOTE_NAME" --progress 2>&1 | tee -a "$LOG_FILE"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Local-to-remote sync complete." | tee -a "$LOG_FILE"
done &

# Monitor the mounted remote directory for changes
inotifywait -m -r -e modify,create,delete,move --format '%w%f' "$MOUNT_DIR" | while read REMOTE_CHANGE
do
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Remote change detected: $REMOTE_CHANGE" | tee -a "$LOG_FILE"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Syncing remote changes to local..." | tee -a "$LOG_FILE"
    rclone sync "$MOUNT_DIR" "$LOCAL_DIR" --progress 2>&1 | tee -a "$LOG_FILE"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Remote-to-local sync complete." | tee -a "$LOG_FILE"
done

# Cleanup on exit
cleanup

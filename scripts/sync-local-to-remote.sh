#!/bin/bash

# Define paths
LIBRARY_DIR="/mnt/books"  # Replace with your actual library directory
REMOTE_NAME="pCloud:/Library/calibre-library"         # Replace with your rclone remote name
LOG_FILE="/home/entheo/.custom/calibre/logs/sync-calibre.log"         # Path to the log file

if [ ! -f "$LOG_FILE" ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Log file does not exist. Creating log file at $LOG_FILE" >> "$LOG_FILE"
    touch "$LOG_FILE"
fi

# Monitor the library directory for changes
inotifywait -m -r -e modify,create,delete,move --format '%w%f' "$LIBRARY_DIR" | while read CHANGE
do
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Change detected: $CHANGE" | tee -a "$LOG_FILE"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Syncing changes to pCloud..." | tee -a "$LOG_FILE"
    rclone sync "$LIBRARY_DIR" "$REMOTE_NAME" --progress
done
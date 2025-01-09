#!/bin/bash

# Project directories
PROJECT_DIR=$(pwd)
SCRIPTS_DIR="$PROJECT_DIR/scripts"
CONFIG_DIR="$PROJECT_DIR/config"
SERVICES_DIR="$PROJECT_DIR/services"
LOGS_DIR="$PROJECT_DIR/logs"

# File paths
ENV_FILE="$CONFIG_DIR/config.env"
EXAMPLE_ENV_FILE="$CONFIG_DIR/example.env"
SYNC_SCRIPT="$SCRIPTS_DIR/bidirectional-sync.sh"
SERVICE_FILE="$SERVICES_DIR/remote-sync.service"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/remote-sync.service"

# Ensure directories exist
mkdir -p "$SCRIPTS_DIR" "$CONFIG_DIR" "$SERVICES_DIR" "$LOGS_DIR"

# Install required dependencies
echo "Installing dependencies..."
sudo apt update && sudo apt install -y rclone inotify-tools


# Check if rclone is configured
if ! rclone listremotes | grep -q ':'; then
    echo "It seems that rclone is not configured yet."
    echo "You need to set up rclone before proceeding."
    echo "The rclone configuration wizard will now run..."
    rclone config
    if ! rclone listremotes | grep -q ':'; then
        echo "No remotes were configured. Exiting the installer."
        exit 1
    fi
else
    echo "Rclone is already configured. Proceeding..."
fi


# Function to prompt for user input
prompt_user_input() {
    local prompt_message=$1
    local default_value=$2
    local user_input

    read -p "$prompt_message [$default_value]: " user_input
    if [ -z "$user_input" ]; then
        echo "$default_value"
    else
        echo "$user_input"
    fi
}

# Interactive setup for config.env
if [ ! -f "$ENV_FILE" ]; then
    echo "Creating environment file with your input..."
    REMOTE_NAME=$(prompt_user_input "Enter your rclone remote name" "pcloud:calibre-library")
    MOUNT_DIR=$(prompt_user_input "Enter the mount directory for the remote" "/mnt/remote-calibre")
    LOCAL_DIR=$(prompt_user_input "Enter the local directory to sync with the remote" "/path/to/local-library")
    LOG_FILE=$(prompt_user_input "Enter the path for the log file" "/path/to/sync.log")
    POLL_INTERVAL=$(prompt_user_input "Enter the polling interval (in seconds)" "10")

    cat <<EOL > "$ENV_FILE"
# Generated configuration file
REMOTE_NAME=$REMOTE_NAME
MOUNT_DIR=$MOUNT_DIR
LOCAL_DIR=$LOCAL_DIR
LOG_FILE=$LOG_FILE
POLL_INTERVAL=$POLL_INTERVAL
EOL

    echo "Environment file created at $ENV_FILE. Here are the contents:"
    cat "$ENV_FILE"
else
    echo "Environment file already exists at $ENV_FILE. Skipping creation."
fi




#!/bin/bash

# Default installation directory
INSTALL_DIR="$HOME/.local/share/calibre-library-remote-sync"

# Get the directory where the installer script resides
INSTALLER_DIR=$(dirname "$(realpath "$0")")

# Get the parent directory (project directory)
SOURCE_DIR=$(dirname "$INSTALLER_DIR")

SCRIPTS_DIR="$INSTALL_DIR/scripts"
CONFIG_DIR="$INSTALL_DIR/config"
SERVICES_DIR="$INSTALL_DIR/services"
LOGS_DIR="$INSTALL_DIR/logs"
LOG_FILE="$LOGS_DIR/sync.log"

# File paths
ENV_FILE="$CONFIG_DIR/config.env"
EXAMPLE_ENV_FILE="$CONFIG_DIR/example.env"
SYNC_SCRIPT="$SCRIPTS_DIR/bidirectional-sync.sh"
SERVICE_FILE="$SERVICES_DIR/remote-sync.service"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/remote-sync.service"


# Ask the user for the installation directory
read -p "Enter the installation directory (default: $INSTALL_DIR): " CUSTOM_INSTALL_DIR
if [ ! -z "$CUSTOM_INSTALL_DIR" ]; then
    INSTALL_DIR=$CUSTOM_INSTALL_DIR
fi

# Ensure the install directory exists
mkdir -p "$INSTALL_DIR"

# Copy files to the install directory
echo "Copying files to the installation directory: $INSTALL_DIR"
cp -R "$SOURCE_DIR/scripts" "$INSTALL_DIR"
cp -R "$SOURCE_DIR/config" "$INSTALL_DIR"
cp -R "$SOURCE_DIR/services" "$INSTALL_DIR"
mkdir -p "$LOGS_DIR"



# Install required dependencies
echo "Installing dependencies..."
sudo apt update && sudo apt install -y rclone inotify-tools



# Update and install the systemd service
echo "Creating systemd service file..."
cat <<EOL > /etc/systemd/system/remote-sync.service
[Unit]
Description=Bi-Directional Sync between Local and Remote
After=network.target

[Service]
ExecStart=$INSTALL_DIR/scripts/bidirectional-sync.sh
Restart=always
User=$USER
WorkingDirectory=$INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOL

# Reload and start the service
echo "Enabling and starting the systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable remote-sync.service
sudo systemctl start remote-sync.service


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
    POLL_INTERVAL=$(prompt_user_input "Enter the polling interval (in seconds)" "10")

    cat <<EOL > "$ENV_FILE"
# Generated configuration file
REMOTE_NAME=$REMOTE_NAME
MOUNT_DIR=$MOUNT_DIR
LOCAL_DIR=$LOCAL_DIR
POLL_INTERVAL=$POLL_INTERVAL
EOL

    echo "Environment file created at $ENV_FILE. Here are the contents:"
    cat "$ENV_FILE"
else
    echo "Environment file already exists at $ENV_FILE. Skipping creation."
fi






echo "Installation complete. The service is running from $INSTALL_DIR."



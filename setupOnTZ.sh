#!/bin/bash

set -e  # Exit on any error

# Display and confirm config
echo "✅ Current configuration:" >> setupOnTZ.log
echo "SSH_KEY_PATH = $SSH_KEY_PATH" >> setupOnTZ.log
echo "SSH_PORT = $SSH_PORT" >> setupOnTZ.log
echo "REMOTE_HOST = $REMOTE_HOST" >> setupOnTZ.log
echo "REMOTE_USER = $REMOTE_USER" >> setupOnTZ.log
echo "LOCAL_SCRIPT_PATH = $LOCAL_SCRIPT_PATH" >> setupOnTZ.log
echo "REMOTE_SCRIPT_PATH = $REMOTE_SCRIPT_PATH" >> setupOnTZ.log
echo "ROOT_PASSWORD = $ROOT_PASSWORD" >> setupOnTZ.log

# Database login details
ROOT_PASSWORD="${ROOT_PASSWORD:-my-password}"
CONTAINER_NAME="singlestoredb"

# --- Install Podman and Podman Compose ---
echo "Installing Podman and Podman Compose..." >> setupOnTZ.log

# Install Podman (if not already installed)
if ! command -v podman &> /dev/null; then
  sudo dnf install -y podman >> setupOnTZ.log 2>&1
else
echo "Podman already installed." >> setupOnTZ.log
fi

# Install Podman Compose (if not already installed)
if ! command -v podman-compose &> /dev/null; then
  sudo dnf install -y podman-compose >> setupOnTZ.log 2>&1
else
echo "Podman Compose already installed." >> setupOnTZ.log
fi

# --- Create /data Directory ---
DATA_DIR="/data"
if [ ! -d "$DATA_DIR" ]; then
echo "Creating /data directory..." >> setupOnTZ.log
  sudo mkdir -p "$DATA_DIR"
  sudo chown $(whoami):$(whoami) "$DATA_DIR"
else
echo "/data directory already exists." >> setupOnTZ.log
fi

# --- Run Podman Compose ---
echo "Starting containers using Podman Compose..." >> setupOnTZ.log
podman-compose up -d
echo "Setup complete." >> setupOnTZ.log

# Run database scripts in SingleStore

# Function to check if database is ready
wait_for_db() {
    local max_attempts=10 
	local delay=15
    local attempt=0

    
    echo "Waiting for database to accept connections..." >> setupOnTZ.log
    
    while [ $attempt -lt $max_attempts ]; do
        if podman exec -i "$CONTAINER_NAME" singlestore -uroot -p"$ROOT_PASSWORD" -e "SELECT 1" &>/dev/null; then
            echo "Database is ready!" >> setupOnTZ.log
            return 0
        fi
        attempt=$((attempt+1))
        echo "Attempt $attempt/$max_attempts failed. Retrying in $delay seconds..." >> setupOnTZ.log
        sleep $delay
    done
    
    echo "❌ Error: Database not ready after $max_attempts attempts" >> setupOnTZ.log
    return 1
}

# Ensure the SingleStore container is running
if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
echo "❌ Error: Container '${CONTAINER_NAME}' is not running." >> setupOnTZ.log
  exit 1
fi

# Wait for database to be ready
wait_for_db || exit 1

# SQL commands to run
SQL_COMMANDS=$(cat <<EOF
CREATE DATABASE IF NOT EXISTS finance;
USE finance;
DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
  transaction_id INT AUTO_INCREMENT PRIMARY KEY,
  account_id INT,
  timestamp DATETIME,
  amount DECIMAL(19, 4),
  location GEOGRAPHYPOINT,
  suspicious BOOL,
  user VARCHAR(100)
);
EOF
)

# Run the SQL commands inside the container using the mysql client
echo "🏦 Running SQL commands in container '${CONTAINER_NAME}'..." >> setupOnTZ.log
echo "logging in to singlestore with user '${ROOT_PASSWORD}'" >> setupOnTZ.log
podman exec -i "${CONTAINER_NAME}" singlestore -uroot -p"${ROOT_PASSWORD}" -e "$SQL_COMMANDS"

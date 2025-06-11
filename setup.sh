#!/bin/bash

set -e  # Exit on any error

# --- Install Podman and Podman Compose ---
echo "Installing Podman and Podman Compose..."

# Install Podman (if not already installed)
if ! command -v podman &> /dev/null; then
  sudo dnf install -y podman
else
  echo "Podman already installed."
fi

# Install Podman Compose (if not already installed)
if ! command -v podman-compose &> /dev/null; then
  sudo dnf install -y podman-compose
else
  echo "Podman Compose already installed."
fi

# --- Create /data Directory ---
DATA_DIR="/data"
if [ ! -d "$DATA_DIR" ]; then
  echo "Creating /data directory..."
  sudo mkdir -p "$DATA_DIR"
  sudo chown $(whoami):$(whoami) "$DATA_DIR"
else
  echo "/data directory already exists."
fi

# --- Run Podman Compose ---
echo "Starting containers using Podman Compose..."
podman-compose up -d

echo "Setup complete."

#!/bin/bash

set -euo pipefail

# Database login details
ROOT_PASSWORD="${ROOT_PASSWORD:-my-password}"
CONTAINER_NAME="singlestoredb"

# Ensure the container is running
if ! podman ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
  echo "❌ Error: Container '${CONTAINER_NAME}' is not running."
  exit 1
fi

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
echo "🏦 Running SQL commands in container '${CONTAINER_NAME}'..."
podman exec -i "${CONTAINER_NAME}" singlestore -uroot -p"${ROOT_PASSWORD}" -e "$SQL_COMMANDS"

#!/bin/bash

# Load config from .env
if [ -f .env ]; then
    echo "🔄 Loading configuration from .env file..."
    source .env
else
    echo "❌ .env file not found. Please create one before running this script."
    exit 1
fi

# Function to confirm or override a value
confirm_or_override() {
    local var_name=$1
    local current_value=$2
    read -p "Current value for $var_name is [$current_value]. Press Enter to keep or enter a new value: " new_value
    if [ -n "$new_value" ]; then
        export "$var_name=$new_value"
        eval "$var_name=\"$new_value\""
    fi
}

# Display and confirm config
echo "✅ Current configuration:"
echo "SSH_KEY_PATH = $SSH_KEY_PATH"
echo "SSH_PORT = $SSH_PORT"
echo "REMOTE_HOST = $REMOTE_HOST"
echo "REMOTE_USER = $REMOTE_USER"
echo "LOCAL_SCRIPT_PATH = $LOCAL_SCRIPT_PATH"
echo "REMOTE_SCRIPT_PATH = $REMOTE_SCRIPT_PATH"
echo "ROOT_PASSWORD = $ROOT_PASSWORD"

echo ""
read -p "Do you want to keep these values? (y/n): " confirm

if [[ "$confirm" =~ ^[Nn] ]]; then
    confirm_or_override SSH_KEY_PATH "$SSH_KEY_PATH"
    confirm_or_override SSH_PORT "$SSH_PORT"
    confirm_or_override REMOTE_HOST "$REMOTE_HOST"
    confirm_or_override REMOTE_USER "$REMOTE_USER"
    confirm_or_override LOCAL_SCRIPT_PATH "$LOCAL_SCRIPT_PATH"
    confirm_or_override REMOTE_SCRIPT_PATH "$REMOTE_SCRIPT_PATH"
    confirm_or_override ROOT_PASSWORD "$ROOT_PASSWORD"
fi

echo ""
echo "Confirm STREAMSETS specific variables"

# Confirm or override environment variables
confirm_or_override DEPLOYMENT_ID "$DEPLOYMENT_ID"
confirm_or_override DEPLOYMENT_TOKEN "$DEPLOYMENT_TOKEN"
confirm_or_override STREAMSETS_IMAGE "$STREAMSETS_IMAGE"
confirm_or_override STREAMSETS_SCH_URL "$STREAMSETS_SCH_URL"

# Resolve docker-compose path (assumed to be in same dir as script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
REMOTE_COMPOSE_PATH="docker-compose.yml"

# Validate files
if [ ! -f "$LOCAL_SCRIPT_PATH" ]; then
    echo "❌ Local script file not found: $LOCAL_SCRIPT_PATH"
    exit 1
fi

if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "❌ docker-compose.yml file not found in script directory: $DOCKER_COMPOSE_FILE"
    exit 1
fi

# Optional: clean up remote files before copying (comment out if not needed)
echo "🧹 Ensuring clean remote destination paths..."
ssh -p "$SSH_PORT" -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST" bash -c "'
    rm -f \"$REMOTE_SCRIPT_PATH\"
    rm -f \"$REMOTE_COMPOSE_PATH\"
'"

# Copy script and docker-compose to remote host
echo ""
echo "📦 Copying files to $REMOTE_USER@$REMOTE_HOST on port $SSH_PORT..."
scp -P "$SSH_PORT" -i "$SSH_KEY_PATH" "$LOCAL_SCRIPT_PATH" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_SCRIPT_PATH"
scp -P "$SSH_PORT" -i "$SSH_KEY_PATH" "$DOCKER_COMPOSE_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_COMPOSE_PATH"
scp -P "$SSH_PORT" -i "$SSH_KEY_PATH" "$KIBANA_DASHBOARD_FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_KIBANA_DASHBOARD_PATH"

if [ $? -ne 0 ]; then
    echo "❌ Failed to copy one or more files."
    exit 1
fi

# Run the script remotely with environment exports
echo "🧪 Executing script on $REMOTE_HOST, please wait for a while - lots going on there..."

ssh -p "$SSH_PORT" -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST" bash -c "'
    export DEPLOYMENT_ID=\"$DEPLOYMENT_ID\"
    export DEPLOYMENT_TOKEN=\"$DEPLOYMENT_TOKEN\"
    export STREAMSETS_IMAGE=\"$STREAMSETS_IMAGE\"
    export STREAMSETS_SCH_URL=\"$STREAMSETS_SCH_URL\"
    export ROOT_PASSWORD=\"$ROOT_PASSWORD\"
    bash \"$REMOTE_SCRIPT_PATH\"
'"

if [ $? -ne 0 ]; then
    echo "❌ Failed to execute the script on the remote host."
    exit 1
fi


# Kibana dashboard path
KIBANA_DASHBOARD_FILE="$SCRIPT_DIR/kibana/export.ndjson"

echo ""
echo "🔐 Creating SSH tunnel to forward Kibana port from remote host..."

# Start SSH port forwarding in background (local 15601 -> remote 5601)
ssh -f -N -L 15601:localhost:5601 -i "$SSH_KEY_PATH" "$REMOTE_USER@$REMOTE_HOST"

# Wait until Kibana on the remote host is ready
echo "⏳ Waiting for Kibana to be ready through the tunnel..."

until curl -s "http://localhost:15601/api/status" | grep -q '"state":"green"'; do
  echo "🔄 Kibana is not ready yet... retrying in 5s"
  sleep 5
done

echo "✅ Kibana is up. Importing dashboard..."

# Import the dashboard via forwarded port
response=$(curl -s -w "%{http_code}" -o /tmp/kibana_response.txt -X POST "http://localhost:15601/api/saved_objects/_import?overwrite=true" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@$KIBANA_DASHBOARD_FILE")

if [[ "$response" == "200" || "$response" == "201" ]]; then
  echo "✅ Dashboard imported successfully."
else
  echo "❌ Dashboard import failed. HTTP status: $response"
  echo "📄 Kibana response:"
  cat /tmp/kibana_response.txt
fi


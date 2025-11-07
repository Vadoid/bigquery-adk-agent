#!/bin/bash

# Helper script to start ADK web interface with default app selection
# This opens the web UI directly to bigquery_agent_app

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Change to project root
cd "$SCRIPT_DIR"

# Port configuration
PORT=${1:-8000}
APP_NAME="bigquery_agent_app"
URL="http://localhost:$PORT/dev-ui/?app=$APP_NAME"

echo "Starting ADK web interface on port $PORT..."
echo "The web UI will open automatically at: $URL"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Function to check if server is ready
wait_for_server() {
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT" | grep -q "200\|404\|302"; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    return 1
}

# Function to open browser
open_browser() {
    if command -v open >/dev/null 2>&1; then
        # macOS
        open "$URL"
    elif command -v xdg-open >/dev/null 2>&1; then
        # Linux
        xdg-open "$URL"
    elif command -v start >/dev/null 2>&1; then
        # Windows (Git Bash)
        start "$URL"
    else
        echo ""
        echo "Please open your browser and navigate to: $URL"
    fi
}

# Start adk web in the background
adk web --port "$PORT" &
ADK_PID=$!

# Wait for server to be ready
echo "Waiting for server to start..."
if wait_for_server; then
    echo "✅ Server is ready!"
    open_browser
else
    echo "⚠️  Server may not be ready, but opening browser anyway..."
    open_browser
fi

# Wait for the ADK process (this will block until Ctrl+C)
wait $ADK_PID


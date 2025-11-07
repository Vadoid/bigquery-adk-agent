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

# Open the browser with the app parameter after a short delay (in background)
(
    sleep 3
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
) &

# Start adk web in the foreground (this will block until Ctrl+C)
adk web --port "$PORT"


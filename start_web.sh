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
    local max_attempts=60  # Wait up to 60 seconds
    local attempt=0
    echo -n "Waiting for server"
    while [ $attempt -lt $max_attempts ]; do
        # Check if the port is listening first (faster check)
        if command -v lsof >/dev/null 2>&1; then
            # macOS/Linux: check if port is in use
            if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
                # Port is listening, now check if HTTP endpoint responds
                if curl -s -f -o /dev/null --max-time 2 "http://localhost:$PORT/dev-ui/" 2>/dev/null; then
                    echo ""  # New line after dots
                    return 0
                fi
            fi
        elif command -v netstat >/dev/null 2>&1; then
            # Alternative: check if port is listening (Linux)
            if netstat -an 2>/dev/null | grep -q ":$PORT.*LISTEN"; then
                if curl -s -f -o /dev/null --max-time 2 "http://localhost:$PORT/dev-ui/" 2>/dev/null; then
                    echo ""  # New line after dots
                    return 0
                fi
            fi
        else
            # Fallback: just check HTTP response
            if curl -s -f -o /dev/null --max-time 2 "http://localhost:$PORT/dev-ui/" 2>/dev/null; then
                echo ""  # New line after dots
                return 0
            fi
        fi
        echo -n "."
        sleep 1
        attempt=$((attempt + 1))
    done
    echo ""  # New line after dots
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
if wait_for_server; then
    echo "✅ Server is ready! Opening browser..."
    sleep 1  # Small additional delay to ensure everything is fully initialized
    open_browser
else
    echo ""
    echo "⚠️  Server didn't respond within timeout, but opening browser anyway..."
    echo "   If the page doesn't load, wait a few more seconds and refresh."
    open_browser
fi

# Wait for the ADK process (this will block until Ctrl+C)
wait $ADK_PID


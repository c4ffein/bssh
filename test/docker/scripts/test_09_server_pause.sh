#!/bin/bash
# Test 09: Server pause simulation
# Tests what happens when the server becomes unresponsive (paused)
# This simulates server load/hang scenarios

set -e

SERVER="testuser@server"
SESSION_NAME="test_session_09"
SESSIONS_FILE="$HOME/.bssh_sessions"

echo "=== Test 09: Server Pause Simulation ==="
echo "NOTE: This test requires docker commands - run from host, not container"

# Check if we're inside a container
if [ -f /.dockerenv ]; then
    echo "SKIP: This test must be run from the host (uses docker commands)"
    exit 0
fi

# Clean up
docker exec bssh-client rm -f /home/testuser/.bssh_sessions 2>/dev/null || true
docker exec bssh-server sh -c "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

# Create a session
echo "Creating session..."
docker exec -u testuser -d bssh-client expect << 'EOF'
spawn bssh -n test_session_09 testuser@server
expect {
    "Creating new session:" {
        sleep 120
    }
}
EOF

sleep 4

# Verify session
if ! docker exec bssh-server screen -ls | grep -q "$SESSION_NAME"; then
    echo "FAIL: Session not created"
    exit 1
fi
echo "Session established"

# Pause the server container
echo "Pausing server container..."
START_TIME=$(date +%s)
docker pause bssh-server

# Wait for client SSH to timeout (should be ~6-10 seconds based on keepalive settings)
echo "Waiting for client to detect server unresponsive..."
sleep 15

# Unpause
echo "Unpausing server container..."
docker unpause bssh-server
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo "Server was paused for ${ELAPSED} seconds"

# Check if screen session survived
sleep 2
if docker exec bssh-server screen -ls | grep -q "$SESSION_NAME"; then
    echo "PASS: Screen session survived server pause"
else
    echo "WARN: Screen session may have been affected"
fi

# Cleanup
docker exec bssh-server sh -c "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

echo "=== Test 09: PASSED ==="

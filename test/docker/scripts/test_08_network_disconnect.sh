#!/bin/bash
# Test 08: Docker network disconnect simulation
# Simulates complete network loss using docker network disconnect

set -e

SERVER="testuser@server"
SESSION_NAME="test_session_08"
SESSIONS_FILE="$HOME/.bssh_sessions"

echo "=== Test 08: Network Disconnect Simulation ==="
echo "NOTE: This test requires docker commands - run from host, not container"

# This test is designed to be run from the host machine, not inside the container
# It uses docker commands to manipulate the network

# Check if we're inside a container
if [ -f /.dockerenv ]; then
    echo "SKIP: This test must be run from the host (uses docker commands)"
    echo "Run: ./run_tests.sh --host-test 08"
    exit 0
fi

# Clean up any existing sessions
docker exec bssh-client rm -f /home/testuser/.bssh_sessions 2>/dev/null || true
docker exec bssh-server sh -c "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

# Create a session
echo "Creating session..."
docker exec -u testuser bssh-client expect << 'EOF'
spawn bssh -n test_session_08 testuser@server
expect {
    "Creating new session:" {
        sleep 2
        # Leave connected
    }
}
# Keep expect running
sleep 60
EOF &
DOCKER_PID=$!

sleep 4

# Verify session is running
if ! docker exec bssh-server screen -ls | grep -q "$SESSION_NAME"; then
    echo "FAIL: Session not created"
    kill $DOCKER_PID 2>/dev/null || true
    exit 1
fi
echo "Session established"

# Disconnect the client from the network
echo "Disconnecting client from network..."
START_TIME=$(date +%s)
docker network disconnect bssh_bssh-net bssh-client

# Wait and check
sleep 15

# Reconnect
echo "Reconnecting client to network..."
docker network connect bssh_bssh-net bssh-client --ip 172.28.0.20

# Verify screen session still exists
sleep 2
if docker exec bssh-server screen -ls | grep -q "$SESSION_NAME"; then
    echo "PASS: Session survived network disconnect"
else
    echo "FAIL: Session lost during network disconnect"
    exit 1
fi

# Cleanup
docker exec bssh-server sh -c "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true
kill $DOCKER_PID 2>/dev/null || true

echo "=== Test 08: PASSED ==="

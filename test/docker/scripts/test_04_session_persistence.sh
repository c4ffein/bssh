#!/bin/bash
# Test 04: Session persistence after connection loss
# Verifies that screen session survives connection loss and can be reconnected

set -e

SERVER="testuser@server"
SESSION_NAME="test_session_04"
SESSIONS_FILE="$HOME/.bssh_sessions"
UNIQUE_MARKER="PERSIST_$(date +%s)"

echo "=== Test 04: Session Persistence After Connection Loss ==="

# Clean up
rm -f "$SESSIONS_FILE"
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true
ssh $SERVER "rm -f /tmp/persist_marker" 2>/dev/null || true

# Step 1: Create session and set a marker
echo "Step 1: Creating session with marker..."
expect << EOF
spawn bssh -n $SESSION_NAME testuser@server
expect {
    "Creating new session:" {
        sleep 1
        send "echo '$UNIQUE_MARKER' > /tmp/persist_marker\r"
        sleep 0.5
        send "echo 'Marker set'\r"
        sleep 1
    }
}
# Stay connected briefly
sleep 2
EOF
EXPECT_PID=$!

# Give it time to set up
sleep 4

# Verify marker exists
if ! ssh $SERVER "cat /tmp/persist_marker" | grep -q "$UNIQUE_MARKER"; then
    echo "FAIL: Marker not set"
    exit 1
fi
echo "Marker verified on remote"

# Step 2: Kill the SSH connection abruptly (simulating network failure)
echo "Step 2: Killing SSH connection..."
pkill -f "ssh.*$SESSION_NAME" 2>/dev/null || true
sleep 1

# Step 3: Verify screen session still exists on server
echo "Step 3: Verifying session survives on server..."
if ssh $SERVER "screen -ls" | grep -q "$SESSION_NAME"; then
    echo "PASS: Screen session survived connection loss"
else
    echo "FAIL: Screen session died with connection"
    exit 1
fi

# Step 4: Reconnect and verify marker still accessible
echo "Step 4: Reconnecting to session..."
expect << EOF
spawn bssh -n $SESSION_NAME testuser@server
expect {
    "Reattaching to:" {
        sleep 1
        send "cat /tmp/persist_marker\r"
        expect "$UNIQUE_MARKER"
        sleep 0.5
        send "\x01d"
        expect eof
    }
    "Creating new session:" {
        puts "FAIL: Created new session instead of reattaching"
        exit 1
    }
    timeout {
        puts "TIMEOUT"
        exit 1
    }
}
EOF

echo "PASS: Successfully reconnected and marker intact"

# Cleanup
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true
ssh $SERVER "rm -f /tmp/persist_marker" 2>/dev/null || true

echo "=== Test 04: PASSED ==="

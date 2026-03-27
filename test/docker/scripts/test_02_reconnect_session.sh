#!/bin/bash
# Test 02: Reconnect to existing session
# Verifies that bssh can reconnect to an existing screen session

set -e

SERVER="testuser@server"
SESSION_NAME="test_session_02"
SESSIONS_FILE="$HOME/.bssh_sessions"
MARKER_FILE="/tmp/bssh_test_marker_$$"

echo "=== Test 02: Session Reconnection ==="

# Clean up
rm -f "$SESSIONS_FILE"
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true
ssh $SERVER "rm -f /tmp/test_marker" 2>/dev/null || true

# Step 1: Create initial session and leave a marker
echo "Step 1: Creating initial session..."
expect << 'EOF'
spawn bssh -n test_session_02 testuser@server
expect {
    "Creating new session:" {
        sleep 1
        # Create a marker file to prove we were here
        send "echo 'MARKER_CONTENT' > /tmp/test_marker\r"
        sleep 0.5
        # Detach
        send "\x01d"
        expect eof
    }
    timeout {
        puts "TIMEOUT"
        exit 1
    }
}
EOF

# Verify marker was created
echo "Verifying marker file..."
if ssh $SERVER "cat /tmp/test_marker" | grep -q "MARKER_CONTENT"; then
    echo "PASS: Marker file created"
else
    echo "FAIL: Marker file not found"
    exit 1
fi

# Step 2: Reconnect and verify we're in the same session
echo "Step 2: Reconnecting to session..."
expect << 'EOF'
spawn bssh -n test_session_02 testuser@server
expect {
    "Reattaching to:" {
        sleep 1
        # Check the marker file still exists (same session)
        send "cat /tmp/test_marker\r"
        expect "MARKER_CONTENT"
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

echo "PASS: Successfully reconnected to existing session"

# Cleanup
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true
ssh $SERVER "rm -f /tmp/test_marker" 2>/dev/null || true

echo "=== Test 02: PASSED ==="

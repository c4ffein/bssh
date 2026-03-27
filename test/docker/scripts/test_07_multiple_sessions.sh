#!/bin/bash
# Test 07: Multiple sessions
# Verifies handling of multiple sessions to the same host

set -e

SERVER="testuser@server"
SESSION_1="test_multi_01"
SESSION_2="test_multi_02"
SESSIONS_FILE="$HOME/.bssh_sessions"

echo "=== Test 07: Multiple Sessions ==="

# Clean up
rm -f "$SESSIONS_FILE"
ssh $SERVER "screen -ls | grep -E '(test_multi_01|test_multi_02)' | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

# Step 1: Create first session
echo "Step 1: Creating first session ($SESSION_1)..."
expect << 'EOF'
spawn bssh -n test_multi_01 testuser@server
expect {
    "Creating new session:" {
        sleep 1
        send "\x01d"
        expect eof
    }
}
EOF

# Step 2: Create second session
echo "Step 2: Creating second session ($SESSION_2)..."
expect << 'EOF'
spawn bssh -n test_multi_02 testuser@server
expect {
    "Creating new session:" {
        sleep 1
        send "\x01d"
        expect eof
    }
}
EOF

# Verify both exist on remote
echo "Verifying both sessions on remote..."
REMOTE_SESSIONS=$(ssh $SERVER "screen -ls" 2>/dev/null)
if echo "$REMOTE_SESSIONS" | grep -q "$SESSION_1" && \
   echo "$REMOTE_SESSIONS" | grep -q "$SESSION_2"; then
    echo "PASS: Both sessions exist on remote"
else
    echo "FAIL: Not all sessions on remote"
    echo "$REMOTE_SESSIONS"
    exit 1
fi

# Verify both tracked locally
echo "Verifying local tracking..."
if grep -q "server:$SESSION_1" "$SESSIONS_FILE" && \
   grep -q "server:$SESSION_2" "$SESSIONS_FILE"; then
    echo "PASS: Both sessions tracked locally"
else
    echo "FAIL: Not all sessions tracked locally"
    cat "$SESSIONS_FILE"
    exit 1
fi

# Step 3: Connect without specifying session (should show menu)
echo "Step 3: Testing session selection menu..."
expect << 'EOF'
spawn bssh testuser@server
expect {
    "Found existing sessions:" {
        expect "\[1\]"
        expect "\[2\]"
        expect "\[n\] Create new session"
        expect "Choice"
        # Select quit
        send "q\r"
        expect "Aborted"
        expect eof
    }
    timeout {
        puts "TIMEOUT waiting for session menu"
        exit 1
    }
}
EOF
echo "PASS: Session selection menu works"

# Cleanup
ssh $SERVER "screen -ls | grep -E '(test_multi_01|test_multi_02)' | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

echo "=== Test 07: PASSED ==="

#!/bin/bash
# Test 01: Create a new session
# Verifies that bssh creates a new screen session on the remote host

set -e

SERVER="testuser@server"
SESSION_NAME="test_session_01"
SESSIONS_FILE="$HOME/.bssh_sessions"

echo "=== Test 01: New Session Creation ==="

# Clean up any existing test sessions
rm -f "$SESSIONS_FILE"
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

# Create a new session with specific name, immediately detach
echo "Creating new session with name: $SESSION_NAME"
expect << 'EOF'
spawn bssh -n test_session_01 testuser@server
expect {
    "Creating new session:" {
        # Session created, now we're in screen
        # Send detach command (Ctrl-a d)
        sleep 1
        send "\x01d"
        expect eof
    }
    timeout {
        puts "TIMEOUT waiting for session creation"
        exit 1
    }
}
EOF

# Verify session exists on remote
echo "Verifying session on remote host..."
REMOTE_SESSIONS=$(ssh $SERVER "screen -ls" 2>/dev/null || true)
if echo "$REMOTE_SESSIONS" | grep -q "$SESSION_NAME"; then
    echo "PASS: Session found on remote host"
else
    echo "FAIL: Session not found on remote host"
    echo "Remote screen output: $REMOTE_SESSIONS"
    exit 1
fi

# Verify session is tracked locally
echo "Verifying local session tracking..."
if grep -q "server:$SESSION_NAME" "$SESSIONS_FILE" 2>/dev/null; then
    echo "PASS: Session tracked in local file"
else
    echo "FAIL: Session not tracked locally"
    echo "Sessions file content: $(cat $SESSIONS_FILE 2>/dev/null || echo 'empty')"
    exit 1
fi

# Cleanup
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

echo "=== Test 01: PASSED ==="

#!/bin/bash
# Test 05: Stale session cleanup
# Verifies that bssh -c removes sessions that no longer exist on remote

set -e

SERVER="testuser@server"
SESSION_NAME="test_session_05"
SESSIONS_FILE="$HOME/.bssh_sessions"

echo "=== Test 05: Stale Session Cleanup ==="

# Clean up
rm -f "$SESSIONS_FILE"
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

# Step 1: Create a session
echo "Step 1: Creating session..."
expect << 'EOF'
spawn bssh -n test_session_05 testuser@server
expect {
    "Creating new session:" {
        sleep 1
        send "\x01d"
        expect eof
    }
}
EOF

# Verify session tracked locally
if ! grep -q "server:$SESSION_NAME" "$SESSIONS_FILE"; then
    echo "FAIL: Session not tracked locally"
    exit 1
fi
echo "Session tracked locally"

# Verify session exists on remote
if ! ssh $SERVER "screen -ls" | grep -q "$SESSION_NAME"; then
    echo "FAIL: Session not on remote"
    exit 1
fi
echo "Session exists on remote"

# Step 2: Kill the screen session on remote (simulating crash/cleanup)
echo "Step 2: Killing screen session on remote..."
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill"
sleep 1

# Verify it's gone on remote
if ssh $SERVER "screen -ls" | grep -q "$SESSION_NAME"; then
    echo "FAIL: Session still exists on remote after kill"
    exit 1
fi
echo "Session killed on remote"

# Verify local file still has the entry (stale now)
if ! grep -q "server:$SESSION_NAME" "$SESSIONS_FILE"; then
    echo "FAIL: Session removed from local before cleanup"
    exit 1
fi
echo "Stale entry still in local file (expected)"

# Step 3: Run cleanup
echo "Step 3: Running bssh -c cleanup..."
OUTPUT=$(bssh -c 2>&1)
echo "$OUTPUT"

# Verify stale session was removed
if grep -q "server:$SESSION_NAME" "$SESSIONS_FILE" 2>/dev/null; then
    echo "FAIL: Stale session not cleaned up"
    cat "$SESSIONS_FILE"
    exit 1
fi
echo "PASS: Stale session cleaned from local file"

echo "=== Test 05: PASSED ==="

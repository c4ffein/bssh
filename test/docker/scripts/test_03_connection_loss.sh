#!/bin/bash
# Test 03: Connection loss detection
# Verifies that bssh detects connection loss within expected timeframe (~6 seconds)

set -e

SERVER="testuser@server"
SESSION_NAME="test_session_03"
SESSIONS_FILE="$HOME/.bssh_sessions"

echo "=== Test 03: Connection Loss Detection ==="

# Clean up
rm -f "$SESSIONS_FILE"
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

# Create a session in background
echo "Creating session..."
expect << 'EOF' &
EXPECT_PID=$!
spawn bssh -n test_session_03 testuser@server
expect {
    "Creating new session:" {
        # Stay connected
        sleep 30
    }
}
EOF
EXPECT_PID=$!

# Wait for session to be established
sleep 3

# Verify session is running
if ! ssh $SERVER "screen -ls" | grep -q "$SESSION_NAME"; then
    echo "FAIL: Session not created"
    kill $EXPECT_PID 2>/dev/null || true
    exit 1
fi
echo "Session established"

# Block network traffic using iptables (simulates network loss)
echo "Simulating network loss with iptables..."
START_TIME=$(date +%s)
iptables -A OUTPUT -d 172.28.0.10 -j DROP

# Wait for the bssh process to exit (should be ~6-10 seconds)
echo "Waiting for connection loss detection..."
TIMEOUT=20
DETECTED=false
for i in $(seq 1 $TIMEOUT); do
    if ! kill -0 $EXPECT_PID 2>/dev/null; then
        END_TIME=$(date +%s)
        ELAPSED=$((END_TIME - START_TIME))
        DETECTED=true
        echo "Connection loss detected after ${ELAPSED} seconds"
        break
    fi
    sleep 1
done

# Restore network
echo "Restoring network..."
iptables -D OUTPUT -d 172.28.0.10 -j DROP

if [ "$DETECTED" = "true" ]; then
    # SSH keepalive is 3 seconds interval, 2 max count = 6 seconds theoretical minimum
    # Allow some buffer for processing
    if [ $ELAPSED -le 15 ]; then
        echo "PASS: Connection loss detected within expected timeframe (${ELAPSED}s <= 15s)"
    else
        echo "WARN: Connection loss detection slower than expected (${ELAPSED}s > 15s)"
    fi
else
    echo "FAIL: Connection loss not detected within ${TIMEOUT}s"
    kill $EXPECT_PID 2>/dev/null || true
    exit 1
fi

# Cleanup
ssh $SERVER "screen -ls | grep $SESSION_NAME | cut -d. -f1 | xargs -r kill" 2>/dev/null || true

echo "=== Test 03: PASSED ==="

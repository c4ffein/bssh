#!/bin/bash
# Test 06: List sessions
# Verifies that bssh -l lists all tracked sessions

set -e

SERVER="testuser@server"
SESSIONS_FILE="$HOME/.bssh_sessions"

echo "=== Test 06: List Sessions ==="

# Clean up
rm -f "$SESSIONS_FILE"

# Step 1: Test with no sessions
echo "Step 1: Testing with no sessions..."
OUTPUT=$(bssh -l 2>&1)
if echo "$OUTPUT" | grep -q "No saved sessions"; then
    echo "PASS: Correctly reports no sessions"
else
    echo "FAIL: Expected 'No saved sessions'"
    echo "Got: $OUTPUT"
    exit 1
fi

# Step 2: Create some sessions manually in the tracking file
echo "Step 2: Adding test sessions..."
cat > "$SESSIONS_FILE" << 'EOF'
server:bssh_20240101_100000
server:bssh_20240101_110000
other-host:bssh_20240101_120000
EOF

# Step 3: List sessions
echo "Step 3: Listing sessions..."
OUTPUT=$(bssh -l 2>&1)
echo "$OUTPUT"

# Verify all sessions are listed
if echo "$OUTPUT" | grep -q "server -> bssh_20240101_100000" && \
   echo "$OUTPUT" | grep -q "server -> bssh_20240101_110000" && \
   echo "$OUTPUT" | grep -q "other-host -> bssh_20240101_120000"; then
    echo "PASS: All sessions listed correctly"
else
    echo "FAIL: Not all sessions listed"
    exit 1
fi

# Cleanup
rm -f "$SESSIONS_FILE"

echo "=== Test 06: PASSED ==="

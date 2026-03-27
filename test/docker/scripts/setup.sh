#!/bin/bash
# Setup script - copies SSH public key to server for passwordless auth

set -e

SERVER="testuser@server"

echo "=== Setting up SSH key authentication ==="

# Wait for server to be ready
echo "Waiting for SSH server..."
for i in $(seq 1 30); do
    if sshpass -p testpass ssh -o ConnectTimeout=2 $SERVER "echo ready" 2>/dev/null; then
        echo "Server is ready!"
        break
    fi
    sleep 1
done

# Copy public key to server
echo "Copying SSH public key to server..."
sshpass -p testpass ssh-copy-id -i ~/.ssh/id_ed25519.pub $SERVER 2>/dev/null

# Verify passwordless auth works
echo "Verifying passwordless authentication..."
if ssh -o BatchMode=yes $SERVER "echo 'SSH key auth working!'" 2>/dev/null; then
    echo "=== Setup complete ==="
else
    echo "ERROR: SSH key authentication failed"
    exit 1
fi

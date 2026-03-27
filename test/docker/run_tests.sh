#!/bin/bash
# Main test runner - run from the host machine
# Usage: ./run_tests.sh [options]
#
# Options:
#   --build       Force rebuild of Docker images
#   --shell       Start an interactive shell in the client container
#   --cleanup     Remove containers and images
#   --host-test N Run host-based test N (for tests requiring docker commands)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
BUILD=false
SHELL_MODE=false
CLEANUP=false
HOST_TEST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD=true
            shift
            ;;
        --shell)
            SHELL_MODE=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --host-test)
            HOST_TEST="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Cleanup mode
if [ "$CLEANUP" = true ]; then
    log_info "Cleaning up containers and images..."
    docker compose down -v --rmi local 2>/dev/null || true
    log_info "Cleanup complete"
    exit 0
fi

# Build/rebuild containers
if [ "$BUILD" = true ] || ! docker compose ps -q 2>/dev/null | grep -q .; then
    log_info "Building Docker images..."
    docker compose build
fi

# Start containers
log_info "Starting containers..."
docker compose up -d

# Wait for containers to be ready
log_info "Waiting for containers to be ready..."
sleep 3

# Install sshpass in client if not present (needed for initial key setup)
docker exec bssh-client apk add --no-cache sshpass 2>/dev/null || true

# Shell mode
if [ "$SHELL_MODE" = true ]; then
    log_info "Starting interactive shell in client container..."
    docker exec -it -u testuser bssh-client /bin/bash
    exit 0
fi

# Host-based test
if [ -n "$HOST_TEST" ]; then
    log_info "Running host-based test $HOST_TEST..."
    test_script="scripts/test_$(printf '%02d' $HOST_TEST)*.sh"
    # shellcheck disable=SC2086
    bash $test_script
    exit $?
fi

# Run all tests inside the container
log_info "Running tests inside container..."
echo ""

docker exec -u testuser bssh-client /home/testuser/tests/run_all_tests.sh
TEST_RESULT=$?

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    log_info "All tests passed!"
else
    log_error "Some tests failed"
fi

# Optionally leave containers running for debugging
# docker compose down

exit $TEST_RESULT

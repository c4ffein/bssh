#!/bin/bash
# Run all bssh tests inside the container

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASSED=0
FAILED=0
SKIPPED=0

echo "========================================"
echo "       BSSH Test Suite"
echo "========================================"
echo ""

# Run setup first
echo ">>> Running setup..."
if "$SCRIPT_DIR/setup.sh"; then
    echo ""
else
    echo "Setup failed!"
    exit 1
fi

# Find and run all test scripts
for test_script in "$SCRIPT_DIR"/test_*.sh; do
    test_name=$(basename "$test_script")
    echo ""
    echo "----------------------------------------"
    echo ">>> Running: $test_name"
    echo "----------------------------------------"

    if "$test_script"; then
        PASSED=$((PASSED + 1))
    else
        exit_code=$?
        if [ $exit_code -eq 0 ]; then
            SKIPPED=$((SKIPPED + 1))
        else
            FAILED=$((FAILED + 1))
            echo "FAILED: $test_name"
        fi
    fi
done

echo ""
echo "========================================"
echo "       Test Results"
echo "========================================"
echo "  Passed:  $PASSED"
echo "  Failed:  $FAILED"
echo "  Skipped: $SKIPPED"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi

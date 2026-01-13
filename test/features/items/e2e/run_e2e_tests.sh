#!/bin/bash

# Script to run E2E tests with Firebase emulator
# Usage: ./run_e2e_tests.sh

set -e

echo "========================================"
echo "Starting Firebase Emulator..."
echo "========================================"

cd ../../../../firebase

# Check if emulator is already running
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "Emulator is already running on port 8080"
    echo "Skipping emulator start"
else
    echo "Starting emulator in background..."
    firebase emulators:start &
    EMULATOR_PID=$!
    echo "Emulator PID: $EMULATOR_PID"
    echo "Waiting 15 seconds for emulator to start..."
    sleep 15
fi

echo ""
echo "========================================"
echo "Running E2E Tests..."
echo "========================================"

cd ../test/features/items/e2e
flutter test items_e2e_test.dart --reporter=expanded

echo ""
echo "========================================"
echo "E2E Tests Complete!"
echo "========================================"
echo ""
echo "To stop the emulator, run: pkill -f firebase"
echo ""

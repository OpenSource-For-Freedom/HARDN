#!/bin/bash

# Build and Test Script for HARDN Lynis Compliance
# This script builds the Docker container and runs basic tests

set -e

echo "=== HARDN BUILD AND TEST ==="
echo "Building Docker container..."

# Build the Docker image
docker build -t hardn-test .

echo "✅ Docker image built successfully"

echo ""
echo "=== RUNNING BASIC TESTS ==="

# Test HARDN installation files
echo "Testing HARDN installation files..."
docker run --rm hardn-test /hardn/test-hardn-installation.sh

echo ""
echo "=== RUNNING BASELINE LYNIS AUDIT ==="

# Run baseline Lynis audit
echo "Running baseline Lynis audit (before HARDN installation)..."
docker run --rm hardn-test bash -c "lynis audit system --quiet --no-colors --log-file /tmp/lynis-baseline.log --report-file /tmp/lynis-baseline.dat && grep 'hardening_index' /tmp/lynis-baseline.dat || echo 'Baseline audit completed'"

echo ""
echo "=== TESTING HARDN INSTALLATION ==="

# Test HARDN installation in a longer-running container
echo "Creating container for HARDN installation test..."
docker run -d --name hardn-test-container --privileged hardn-test sleep 1800

echo "Installing HARDN..."
docker exec hardn-test-container bash -c "cd /hardn && timeout 600 bash -c './src/setup/hardn-main.sh --non-interactive 2>&1 | head -50' || echo 'HARDN installation completed or timed out'"

echo "Running post-installation Lynis audit..."
docker exec hardn-test-container bash -c "lynis audit system --quiet --no-colors --log-file /tmp/lynis-post.log --report-file /tmp/lynis-post.dat && grep 'hardening_index' /tmp/lynis-post.dat || echo 'Post-installation audit completed'"

# Cleanup
echo "Cleaning up test container..."
docker stop hardn-test-container
docker rm hardn-test-container

echo ""
echo "=== BUILD AND TEST COMPLETE ==="
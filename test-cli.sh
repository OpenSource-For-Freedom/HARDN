#!/bin/bash

# Test script for HARDN-XDR during development
# Sets up the environment to test the modular CLI

set -e

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set up environment variables for testing
export HARDN_VERSION="2.0.0"
export HARDN_CONFIG_DIR="${SCRIPT_DIR}/usr/share/hardn/templates"
export HARDN_DATA_DIR="${SCRIPT_DIR}/usr/share/hardn"
export HARDN_LOG_DIR="/tmp/hardn-test/var/log/hardn"
export HARDN_LIB_DIR="/tmp/hardn-test/var/lib/hardn"
export HARDN_MODULES_DIR="${SCRIPT_DIR}/usr/share/hardn/modules"

# Create test directories
mkdir -p "${HARDN_LOG_DIR}"
mkdir -p "${HARDN_LIB_DIR}/backups"
mkdir -p "/tmp/hardn-test/etc/hardn"

# Copy configuration template for testing
cp "${SCRIPT_DIR}/usr/share/hardn/templates/hardn.conf" "/tmp/hardn-test/etc/hardn/"

echo "Test environment set up successfully"
echo "HARDN_MODULES_DIR: ${HARDN_MODULES_DIR}"
echo "HARDN_LOG_DIR: ${HARDN_LOG_DIR}"

# Test basic CLI functionality
echo ""
echo "Testing CLI functionality..."

# Test version
echo "Testing --version:"
"${SCRIPT_DIR}/usr/bin/hardn" --version

echo ""

# Test help
echo "Testing --help:"
"${SCRIPT_DIR}/usr/bin/hardn" --help

echo ""

# Test status (non-root, should show limited info)
echo "Testing status command:"
"${SCRIPT_DIR}/usr/bin/hardn" status || echo "Status command completed (may show warnings in test environment)"

echo ""
echo "Basic CLI tests completed successfully!"
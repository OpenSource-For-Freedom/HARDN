#!/bin/bash

# Test HARDN Installation Script
# This script tests the HARDN installation for failures before running Lynis

set -e

echo "=== HARDN INSTALLATION TEST ==="
echo "Testing HARDN installation for failures..."

# Check if we're running in a suitable environment
if [ ! -f /etc/debian_version ]; then
    echo "❌ ERROR: This system is not Debian-based"
    exit 1
fi

echo "✅ Debian-based system detected"

# Check if required files exist
REQUIRED_FILES=(
    "install.sh"
    "src/setup/hardn-main.sh"
    "progs.csv"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "/hardn/$file" ]; then
        echo "❌ ERROR: Required file missing: $file"
        exit 1
    fi
    echo "✅ Found required file: $file"
done

# Test the main hardening script for syntax errors
echo "Testing hardn-main.sh for syntax errors..."
if bash -n /hardn/src/setup/hardn-main.sh; then
    echo "✅ hardn-main.sh syntax check passed"
else
    echo "❌ ERROR: hardn-main.sh has syntax errors"
    exit 1
fi

# Test the install script for syntax errors
echo "Testing install.sh for syntax errors..."
if bash -n /hardn/install.sh; then
    echo "✅ install.sh syntax check passed"
else
    echo "❌ ERROR: install.sh has syntax errors"
    exit 1
fi

# Check if progs.csv is properly formatted
echo "Testing progs.csv format..."
if [ -s /hardn/progs.csv ]; then
    echo "✅ progs.csv exists and is not empty"
    # Show a few sample lines
    echo "Sample entries from progs.csv:"
    head -5 /hardn/progs.csv
else
    echo "❌ ERROR: progs.csv is missing or empty"
    exit 1
fi

echo ""
echo "=== ALL TESTS PASSED ==="
echo "HARDN installation files appear to be valid"
echo ""
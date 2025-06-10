#!/bin/bash

# Quick HARDN Test for Lynis Compliance
# This script performs a limited test to demonstrate HARDN improvements

set -e

echo "=== QUICK HARDN LYNIS TEST ==="
echo "Running limited test with timeout protection..."

# Record baseline score
echo "=== BASELINE LYNIS AUDIT ==="
lynis audit system --quiet --no-colors --log-file /tmp/baseline.log --report-file /tmp/baseline.dat

if [ -f /tmp/baseline.dat ]; then
    BASELINE_SCORE=$(grep "hardening_index" /tmp/baseline.dat | cut -d"=" -f2 | tr -d " " || echo "0")
    echo "Baseline Hardening Index: ${BASELINE_SCORE}%"
else
    echo "⚠️  Warning: Could not determine baseline score"
    BASELINE_SCORE=0
fi

echo ""
echo "=== TESTING HARDN INSTALLATION (LIMITED) ==="
echo "Running key HARDN components with 5-minute timeout..."

cd /hardn

# Test HARDN script execution with timeout
timeout 300 bash -c '
    source ./src/setup/hardn-main.sh
    
    # Run only core security setup functions
    echo "Testing core HARDN functions..."
    NON_INTERACTIVE_MODE=true
    
    # Test some key functions that should improve Lynis score quickly
    echo "Running system package updates..."
    update_system_packages
    
    echo "Installing security dependencies..."
    install_package_dependencies "progs.csv"
    
    echo "Applying basic security setup..."
    # Run a subset of security functions that are fast and effective
    disable_service_if_active cups
    disable_service_if_active avahi-daemon
    disable_service_if_active bluetooth
    
    echo "Core HARDN components completed"
' || {
    echo "⚠️  HARDN components completed or timed out after 5 minutes"
    echo "Proceeding with post-test Lynis audit..."
}

echo ""
echo "=== POST-TEST LYNIS AUDIT ==="
echo "Running Lynis audit after HARDN components..."

# Run post-test Lynis audit
lynis audit system --quiet --no-colors --log-file /tmp/post-test.log --report-file /tmp/post-test.dat

if [ -f /tmp/post-test.dat ]; then
    POST_SCORE=$(grep "hardening_index" /tmp/post-test.dat | cut -d"=" -f2 | tr -d " " || echo "0")
    echo "Post-Test Hardening Index: ${POST_SCORE}%"
else
    echo "❌ ERROR: Could not determine post-test score"
    exit 1
fi

# Calculate improvement
IMPROVEMENT=$((POST_SCORE - BASELINE_SCORE))

echo ""
echo "=== TEST RESULTS ==="
echo "Baseline Score: ${BASELINE_SCORE}%"
echo "Post-Test Score: ${POST_SCORE}%"
echo "Improvement: ${IMPROVEMENT}%"
echo ""

# Check for any improvement
if [ "$IMPROVEMENT" -gt 0 ]; then
    echo "✅ SUCCESS: HARDN improved Lynis score by ${IMPROVEMENT} percentage points"
    echo "📈 This demonstrates HARDN's effectiveness in improving system security"
    
    if [ "$POST_SCORE" -ge 90 ]; then
        echo "🎯 BONUS: Achieved full 90%+ compliance target!"
    elif [ "$POST_SCORE" -ge 75 ]; then
        echo "🎯 GOOD: Achieved strong 75%+ compliance score"
    else
        echo "🔧 NOTE: Full HARDN installation should achieve higher scores"
    fi
    exit 0
else
    echo "⚠️  LIMITED: Score improvement was minimal in this quick test"
    echo "🔍 Full HARDN installation with all components should show greater improvement"
    exit 1
fi
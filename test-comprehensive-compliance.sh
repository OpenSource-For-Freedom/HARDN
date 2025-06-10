#!/bin/bash

# Comprehensive HARDN Lynis Compliance Test
# This script performs a full test of HARDN installation and Lynis compliance validation

set -e

echo "=== HARDN LYNIS COMPLIANCE TEST ==="
echo "Running comprehensive test with timeout protection..."

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
echo "=== INSTALLING HARDN-XDR ==="
echo "Running HARDN installation with 15-minute timeout..."

# Install HARDN with timeout and capture output
cd /hardn
timeout 900 ./src/setup/hardn-main.sh --non-interactive 2>&1 | tail -20 || {
    echo "⚠️  HARDN installation completed or timed out"
    echo "Proceeding with post-installation Lynis audit..."
}

echo ""
echo "=== POST-INSTALLATION LYNIS AUDIT ==="
echo "Running Lynis audit after HARDN installation..."

# Run post-installation Lynis audit
lynis audit system --quiet --no-colors --log-file /tmp/post-hardn.log --report-file /tmp/post-hardn.dat

if [ -f /tmp/post-hardn.dat ]; then
    POST_SCORE=$(grep "hardening_index" /tmp/post-hardn.dat | cut -d"=" -f2 | tr -d " " || echo "0")
    echo "Post-HARDN Hardening Index: ${POST_SCORE}%"
else
    echo "❌ ERROR: Could not determine post-installation score"
    exit 1
fi

# Calculate improvement
IMPROVEMENT=$((POST_SCORE - BASELINE_SCORE))

echo ""
echo "=== COMPLIANCE RESULTS ==="
echo "Baseline Score: ${BASELINE_SCORE}%"
echo "Post-HARDN Score: ${POST_SCORE}%"
echo "Improvement: ${IMPROVEMENT}%"
echo ""

# Check compliance
if [ "$POST_SCORE" -ge 90 ]; then
    echo "✅ PASS: Lynis compliance score is ${POST_SCORE}% (>= 90%)"
    echo "🎯 HARDN successfully achieved full Lynis compliance!"
    echo "📈 Score improved by ${IMPROVEMENT} percentage points"
    exit 0
else
    echo "⚠️  PARTIAL: Lynis compliance score is ${POST_SCORE}% (< 90%)"
    if [ "$IMPROVEMENT" -gt 0 ]; then
        echo "📈 Score improved by ${IMPROVEMENT} percentage points (positive progress)"
        echo "🔧 Additional hardening may be needed to reach 90% threshold"
    else
        echo "📉 Score did not improve significantly"
        echo "🔍 Investigation needed for HARDN effectiveness"
    fi
    
    # Show some suggestions from Lynis
    echo ""
    echo "=== TOP LYNIS SUGGESTIONS ==="
    if [ -f /tmp/post-hardn.dat ]; then
        echo "Sample suggestions from Lynis report:"
        grep "suggestion\[\]" /tmp/post-hardn.dat | head -5 | sed 's/suggestion\[\]=/- /'
    fi
    
    exit 1
fi
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
    BASELINE_SCORE=$(grep "hardening_index" /tmp/baseline.dat | cut -d"=" -f2 | tr -d " " 2>/dev/null || echo "0")
    # Validate that BASELINE_SCORE is numeric
    if ! [[ "$BASELINE_SCORE" =~ ^[0-9]+$ ]]; then
        echo "⚠️  Warning: Invalid baseline score format: '$BASELINE_SCORE', using 0"
        BASELINE_SCORE=0
    fi
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
if timeout 900 ./src/setup/hardn-main.sh --non-interactive 2>&1 | tail -20; then
    echo "✅ HARDN installation completed successfully"
else
    echo "⚠️  HARDN installation completed with warnings or timed out (this is expected in some environments)"
    echo "Proceeding with post-installation Lynis audit..."
fi

echo ""
echo "=== POST-INSTALLATION LYNIS AUDIT ==="
echo "Running Lynis audit after HARDN installation..."

# Run post-installation Lynis audit
lynis audit system --quiet --no-colors --log-file /tmp/post-hardn.log --report-file /tmp/post-hardn.dat

if [ -f /tmp/post-hardn.dat ]; then
    POST_SCORE=$(grep "hardening_index" /tmp/post-hardn.dat | cut -d"=" -f2 | tr -d " " 2>/dev/null || echo "0")
    # Validate that POST_SCORE is numeric
    if ! [[ "$POST_SCORE" =~ ^[0-9]+$ ]]; then
        echo "⚠️  Warning: Invalid post-installation score format: '$POST_SCORE', using 0"
        POST_SCORE=0
    fi
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

# Generate remediation report regardless of pass/fail
echo ""
echo "=== GENERATING REMEDIATION REPORT ==="
echo "Creating comprehensive remediation guidance..."

# Ensure report directories exist
mkdir -p /var/log/hardn-reports /var/log/lynis

# Copy the Lynis report to expected location for report generator
if [ -f /tmp/post-hardn.dat ]; then
    cp /tmp/post-hardn.dat /var/log/lynis/hardn-report.dat
fi

# Run remediation report generator if available
if [ -f /hardn/src/setup/generate-remediation-report.sh ]; then
    echo "Running remediation report generator..."
    bash /hardn/src/setup/generate-remediation-report.sh
    if [ $? -eq 0 ]; then
        echo "✅ Remediation report generated successfully"
        echo "📁 Check /var/log/hardn-reports/ for detailed reports"
        
        # Show latest report files
        echo ""
        echo "=== GENERATED REPORTS ==="
        ls -la /var/log/hardn-reports/ 2>/dev/null || echo "No reports directory found"
        
        # Show a snippet of the latest remediation report
        LATEST_REPORT=$(ls -t /var/log/hardn-reports/remediation_report_*.md 2>/dev/null | head -1)
        if [ -f "$LATEST_REPORT" ]; then
            echo ""
            echo "=== REMEDIATION REPORT PREVIEW ==="
            head -30 "$LATEST_REPORT"
            echo ""
            echo "... (see full report at $LATEST_REPORT)"
        fi
    else
        echo "⚠️  Remediation report generation encountered issues"
    fi
else
    echo "⚠️  Remediation report generator not found"
fi

echo ""

# Check compliance
if [ "$POST_SCORE" -ge 90 ]; then
    echo "✅ PASS: Lynis compliance score is ${POST_SCORE}% (>= 90%)"
    echo "🎯 HARDN successfully achieved full Lynis compliance!"
    echo "📈 Score improved by ${IMPROVEMENT} percentage points"
    echo ""
    echo "🎉 SUCCESS: Full compliance achieved!"
    echo "📊 Detailed reports available for ongoing maintenance and optimization"
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
    
    echo ""
    echo "📋 REMEDIATION REQUIRED: Check the generated reports for specific guidance"
    echo "🎯 Target: $((90 - POST_SCORE)) additional points needed to reach 90%"
    echo "📁 Detailed remediation steps available in /var/log/hardn-reports/"
    
    exit 1
fi
#!/bin/bash

# HARDN Lynis Compliance Test Script
# Tests HARDN installation and validates Lynis compliance score >= 90%

set -e

echo "=== HARDN LYNIS COMPLIANCE TEST ==="
echo "Starting Lynis compliance validation..."

# Ensure we're running in the correct environment
if [ ! -f "/etc/debian_version" ]; then
    echo "ERROR: This test requires a Debian-based system"
    exit 1
fi

# Check if Lynis is available
if ! command -v lynis > /dev/null 2>&1; then
    echo "ERROR: Lynis is not installed"
    exit 1
fi

# Create directories for reports
mkdir -p /var/log/hardn-reports /var/log/lynis /tmp

echo "=== RUNNING BASELINE LYNIS AUDIT (BEFORE HARDN) ==="
lynis audit system --quiet --no-colors --log-file /tmp/lynis-baseline.log --report-file /tmp/lynis-baseline.dat || true

BASELINE_INDEX=$(grep 'hardening_index' /tmp/lynis-baseline.dat | cut -d'=' -f2 | tr -d ' ' 2>/dev/null || echo '0')
echo "Baseline Hardening Index: ${BASELINE_INDEX}%"

echo "=== INSTALLING HARDN HARDENING ==="
# Change to the HARDN directory and run installation
cd /hardn
if [ -f "./src/setup/hardn-main.sh" ]; then
    echo "Running HARDN installation in non-interactive mode..."
    timeout 1800 ./src/setup/hardn-main.sh --non-interactive || echo "HARDN installation completed (timeout or non-zero exit)"
else
    echo "ERROR: HARDN installation script not found"
    exit 1
fi

echo "=== RUNNING POST-HARDN LYNIS AUDIT ==="
lynis audit system --quiet --no-colors --log-file /tmp/lynis-post.log --report-file /tmp/lynis-post.dat

# Extract hardening index
HARDENING_INDEX=$(grep 'hardening_index' /tmp/lynis-post.dat | cut -d'=' -f2 | tr -d ' ' 2>/dev/null || echo '0')
echo "Post-HARDN Hardening Index: ${HARDENING_INDEX}%"

# Copy reports to log directory
cp /tmp/lynis-post.dat /var/log/lynis/hardn-report.dat 2>/dev/null || true
cp /tmp/lynis-post.log /var/log/lynis/hardn-audit.log 2>/dev/null || true

# Create score files for artifacts
echo "${HARDENING_INDEX}" > /var/log/hardn-reports/lynis-score.txt
cat > /var/log/hardn-reports/lynis-score.json << EOF
{
  "baseline_index": ${BASELINE_INDEX},
  "post_hardn_index": ${HARDENING_INDEX},
  "improvement": $((HARDENING_INDEX - BASELINE_INDEX)),
  "compliance_target": 90,
  "compliance_met": $([ "${HARDENING_INDEX}" -ge 90 ] && echo "true" || echo "false")
}
EOF

echo "=== COMPLIANCE VALIDATION ==="
echo "Baseline score: ${BASELINE_INDEX}%"
echo "Post-HARDN score: ${HARDENING_INDEX}%"
echo "Improvement: $((HARDENING_INDEX - BASELINE_INDEX))%"

if [ "${HARDENING_INDEX}" -ge 90 ]; then
    echo "✅ PASS: Lynis compliance score is ${HARDENING_INDEX}% (>= 90%)"
    echo "HARDN successfully achieved compliance target"
    exit 0
else
    echo "❌ FAIL: Lynis compliance score is ${HARDENING_INDEX}% (< 90%)"
    echo "Review the suggestions in the Lynis report to improve score"
    
    # Show some remediation suggestions
    if [ -f /tmp/lynis-post.dat ]; then
        echo "=== TOP REMEDIATION SUGGESTIONS ==="
        grep -E "suggestion\[" /tmp/lynis-post.dat | head -5 || true
    fi
    
    exit 1
fi
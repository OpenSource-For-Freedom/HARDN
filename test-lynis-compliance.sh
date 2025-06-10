#!/bin/bash

echo "Running Lynis security audit..."
lynis audit system --quiet --no-colors --log-file /tmp/lynis.log --report-file /tmp/lynis-report.dat

echo ""
echo "=== LYNIS AUDIT COMPLETE ==="
echo "Checking compliance score..."

if [ -f /tmp/lynis-report.dat ]; then
    HARDENING_INDEX=$(grep "hardening_index" /tmp/lynis-report.dat | cut -d"=" -f2 | tr -d " " 2>/dev/null || echo "0")
    # Validate that HARDENING_INDEX is numeric
    if ! echo "$HARDENING_INDEX" | grep -q "^[0-9]\+$"; then
        echo "⚠️  Warning: Invalid hardening index format: '$HARDENING_INDEX', using 0"
        HARDENING_INDEX=0
    fi
    echo "Hardening Index: $HARDENING_INDEX%"
    if [ "$HARDENING_INDEX" -ge 90 ]; then
        echo "✅ PASS: Lynis compliance score is $HARDENING_INDEX% (>= 90%)"
        exit 0
    else
        echo "❌ FAIL: Lynis compliance score is $HARDENING_INDEX% (< 90%)"
        exit 1
    fi
else
    echo "❌ ERROR: Lynis report file not found"
    exit 1
fi
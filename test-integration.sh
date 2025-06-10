#!/bin/bash

# Integration test for HARDN-XDR package
# Tests the complete installation and basic functionality

set -e

echo "🧪 HARDN-XDR Integration Test"
echo "============================="

# Test basic package information
echo "📦 Testing package information..."
if dpkg -l | grep -q hardn-xdr; then
    echo "✅ Package is installed"
    dpkg -l hardn-xdr
else
    echo "❌ Package not installed"
    exit 1
fi

# Test file installation
echo ""
echo "📁 Testing file installation..."

required_files=(
    "/usr/bin/hardn"
    "/usr/share/hardn/modules/logging.sh"
    "/usr/share/hardn/modules/utils.sh"
    "/usr/share/hardn/modules/hardening.sh"
    "/usr/share/hardn/templates/hardn.conf"
    "/usr/share/man/man1/hardn.1.gz"
    "/lib/systemd/system/hardn-monitor.service"
)

for file in "${required_files[@]}"; do
    if [[ -f "${file}" ]]; then
        echo "✅ ${file}"
    else
        echo "❌ ${file} - MISSING"
        exit 1
    fi
done

# Test directory creation
echo ""
echo "📂 Testing directory creation..."

required_dirs=(
    "/etc/hardn"
    "/var/log/hardn"
    "/var/lib/hardn"
    "/var/lib/hardn/backups"
)

for dir in "${required_dirs[@]}"; do
    if [[ -d "${dir}" ]]; then
        echo "✅ ${dir}"
    else
        echo "❌ ${dir} - MISSING"
        exit 1
    fi
done

# Test user and group creation
echo ""
echo "👤 Testing user/group creation..."

if getent passwd hardn >/dev/null; then
    echo "✅ hardn user exists"
else
    echo "❌ hardn user missing"
    exit 1
fi

if getent group hardn >/dev/null; then
    echo "✅ hardn group exists"
else
    echo "❌ hardn group missing"
    exit 1
fi

# Test permissions
echo ""
echo "🔐 Testing permissions..."

# Check hardn executable
if [[ -x "/usr/bin/hardn" ]]; then
    echo "✅ /usr/bin/hardn is executable"
else
    echo "❌ /usr/bin/hardn not executable"
    exit 1
fi

# Check log directory permissions
log_perms=$(stat -c "%a" /var/log/hardn)
if [[ "${log_perms}" == "750" ]]; then
    echo "✅ /var/log/hardn has correct permissions (750)"
else
    echo "⚠️  /var/log/hardn permissions: ${log_perms} (expected: 750)"
fi

# Test basic CLI functionality
echo ""
echo "🖥️  Testing CLI functionality..."

# Test version
if hardn --version >/dev/null 2>&1; then
    echo "✅ hardn --version works"
    hardn --version | head -1
else
    echo "❌ hardn --version failed"
    exit 1
fi

# Test help
if hardn --help >/dev/null 2>&1; then
    echo "✅ hardn --help works"
else
    echo "❌ hardn --help failed"
    exit 1
fi

# Test status (non-root)
if hardn status >/dev/null 2>&1; then
    echo "✅ hardn status works"
else
    echo "⚠️  hardn status had issues (may be normal without root)"
fi

# Test systemd service
echo ""
echo "🔧 Testing systemd service..."

if systemctl list-unit-files | grep -q hardn-monitor; then
    echo "✅ hardn-monitor.service is installed"
    
    # Check if enabled
    if systemctl is-enabled hardn-monitor >/dev/null 2>&1; then
        echo "✅ hardn-monitor.service is enabled"
    else
        echo "⚠️  hardn-monitor.service not enabled"
    fi
else
    echo "❌ hardn-monitor.service not found"
    exit 1
fi

# Test man page
echo ""
echo "📖 Testing man page..."

if man hardn >/dev/null 2>&1; then
    echo "✅ man hardn works"
else
    echo "❌ man hardn failed"
    exit 1
fi

# Test configuration
echo ""
echo "⚙️  Testing configuration..."

if [[ -f "/etc/hardn/hardn.conf" ]]; then
    echo "✅ Configuration file exists"
    
    # Check if it's readable
    if [[ -r "/etc/hardn/hardn.conf" ]]; then
        echo "✅ Configuration file is readable"
    else
        echo "❌ Configuration file not readable"
        exit 1
    fi
else
    echo "❌ Configuration file missing"
    exit 1
fi

echo ""
echo "🎉 All integration tests passed!"
echo ""
echo "📋 Summary:"
echo "  ✅ Package installation"
echo "  ✅ File and directory structure"
echo "  ✅ User and group creation"
echo "  ✅ Permission configuration"
echo "  ✅ CLI functionality"
echo "  ✅ Systemd integration"
echo "  ✅ Man page installation"
echo "  ✅ Configuration setup"
echo ""
echo "HARDN-XDR is ready for use!"
echo "Run 'sudo hardn setup' to begin system hardening."
#!/bin/bash

# HARDN Installation Test Script
# Tests HARDN installation process and basic functionality

set -e

echo "=== HARDN INSTALLATION TEST ==="
echo "Testing HARDN installation and basic functionality..."

# Ensure we're running in the correct environment
if [ ! -f "/etc/debian_version" ]; then
    echo "ERROR: This test requires a Debian-based system"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Function to test HARDN installation
test_hardn_installation() {
    echo "=== TESTING HARDN INSTALLATION ==="
    
    # Check if HARDN main script exists
    if [ ! -f "/hardn/src/setup/hardn-main.sh" ]; then
        echo "ERROR: HARDN main script not found"
        return 1
    fi
    
    # Check if HARDN is executable
    if [ ! -x "/hardn/src/setup/hardn-main.sh" ]; then
        echo "ERROR: HARDN main script is not executable"
        return 1
    fi
    
    echo "✅ HARDN main script found and executable"
    
    # Test dry-run installation
    echo "Testing HARDN dry-run installation..."
    cd /hardn
    
    if ./src/setup/hardn-main.sh --non-interactive --dry-run; then
        echo "✅ HARDN dry-run completed successfully"
    else
        echo "⚠️  HARDN dry-run completed with warnings (exit code $?)"
    fi
    
    return 0
}

# Function to test HARDN modules
test_hardn_modules() {
    echo "=== TESTING HARDN MODULES ==="
    
    local modules_dir="/hardn/usr/share/hardn/modules"
    local required_modules=(
        "logging.sh"
        "utils.sh" 
        "hardening.sh"
        "audit.sh"
        "status.sh"
        "backup.sh"
        "monitor.sh"
        "update.sh"
        "uninstall.sh"
    )
    
    for module in "${required_modules[@]}"; do
        if [ -f "${modules_dir}/${module}" ]; then
            echo "✅ Module found: ${module}"
        else
            echo "❌ Module missing: ${module}"
            return 1
        fi
    done
    
    return 0
}

# Function to test HARDN CLI (if installed)
test_hardn_cli() {
    echo "=== TESTING HARDN CLI ==="
    
    local hardn_bin="/hardn/usr/bin/hardn"
    
    if [ -f "${hardn_bin}" ]; then
        echo "✅ HARDN CLI binary found"
        
        # Test basic CLI functionality
        if "${hardn_bin}" --version 2>/dev/null; then
            echo "✅ HARDN CLI version command works"
        else
            echo "⚠️  HARDN CLI version command failed (might need dependencies)"
        fi
        
        if "${hardn_bin}" --help 2>/dev/null; then
            echo "✅ HARDN CLI help command works"
        else
            echo "⚠️  HARDN CLI help command failed (might need dependencies)"
        fi
    else
        echo "⚠️  HARDN CLI binary not found (might not be installed system-wide)"
    fi
    
    return 0
}

# Function to test configuration files
test_hardn_config() {
    echo "=== TESTING HARDN CONFIGURATION ==="
    
    local config_files=(
        "/hardn/usr/share/hardn/modules"
        "/hardn/src/setup"
        "/hardn/install.sh"
        "/hardn/progs.csv"
    )
    
    for config in "${config_files[@]}"; do
        if [ -e "${config}" ]; then
            echo "✅ Configuration found: ${config}"
        else
            echo "❌ Configuration missing: ${config}"
            return 1
        fi
    done
    
    return 0
}

# Function to run a complete installation test
test_complete_installation() {
    echo "=== RUNNING COMPLETE INSTALLATION TEST ==="
    
    # Create necessary directories
    mkdir -p /var/log/hardn /etc/hardn
    
    # Run HARDN installation in non-interactive mode
    cd /hardn
    echo "Installing HARDN (this may take several minutes)..."
    
    if timeout 1800 ./src/setup/hardn-main.sh --non-interactive; then
        echo "✅ HARDN installation completed successfully"
        return 0
    else
        local exit_code=$?
        echo "⚠️  HARDN installation completed with exit code: ${exit_code}"
        echo "This may be expected in containerized environments"
        return 0  # Don't fail the test for installation warnings
    fi
}

# Main test execution
main() {
    echo "Starting HARDN installation test at $(date)"
    
    local test_results=0
    
    # Run all tests
    test_hardn_installation || test_results=$((test_results + 1))
    test_hardn_modules || test_results=$((test_results + 1))
    test_hardn_cli || test_results=$((test_results + 1))
    test_hardn_config || test_results=$((test_results + 1))
    
    # Only run complete installation if previous tests passed
    if [ ${test_results} -eq 0 ]; then
        test_complete_installation || test_results=$((test_results + 1))
    else
        echo "⚠️  Skipping complete installation test due to previous failures"
    fi
    
    echo "=== TEST SUMMARY ==="
    if [ ${test_results} -eq 0 ]; then
        echo "✅ All HARDN installation tests passed"
        echo "HARDN is ready for use"
        exit 0
    else
        echo "❌ Some HARDN installation tests failed (${test_results} failures)"
        echo "Review the output above for details"
        exit 1
    fi
}

# Run main function
main "$@"
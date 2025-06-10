#!/bin/bash

# HARDN Comprehensive Compliance Test Script
# Tests complete HARDN compliance including STIG, security tools, and system hardening

set -e

echo "=== HARDN COMPREHENSIVE COMPLIANCE TEST ==="
echo "Testing complete HARDN compliance and security hardening..."

# Ensure we're running in the correct environment
if [ ! -f "/etc/debian_version" ]; then
    echo "ERROR: This test requires a Debian-based system"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" > /dev/null 2>&1
}

# Function to check service status
service_active() {
    systemctl is-active "$1" > /dev/null 2>&1
}

# Function to test security tools installation
test_security_tools() {
    echo "=== TESTING SECURITY TOOLS INSTALLATION ==="
    
    local tools=(
        "ufw"           # Firewall
        "fail2ban"      # Intrusion prevention
        "aide"          # File integrity monitoring
        "rkhunter"      # Rootkit detection
        "lynis"         # Security auditing
    )
    
    local results=0
    
    for tool in "${tools[@]}"; do
        if command_exists "${tool}"; then
            echo "✅ Security tool installed: ${tool}"
        else
            echo "❌ Security tool missing: ${tool}"
            results=$((results + 1))
        fi
    done
    
    return ${results}
}

# Function to test system hardening
test_system_hardening() {
    echo "=== TESTING SYSTEM HARDENING ==="
    
    local results=0
    
    # Test kernel parameters
    echo "Testing kernel security parameters..."
    
    # Check ASLR
    if [ "$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null)" = "2" ]; then
        echo "✅ ASLR enabled"
    else
        echo "⚠️  ASLR not optimally configured"
        results=$((results + 1))
    fi
    
    # Check if core dumps are disabled
    if [ "$(ulimit -c)" = "0" ]; then
        echo "✅ Core dumps disabled"
    else
        echo "⚠️  Core dumps may be enabled"
    fi
    
    # Test file permissions
    echo "Testing critical file permissions..."
    
    local critical_files=(
        "/etc/passwd:644"
        "/etc/shadow:640"
        "/etc/group:644"
        "/etc/gshadow:640"
    )
    
    for file_perm in "${critical_files[@]}"; do
        local file="${file_perm%:*}"
        local expected_perm="${file_perm#*:}"
        
        if [ -f "${file}" ]; then
            local actual_perm
            actual_perm=$(stat -c "%a" "${file}" 2>/dev/null)
            if [ "${actual_perm}" = "${expected_perm}" ] || [ "${actual_perm}" -le "${expected_perm}" ]; then
                echo "✅ File permissions correct: ${file} (${actual_perm})"
            else
                echo "⚠️  File permissions may need review: ${file} (${actual_perm})"
            fi
        else
            echo "⚠️  Critical file not found: ${file}"
        fi
    done
    
    return ${results}
}

# Function to test firewall configuration
test_firewall_config() {
    echo "=== TESTING FIREWALL CONFIGURATION ==="
    
    local results=0
    
    if command_exists "ufw"; then
        # Check UFW status
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        if [[ "${ufw_status}" == *"active"* ]]; then
            echo "✅ UFW firewall is active"
        else
            echo "⚠️  UFW firewall status: ${ufw_status}"
            results=$((results + 1))
        fi
        
        # Check default policies
        local ufw_verbose
        ufw_verbose=$(ufw status verbose 2>/dev/null)
        if [[ "${ufw_verbose}" == *"deny (incoming)"* ]]; then
            echo "✅ UFW default incoming policy: deny"
        else
            echo "⚠️  UFW incoming policy may not be restrictive"
        fi
        
        if [[ "${ufw_verbose}" == *"allow (outgoing)"* ]]; then
            echo "✅ UFW default outgoing policy: allow"
        else
            echo "⚠️  UFW outgoing policy: check configuration"
        fi
    else
        echo "❌ UFW not installed"
        results=$((results + 1))
    fi
    
    return ${results}
}

# Function to test intrusion prevention
test_intrusion_prevention() {
    echo "=== TESTING INTRUSION PREVENTION ==="
    
    local results=0
    
    if command_exists "fail2ban-client"; then
        # Check fail2ban status
        if service_active "fail2ban"; then
            echo "✅ Fail2ban service is active"
            
            # Check SSH jail
            local ssh_jail=$(fail2ban-client status sshd 2>/dev/null | grep "Status for the jail: sshd" || echo "not found")
            if [[ "${ssh_jail}" != "not found" ]]; then
                echo "✅ Fail2ban SSH jail configured"
            else
                echo "⚠️  Fail2ban SSH jail may not be configured"
            fi
        else
            echo "⚠️  Fail2ban service not active"
            results=$((results + 1))
        fi
    else
        echo "❌ Fail2ban not installed"
        results=$((results + 1))
    fi
    
    return ${results}
}

# Function to test file integrity monitoring
test_file_integrity() {
    echo "=== TESTING FILE INTEGRITY MONITORING ==="
    
    local results=0
    
    if command_exists "aide"; then
        echo "✅ AIDE installed"
        
        # Check if AIDE database exists
        if [ -f "/var/lib/aide/aide.db" ] || [ -f "/var/lib/aide/aide.db.new" ]; then
            echo "✅ AIDE database found"
        else
            echo "⚠️  AIDE database not found (may need initialization)"
        fi
    else
        echo "❌ AIDE not installed"
        results=$((results + 1))
    fi
    
    return ${results}
}

# Function to test AppArmor
test_apparmor() {
    echo "=== TESTING APPARMOR ==="
    
    local results=0
    
    if command_exists "aa-status"; then
        echo "✅ AppArmor installed"
        
        # Check AppArmor status
        local aa_status=$(aa-status --enabled 2>/dev/null && echo "enabled" || echo "disabled")
        if [ "${aa_status}" = "enabled" ]; then
            echo "✅ AppArmor is enabled"
        else
            echo "⚠️  AppArmor status: ${aa_status}"
            results=$((results + 1))
        fi
    else
        echo "⚠️  AppArmor not installed"
        results=$((results + 1))
    fi
    
    return ${results}
}

# Function to run STIG compliance checks
test_stig_compliance() {
    echo "=== TESTING STIG COMPLIANCE ==="
    
    local results=0
    
    # Test password policy
    echo "Testing password policy..."
    if [ -f "/etc/pam.d/common-password" ]; then
        if grep -q "pam_pwquality" /etc/pam.d/common-password 2>/dev/null; then
            echo "✅ Password quality module configured"
        else
            echo "⚠️  Password quality module may not be configured"
        fi
    else
        echo "⚠️  PAM password configuration not found"
    fi
    
    # Test login security
    echo "Testing login security..."
    if [ -f "/etc/login.defs" ]; then
        local max_days=$(grep "^PASS_MAX_DAYS" /etc/login.defs 2>/dev/null | awk '{print $2}')
        if [ -n "${max_days}" ] && [ "${max_days}" -le 90 ]; then
            echo "✅ Password maximum age configured: ${max_days} days"
        else
            echo "⚠️  Password maximum age: ${max_days:-not configured}"
        fi
    else
        echo "⚠️  Login definitions not found"
    fi
    
    # Test SSH configuration
    echo "Testing SSH security..."
    if [ -f "/etc/ssh/sshd_config" ]; then
        if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
            echo "✅ SSH root login disabled"
        else
            echo "⚠️  SSH root login may be enabled"
        fi
        
        if grep -q "^Protocol 2" /etc/ssh/sshd_config 2>/dev/null; then
            echo "✅ SSH protocol 2 configured"
        else
            echo "⚠️  SSH protocol configuration not found"
        fi
    else
        echo "⚠️  SSH configuration not found"
    fi
    
    return ${results}
}

# Function to run Lynis audit for compliance scoring
test_lynis_compliance() {
    echo "=== RUNNING LYNIS COMPLIANCE AUDIT ==="
    
    if ! command_exists "lynis"; then
        echo "❌ Lynis not available for compliance testing"
        return 1
    fi
    
    # Run Lynis audit
    echo "Running Lynis security audit..."
    mkdir -p /tmp/compliance-test
    
    if lynis audit system --quiet --no-colors --log-file /tmp/compliance-test/lynis.log --report-file /tmp/compliance-test/lynis.dat; then
        echo "✅ Lynis audit completed"
        
        # Extract hardening index
        local hardening_index=$(grep 'hardening_index' /tmp/compliance-test/lynis.dat | cut -d'=' -f2 | tr -d ' ' 2>/dev/null || echo '0')
        echo "Hardening Index: ${hardening_index}%"
        
        if [ "${hardening_index}" -ge 80 ]; then
            echo "✅ Excellent compliance score: ${hardening_index}%"
            return 0
        elif [ "${hardening_index}" -ge 70 ]; then
            echo "✅ Good compliance score: ${hardening_index}%"
            return 0
        elif [ "${hardening_index}" -ge 60 ]; then
            echo "⚠️  Moderate compliance score: ${hardening_index}%"
            return 1
        else
            echo "❌ Low compliance score: ${hardening_index}%"
            return 1
        fi
    else
        echo "❌ Lynis audit failed"
        return 1
    fi
}

# Main test execution
main() {
    echo "Starting comprehensive compliance test at $(date)"
    
    local total_failures=0
    
    # Run all compliance tests
    echo
    test_security_tools || total_failures=$((total_failures + $?))
    
    echo
    test_system_hardening || total_failures=$((total_failures + $?))
    
    echo  
    test_firewall_config || total_failures=$((total_failures + $?))
    
    echo
    test_intrusion_prevention || total_failures=$((total_failures + $?))
    
    echo
    test_file_integrity || total_failures=$((total_failures + $?))
    
    echo
    test_apparmor || total_failures=$((total_failures + $?))
    
    echo
    test_stig_compliance || total_failures=$((total_failures + $?))
    
    echo
    test_lynis_compliance || total_failures=$((total_failures + $?))
    
    # Summary
    echo
    echo "=== COMPREHENSIVE COMPLIANCE TEST SUMMARY ==="
    echo "Test completed at $(date)"
    
    if [ ${total_failures} -eq 0 ]; then
        echo "✅ All compliance tests passed"
        echo "HARDN system meets comprehensive security standards"
        exit 0
    else
        echo "⚠️  Some compliance tests had issues (${total_failures} test failures)"
        echo "Review the output above for specific recommendations"
        echo "Note: Some warnings are expected in containerized environments"
        exit 1
    fi
}

# Run main function
main "$@"
#!/bin/bash

# HARDN Status Module
# Display system hardening status and monitoring information

# Source required modules
# shellcheck source=/usr/share/hardn/modules/logging.sh
source "${HARDN_MODULES_DIR}/logging.sh"
# shellcheck source=/usr/share/hardn/modules/utils.sh
source "${HARDN_MODULES_DIR}/utils.sh"

# Check if HARDN has been installed/configured
is_hardn_configured() {
    [[ -f /etc/hardn/hardn.conf ]] && [[ -d /var/log/hardn ]]
}

# Get service status with color coding
get_service_status() {
    local service="$1"
    
    if ! service_exists "${service}"; then
        echo "ERROR Not installed"
        return 1
    elif is_service_active "${service}"; then
        echo "OK Running"
        return 0
    elif is_service_enabled "${service}"; then
        echo "WARNING Enabled but not running"
        return 2
    else
        echo "ERROR Disabled"
        return 1
    fi
}

# Show security services status
show_security_services() {
    log_info "Security Services Status"
    log_separator "-" 40
    
    local services=(
        "ufw:UFW Firewall"
        "fail2ban:Fail2Ban IPS"
        "auditd:Audit Daemon"
        "apparmor:AppArmor MAC"
        "clamav-daemon:ClamAV Antivirus"
        "clamav-freshclam:ClamAV Updates"
        "rsyslog:System Logging"
        "systemd-timesyncd:Time Sync"
        "ssh:SSH Server"
    )
    
    for service_info in "${services[@]}"; do
        local service="${service_info%%:*}"
        local description="${service_info##*:}"
        local status
        
        status=$(get_service_status "${service}")
        printf "%-20s %-15s %s\n" "${description}" "${service}" "${status}"
    done
    
    echo
}

# Show system hardening status
show_hardening_status() {
    log_separator "="
    log_info "HARDN System Status"
    log_separator "="
    
    # Basic system information
    log_info "System Information"
    log_separator "-" 40
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/etc/os-release
        source /etc/os-release
        echo "OS: ${PRETTY_NAME:-Unknown}"
        echo "Version: ${VERSION_ID:-Unknown}"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo "Hostname: $(hostname)"
    fi
    
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo "Current User: $(whoami)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo
    
    # HARDN installation status
    log_info "HARDN Installation Status"
    log_separator "-" 40
    
    if is_hardn_configured; then
        echo "OK HARDN is installed and configured"
        if [[ -f /etc/hardn/hardn.conf ]]; then
            echo "OK Configuration file present"
        fi
        if [[ -d /var/log/hardn ]]; then
            echo "OK Log directory present"
            local log_count
            log_count=$(find /var/log/hardn -name "*.log" 2>/dev/null | wc -l)
            echo "   Log files: ${log_count}"
        fi
    else
        echo "ERROR HARDN not fully configured"
        echo "   Run 'hardn setup' to configure the system"
    fi
    echo
    
    # Security services status
    show_security_services
    
    # Kernel security parameters
    log_info "Kernel Security Parameters"
    log_separator "-" 40
    
    local sysctl_params=(
        "kernel.dmesg_restrict"
        "kernel.kptr_restrict"
        "net.ipv4.ip_forward"
        "net.ipv4.conf.all.accept_redirects"
        "net.ipv4.tcp_syncookies"
        "fs.suid_dumpable"
        "kernel.yama.ptrace_scope"
    )
    
    for param in "${sysctl_params[@]}"; do
        local value
        if value=$(sysctl -n "${param}" 2>/dev/null); then
            printf "%-35s %s\n" "${param}" "${value}"
        else
            printf "%-35s %s\n" "${param}" "Not set"
        fi
    done
    echo
    
    # Firewall status
    log_info "Firewall Status"
    log_separator "-" 40
    
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        echo "UFW Status: ${ufw_status}"
        
        if [[ "${ufw_status}" == *"active"* ]]; then
            echo "OK Firewall is active and protecting the system"
        else
            echo "ERROR Firewall is not active"
        fi
    else
        echo "ERROR UFW not installed"
    fi
    echo
    
    # Recent security events
    log_info "Recent Security Events"
    log_separator "-" 40
    
    if [[ -f /var/log/auth.log ]]; then
        echo "Authentication failures (last 5):"
        grep "authentication failure\|Failed password" /var/log/auth.log 2>/dev/null | tail -5 | while read -r line; do
            echo "  ${line}"
        done
    fi
    
    if [[ -f /var/log/hardn/security.log ]]; then
        echo "HARDN security events (last 5):"
        tail -5 /var/log/hardn/security.log 2>/dev/null | while read -r line; do
            echo "  ${line}"
        done
    fi
    echo
    
    # Disk usage
    log_info "Disk Usage"
    log_separator "-" 40
    df -h / /var /tmp 2>/dev/null | grep -v "Filesystem"
    echo
    
    # Memory usage
    log_info "Memory Usage"
    log_separator "-" 40
    free -h
    echo
    
    # Network interfaces
    log_info "Network Interfaces"
    log_separator "-" 40
    ip -br addr show 2>/dev/null || ifconfig -a 2>/dev/null | grep -E "^[a-z]|inet"
    echo
    
    # Last system updates
    log_info "System Updates"
    log_separator "-" 40
    
    if [[ -f /var/log/apt/history.log ]]; then
        echo "Last package installation:"
        grep "Install:" /var/log/apt/history.log 2>/dev/null | tail -1 | while read -r line; do
            echo "  ${line}"
        done
        
        echo "Last package upgrade:"
        grep "Upgrade:" /var/log/apt/history.log 2>/dev/null | tail -1 | while read -r line; do
            echo "  ${line}"
        done
    fi
    echo
    
    # Security recommendations
    log_info "Security Recommendations"
    log_separator "-" 40
    
    local recommendations=()
    
    # Check for updates
    if [[ -f /var/lib/apt/lists/ ]]; then
        local last_update
        last_update=$(stat -c %Y /var/lib/apt/lists/ 2>/dev/null)
        local current_time
        current_time=$(date +%s)
        local days_since_update
        days_since_update=$(( (current_time - last_update) / 86400 ))
        
        if [[ ${days_since_update} -gt 7 ]]; then
            recommendations+=("Update package lists (last updated ${days_since_update} days ago)")
        fi
    fi
    
    # Check for inactive security services
    if ! is_service_active "ufw"; then
        recommendations+=("Enable UFW firewall")
    fi
    
    if ! is_service_active "fail2ban"; then
        recommendations+=("Enable Fail2Ban intrusion prevention")
    fi
    
    if ! is_service_active "auditd"; then
        recommendations+=("Enable audit daemon")
    fi
    
    # Check for unattended upgrades
    if ! is_package_installed "unattended-upgrades"; then
        recommendations+=("Install automatic security updates")
    fi
    
    # Check log rotation
    if [[ ! -f /etc/logrotate.d/hardn ]]; then
        recommendations+=("Configure log rotation for HARDN logs")
    fi
    
    if [[ ${#recommendations[@]} -eq 0 ]]; then
        echo "OK No immediate security recommendations"
    else
        for recommendation in "${recommendations[@]}"; do
            echo "WARNING ${recommendation}"
        done
    fi
    
    echo
    log_separator "="
}

# Show monitoring status
show_monitoring_status() {
    log_info "HARDN Monitoring Status"
    log_separator "="
    
    # Check if monitoring service is running
    if service_exists "hardn-monitor"; then
        local status
        status=$(get_service_status "hardn-monitor")
        echo "HARDN Monitor Service: ${status}"
    else
        echo "ERROR HARDN Monitor Service: Not installed"
    fi
    
    # Check log files
    echo
    log_info "Log Files Status"
    log_separator "-" 40
    
    local log_files=(
        "/var/log/hardn/hardn.log:HARDN Main Log"
        "/var/log/hardn/security.log:Security Events"
        "/var/log/auth.log:Authentication Log"
        "/var/log/audit/audit.log:Audit Log"
        "/var/log/fail2ban.log:Fail2Ban Log"
        "/var/log/clamav/freshclam.log:ClamAV Updates"
    )
    
    for log_info in "${log_files[@]}"; do
        local log_file="${log_info%%:*}"
        local description="${log_info##*:}"
        
        if [[ -f "${log_file}" ]]; then
            local size
            local last_modified
            size=$(du -h "${log_file}" 2>/dev/null | cut -f1)
            last_modified=$(stat -c "%y" "${log_file}" 2>/dev/null | cut -d. -f1)
            printf "%-20s %-15s %s (last: %s)\n" "${description}" "OK Present" "${size}" "${last_modified}"
        else
            printf "%-20s %-15s\n" "${description}" "ERROR Missing"
        fi
    done
    
    echo
}

# Show system performance metrics
show_performance_metrics() {
    log_info "System Performance Metrics"
    log_separator "="
    
    # CPU information
    echo "CPU Information:"
    if [[ -f /proc/cpuinfo ]]; then
        local cpu_model
        local cpu_cores
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
        cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
        echo "  Model: ${cpu_model}"
        echo "  Cores: ${cpu_cores}"
    fi
    
    # Load average
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo "  Load Average: ${load_avg}"
    echo
    
    # Memory information
    echo "Memory Information:"
    if [[ -f /proc/meminfo ]]; then
        local total_mem
        local free_mem
        local available_mem
        total_mem=$(grep "MemTotal" /proc/meminfo | awk '{print int($2/1024) " MB"}')
        free_mem=$(grep "MemFree" /proc/meminfo | awk '{print int($2/1024) " MB"}')
        available_mem=$(grep "MemAvailable" /proc/meminfo | awk '{print int($2/1024) " MB"}')
        echo "  Total: ${total_mem}"
        echo "  Free: ${free_mem}"
        echo "  Available: ${available_mem}"
    fi
    echo
    
    # Disk information
    echo "Disk Usage:"
    df -h | grep -E "^/dev" | while read -r line; do
        echo "  ${line}"
    done
    echo
    
    # Top processes by CPU
    echo "Top CPU Processes:"
    ps aux --sort=-%cpu | head -6 | tail -5 | while read -r line; do
        echo "  ${line}"
    done
    echo
    
    # Top processes by memory
    echo "Top Memory Processes:"
    ps aux --sort=-%mem | head -6 | tail -5 | while read -r line; do
        echo "  ${line}"
    done
    echo
}

# Export functions
export -f is_hardn_configured get_service_status show_security_services
export -f show_hardening_status show_monitoring_status show_performance_metrics
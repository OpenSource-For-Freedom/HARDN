#!/bin/bash

# HARDN Monitor Module
# System monitoring and service management

# Source required modules
# shellcheck source=/usr/share/hardn/modules/logging.sh
source "${HARDN_MODULES_DIR}/logging.sh"
# shellcheck source=/usr/share/hardn/modules/utils.sh
source "${HARDN_MODULES_DIR}/utils.sh"

# Start monitoring services
start_monitoring_services() {
    log_info "Starting HARDN monitoring services..."
    
    local services=(
        "ufw:UFW Firewall"
        "fail2ban:Fail2Ban IPS"
        "auditd:Audit System"
        "apparmor:AppArmor MAC"
        "clamav-daemon:ClamAV Daemon"
        "rsyslog:System Logging"
    )
    
    for service_info in "${services[@]}"; do
        local service="${service_info%%:*}"
        local description="${service_info##*:}"
        
        enable_service "${service}" "${description}"
    done
    
    # Start HARDN monitor service if it exists
    if service_exists "hardn-monitor"; then
        enable_service "hardn-monitor" "HARDN Monitor"
    fi
    
    hardn_status "pass" "Monitoring services started"
}

# Stop monitoring services
stop_monitoring_services() {
    log_info "Stopping HARDN monitoring services..."
    
    local services=(
        "hardn-monitor:HARDN Monitor"
        "fail2ban:Fail2Ban IPS"
        "clamav-daemon:ClamAV Daemon"
    )
    
    for service_info in "${services[@]}"; do
        local service="${service_info%%:*}"
        local description="${service_info##*:}"
        
        if service_exists "${service}"; then
            disable_service "${service}" "${description}"
        fi
    done
    
    hardn_status "pass" "Monitoring services stopped"
}

# Restart monitoring services
restart_monitoring_services() {
    log_info "Restarting HARDN monitoring services..."
    
    stop_monitoring_services
    sleep 2
    start_monitoring_services
    
    hardn_status "pass" "Monitoring services restarted"
}

# Show monitoring status
show_monitoring_status() {
    log_info "HARDN Monitoring Status"
    log_separator "=" 50
    
    local services=(
        "hardn-monitor:HARDN Monitor Service"
        "ufw:UFW Firewall"
        "fail2ban:Fail2Ban IPS"
        "auditd:Audit System"
        "apparmor:AppArmor MAC"
        "clamav-daemon:ClamAV Daemon" 
        "clamav-freshclam:ClamAV Updates"
        "rsyslog:System Logging"
    )
    
    for service_info in "${services[@]}"; do
        local service="${service_info%%:*}"
        local description="${service_info##*:}"
        local status
        
        status=$(get_service_status "${service}")
        printf "%-25s %s\n" "${description}" "${status}"
    done
    
    echo
    
    # Show system resource usage
    log_info "System Resources"
    log_separator "-" 30
    
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}' | xargs)"
    echo "Memory Usage: $(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')"
    echo "Disk Usage: $(df / | awk 'NR==2{print $5}')"
    
    echo
    
    # Show recent security events
    log_info "Recent Security Events"
    log_separator "-" 30
    
    if [[ -f /var/log/fail2ban.log ]]; then
        local bans
        bans=$(grep "Ban " /var/log/fail2ban.log 2>/dev/null | tail -3)
        if [[ -n "${bans}" ]]; then
            echo "Recent Fail2Ban actions:"
            echo "${bans}" | while read -r line; do
                echo "  ${line}"
            done
        else
            echo "No recent Fail2Ban actions"
        fi
    fi
    
    echo
}

# Export functions
export -f start_monitoring_services stop_monitoring_services
export -f restart_monitoring_services show_monitoring_status
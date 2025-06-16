#!/bin/bash

# HARDN Update Module
# Update security configurations and tools

# Source required modules
# shellcheck source=/usr/share/hardn/modules/logging.sh
source "${HARDN_MODULES_DIR}/logging.sh"
# shellcheck source=/usr/share/hardn/modules/utils.sh
source "${HARDN_MODULES_DIR}/utils.sh"

# Update security configurations
update_security_configs() {
    log_info "Updating HARDN security configurations..."
    
    # Update package lists
    update_package_lists
    
    # Update ClamAV definitions
    update_clamav_definitions
    
    # Update rkhunter database
    update_rkhunter_database
    
    # Update Fail2Ban filters
    update_fail2ban_filters
    
    # Restart services to apply updates
    restart_security_services
    
    hardn_status "pass" "Security configurations updated"
}

# Update ClamAV virus definitions
update_clamav_definitions() {
    log_info "Updating ClamAV virus definitions..."
    
    if ! command -v freshclam >/dev/null 2>&1; then
        log_warn "ClamAV not installed, skipping definition update"
        return 1
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would update ClamAV definitions"
        return 0
    fi
    
    if freshclam --quiet; then
        hardn_status "pass" "ClamAV definitions updated successfully"
    else
        hardn_status "warning" "ClamAV definition update failed"
        return 1
    fi
}

# Update rkhunter database
update_rkhunter_database() {
    log_info "Updating rkhunter database..."
    
    if ! command -v rkhunter >/dev/null 2>&1; then
        log_warn "rkhunter not installed, skipping database update"
        return 1
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would update rkhunter database"
        return 0
    fi
    
    if rkhunter --update --quiet; then
        hardn_status "pass" "rkhunter database updated successfully"
        
        # Also update file properties database
        if rkhunter --propupd --quiet; then
            log_debug "rkhunter file properties updated"
        fi
    else
        hardn_status "warning" "rkhunter database update failed"
        return 1
    fi
}

# Update Fail2Ban filters
update_fail2ban_filters() {
    log_info "Updating Fail2Ban filters..."
    
    if ! is_service_active "fail2ban"; then
        log_warn "Fail2Ban not running, skipping filter update"
        return 1
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would update Fail2Ban filters"
        return 0
    fi
    
    # Reload Fail2Ban to pick up any filter updates
    if systemctl reload fail2ban; then
        hardn_status "pass" "Fail2Ban filters reloaded"
    else
        hardn_status "warning" "Failed to reload Fail2Ban filters"
        return 1
    fi
}

# Restart security services
restart_security_services() {
    log_info "Restarting security services..."
    
    local services=(
        "fail2ban"
        "clamav-daemon"
        "clamav-freshclam"
    )
    
    for service in "${services[@]}"; do
        if is_service_active "${service}"; then
            if is_dry_run; then
                log_info "[DRY-RUN] Would restart ${service}"
            else
                log_debug "Restarting ${service}..."
                if systemctl restart "${service}"; then
                    log_debug "${service} restarted successfully"
                else
                    log_warn "Failed to restart ${service}"
                fi
            fi
        fi
    done
    
    hardn_status "pass" "Security services restarted"
}

# Update system packages (security updates only)
update_security_packages() {
    log_info "Installing security updates..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would install security updates"
        return 0
    fi
    
    # Update package lists
    update_package_lists
    
    # Install security updates
    if DEBIAN_FRONTEND=noninteractive apt-get -s upgrade | grep -i security >/dev/null; then
        log_info "Security updates available, installing..."
        
        if DEBIAN_FRONTEND=noninteractive apt-get -y upgrade; then
            hardn_status "pass" "Security updates installed successfully"
            
            # Check if reboot is required
            if [[ -f /var/run/reboot-required ]]; then
                hardn_status "warning" "System reboot required to complete updates"
            fi
        else
            hardn_status "error" "Failed to install security updates"
            return 1
        fi
    else
        hardn_status "pass" "No security updates available"
    fi
}

# Update AIDE database
update_aide_database() {
    log_info "Updating AIDE integrity database..."
    
    if ! command -v aide >/dev/null 2>&1; then
        log_warn "AIDE not installed, skipping database update"
        return 1
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would update AIDE database"
        return 0
    fi
    
    # Create new AIDE database
    log_info "Creating new AIDE database (this may take a while)..."
    
    if aide --init >/dev/null 2>&1; then
        # Move new database to active location
        if [[ -f /var/lib/aide/aide.db.new ]]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
            hardn_status "pass" "AIDE database updated successfully"
        fi
    else
        hardn_status "error" "Failed to update AIDE database"
        return 1
    fi
}

# Show update status
show_update_status() {
    log_info "HARDN Update Status"
    log_separator "=" 40
    
    # Check last update times
    echo "Last package update:"
    if [[ -f /var/lib/apt/lists/ ]]; then
        local last_update
        last_update=$(stat -c %Y /var/lib/apt/lists/ 2>/dev/null)
        local current_time
        current_time=$(date +%s)
        local days_since_update
        days_since_update=$(( (current_time - last_update) / 86400 ))
        echo "  ${days_since_update} days ago"
    else
        echo "  Unknown"
    fi
    
    echo "Last ClamAV update:"
    if [[ -f /var/log/clamav/freshclam.log ]]; then
        local last_clamav_update
        last_clamav_update=$(tail -1 /var/log/clamav/freshclam.log 2>/dev/null | awk '{print $1, $2}')
        echo "  ${last_clamav_update:-Unknown}"
    else
        echo "  Unknown"
    fi
    
    echo "System uptime:"
    echo "  $(uptime -p 2>/dev/null || uptime)"
    
    echo
    
    # Check for available updates
    echo "Available updates:"
    if command -v apt >/dev/null 2>&1; then
        local update_count
        update_count=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
        echo "  ${update_count} packages can be upgraded"
        
        local security_count
        security_count=$(apt list --upgradable 2>/dev/null | grep -c security)
        if [[ ${security_count} -gt 0 ]]; then
            echo "  ${security_count} security updates available"
        fi
    fi
    
    echo
}

# Export functions
export -f update_security_configs update_clamav_definitions
export -f update_rkhunter_database update_fail2ban_filters
export -f restart_security_services update_security_packages
export -f update_aide_database show_update_status
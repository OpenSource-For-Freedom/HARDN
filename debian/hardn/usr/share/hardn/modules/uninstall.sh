#!/bin/bash

# HARDN Uninstall Module
# Remove HARDN hardening and restore system

# Source required modules
# shellcheck source=/usr/share/hardn/modules/logging.sh
source "${HARDN_MODULES_DIR}/logging.sh"
# shellcheck source=/usr/share/hardn/modules/utils.sh
source "${HARDN_MODULES_DIR}/utils.sh"

# Remove HARDN hardening
remove_hardening() {
    log_warn "Removing HARDN hardening..."
    
    if ! confirm_action "This will remove HARDN security hardening. Are you sure?" "n"; then
        log_info "Uninstall cancelled"
        return 0
    fi
    
    if ! confirm_action "This action cannot be easily undone. Continue?" "n"; then
        log_info "Uninstall cancelled"
        return 0
    fi
    
    # Create backup before removal
    log_info "Creating backup before removal..."
    # shellcheck source=/usr/share/hardn/modules/backup.sh
    source "${HARDN_MODULES_DIR}/backup.sh"
    create_system_backup "pre-uninstall-$(date +%Y%m%d_%H%M%S)"
    
    # Remove HARDN configuration files
    remove_hardn_configs
    
    # Restore original configurations
    restore_original_configs
    
    # Remove HARDN services
    remove_hardn_services
    
    # Optionally remove security packages
    if confirm_action "Remove installed security packages?" "n"; then
        remove_security_packages
    fi
    
    hardn_status "pass" "HARDN hardening removed"
    log_info "System has been restored to pre-HARDN state"
    log_info "Please reboot the system to complete the removal"
}

# Remove HARDN configuration files
remove_hardn_configs() {
    log_info "Removing HARDN configuration files..."
    
    local config_files=(
        "/etc/sysctl.d/99-hardn-security.conf"
        "/etc/audit/rules.d/hardn-audit.rules"
        "/etc/fail2ban/jail.d/hardn-jail.conf"
        "/etc/rsyslog.d/50-hardn.conf"
        "/etc/aide/aide.conf.d/hardn-aide.conf"
        "/etc/systemd/resolved.conf.d/hardn-dns.conf"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "${config_file}" ]]; then
            if is_dry_run; then
                log_info "[DRY-RUN] Would remove ${config_file}"
            else
                backup_file "${config_file}"
                rm -f "${config_file}"
                log_debug "Removed ${config_file}"
            fi
        fi
    done
    
    hardn_status "pass" "HARDN configuration files removed"
}

# Restore original configurations
restore_original_configs() {
    log_info "Restoring original configurations..."
    
    # Restore original sysctl settings
    if ! is_dry_run; then
        # Reset problematic sysctl settings to defaults
        local sysctl_resets=(
            "net.ipv4.ip_forward=0"
            "kernel.dmesg_restrict=0"
            "kernel.kptr_restrict=1"
            "fs.suid_dumpable=2"
        )
        
        for setting in "${sysctl_resets[@]}"; do
            sysctl -w "${setting}" >/dev/null 2>&1 || true
        done
    fi
    
    # Restore DNS settings
    if [[ -f /etc/systemd/resolved.conf.d/hardn-dns.conf ]]; then
        if is_dry_run; then
            log_info "[DRY-RUN] Would restore DNS settings"
        else
            rm -f /etc/systemd/resolved.conf.d/hardn-dns.conf
            systemctl restart systemd-resolved 2>/dev/null || true
            log_debug "DNS settings restored"
        fi
    fi
    
    hardn_status "pass" "Original configurations restored"
}

# Remove HARDN services
remove_hardn_services() {
    log_info "Removing HARDN services..."
    
    # Stop and disable HARDN monitor service
    if service_exists "hardn-monitor"; then
        disable_service "hardn-monitor" "HARDN Monitor"
    fi
    
    # Reset security services to default state
    local services_to_reset=(
        "fail2ban"
        "ufw"
    )
    
    for service in "${services_to_reset[@]}"; do
        if service_exists "${service}"; then
            if confirm_action "Disable ${service}?" "n"; then
                disable_service "${service}"
            fi
        fi
    done
    
    # Reset UFW to defaults if requested
    if is_service_active "ufw" && confirm_action "Reset UFW firewall to defaults?" "n"; then
        if ! is_dry_run; then
            echo "y" | ufw --force reset >/dev/null 2>&1
            ufw --force disable >/dev/null 2>&1
            log_debug "UFW reset to defaults"
        fi
    fi
    
    hardn_status "pass" "HARDN services removed"
}

# Remove security packages (optional)
remove_security_packages() {
    log_info "Removing security packages..."
    
    local security_packages=(
        "rkhunter"
        "chkrootkit"
        "unhide"
        "aide"
        "aide-common"
        "fail2ban"
        "lynis"
        "yara"
    )
    
    log_warn "The following packages will be removed:"
    for package in "${security_packages[@]}"; do
        if is_package_installed "${package}"; then
            echo "  - ${package}"
        fi
    done
    
    if ! confirm_action "Proceed with package removal?" "n"; then
        log_info "Package removal cancelled"
        return 0
    fi
    
    for package in "${security_packages[@]}"; do
        if is_package_installed "${package}"; then
            if is_dry_run; then
                log_info "[DRY-RUN] Would remove package: ${package}"
            else
                log_debug "Removing ${package}..."
                if DEBIAN_FRONTEND=noninteractive apt-get remove -y "${package}" >/dev/null 2>&1; then
                    log_debug "Removed ${package}"
                else
                    log_warn "Failed to remove ${package}"
                fi
            fi
        fi
    done
    
    # Clean up orphaned packages
    if ! is_dry_run; then
        DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >/dev/null 2>&1
    fi
    
    hardn_status "pass" "Security packages removed"
}

# Show what would be removed (dry run)
show_removal_plan() {
    log_info "HARDN Removal Plan"
    log_separator "=" 40
    
    echo "Configuration files to be removed:"
    local config_files=(
        "/etc/sysctl.d/99-hardn-security.conf"
        "/etc/audit/rules.d/hardn-audit.rules"
        "/etc/fail2ban/jail.d/hardn-jail.conf"
        "/etc/rsyslog.d/50-hardn.conf"
        "/etc/aide/aide.conf.d/hardn-aide.conf"
        "/etc/systemd/resolved.conf.d/hardn-dns.conf"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "${config_file}" ]]; then
            echo "  ✓ ${config_file}"
        else
            echo "  - ${config_file} (not found)"
        fi
    done
    
    echo
    echo "Services to be modified:"
    local services=("hardn-monitor" "fail2ban" "ufw" "auditd")
    for service in "${services[@]}"; do
        if service_exists "${service}"; then
            local status
            if is_service_active "${service}"; then
                status="running → stopped"
            else
                status="stopped"
            fi
            echo "  ✓ ${service} (${status})"
        else
            echo "  - ${service} (not installed)"
        fi
    done
    
    echo
    echo "System changes to be reverted:"
    echo "  ✓ Kernel security parameters"
    echo "  ✓ DNS configuration"
    echo "  ✓ Audit rules"
    echo "  ✓ Firewall rules"
    
    echo
    echo "Data preserved:"
    echo "  ✓ System backups in ${HARDN_LIB_DIR}/backups"
    echo "  ✓ Log files in ${HARDN_LOG_DIR}"
    
    echo
}

# Export functions
export -f remove_hardening remove_hardn_configs restore_original_configs
export -f remove_hardn_services remove_security_packages show_removal_plan
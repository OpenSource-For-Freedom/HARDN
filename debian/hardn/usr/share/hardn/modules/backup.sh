#!/bin/bash

# HARDN Backup Module
# System backup and restore functionality

# Source required modules
# shellcheck source=/usr/share/hardn/modules/logging.sh
source "${HARDN_MODULES_DIR}/logging.sh"
# shellcheck source=/usr/share/hardn/modules/utils.sh
source "${HARDN_MODULES_DIR}/utils.sh"

# Create system backup
create_system_backup() {
    local backup_name="${1:-$(date +%Y%m%d_%H%M%S)}"
    local backup_dir="${HARDN_LIB_DIR}/backups/${backup_name}"
    
    log_info "Creating system backup: ${backup_name}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would create backup in ${backup_dir}"
        return 0
    fi
    
    # Create backup directory
    mkdir -p "${backup_dir}"
    
    # Backup critical configuration files
    local config_files=(
        "/etc/sysctl.d/99-hardn-security.conf"
        "/etc/audit/rules.d/hardn-audit.rules"
        "/etc/fail2ban/jail.d/hardn-jail.conf"
        "/etc/ufw/ufw.conf"
        "/etc/rsyslog.d/50-hardn.conf"
        "/etc/hardn/hardn.conf"
    )
    
    for config_file in "${config_files[@]}"; do
        if [[ -f "${config_file}" ]]; then
            local backup_path
            backup_path="${backup_dir}$(dirname "${config_file}")"
            mkdir -p "${backup_path}"
            cp "${config_file}" "${backup_path}/"
            log_debug "Backed up ${config_file}"
        fi
    done
    
    # Create backup manifest
    cat > "${backup_dir}/manifest.txt" << EOF
HARDN System Backup
Created: $(date)
System: $(hostname)
HARDN Version: ${HARDN_VERSION}

Configuration files backed up:
$(find "${backup_dir}" -type f -name "*.conf" -o -name "*.rules")

Services status at backup time:
$(systemctl list-units --state=active --type=service | grep -E "(ufw|fail2ban|auditd|apparmor)")
EOF
    
    hardn_status "pass" "System backup created: ${backup_dir}"
    log_info "Backup manifest: ${backup_dir}/manifest.txt"
}

# Restore system backup
restore_system_backup() {
    local backup_name="${1}"
    
    if [[ -z "${backup_name}" ]]; then
        log_error "Backup name required"
        log_info "Available backups:"
        list_backups
        return 1
    fi
    
    local backup_dir="${HARDN_LIB_DIR}/backups/${backup_name}"
    
    if [[ ! -d "${backup_dir}" ]]; then
        log_error "Backup not found: ${backup_dir}"
        return 1
    fi
    
    log_info "Restoring system backup: ${backup_name}"
    
    if ! confirm_action "This will restore system configuration from backup. Continue?"; then
        log_info "Restore cancelled"
        return 0
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would restore from ${backup_dir}"
        return 0
    fi
    
    # Restore configuration files
    find "${backup_dir}" -type f \( -name "*.conf" -o -name "*.rules" \) | while read -r backup_file; do
        local relative_path="${backup_file#"${backup_dir}"}"
        local target_file="${relative_path}"
        
        if [[ -f "${target_file}" ]]; then
            # Create backup of current file before restoring
            backup_file "${target_file}"
        fi
        
        # Restore file
        cp "${backup_file}" "${target_file}"
        log_debug "Restored ${target_file}"
    done
    
    hardn_status "pass" "System backup restored from: ${backup_dir}"
    log_info "Please restart services or reboot to apply restored configuration"
}

# List available backups
list_backups() {
    local backup_base_dir="${HARDN_LIB_DIR}/backups"
    
    if [[ ! -d "${backup_base_dir}" ]]; then
        log_info "No backups found (backup directory doesn't exist)"
        return 0
    fi
    
    log_info "Available backups:"
    log_separator "-" 40
    
    local backup_found=false
    
    for backup_dir in "${backup_base_dir}"/*; do
        if [[ -d "${backup_dir}" ]]; then
            local backup_name
            backup_name=$(basename "${backup_dir}")
            local backup_date="Unknown"
            local file_count=0
            
            # Get backup information
            if [[ -f "${backup_dir}/manifest.txt" ]]; then
                backup_date=$(grep "Created:" "${backup_dir}/manifest.txt" | cut -d: -f2- | xargs)
            fi
            
            file_count=$(find "${backup_dir}" -type f | wc -l)
            
            printf "%-20s %-25s %d files\n" "${backup_name}" "${backup_date}" "${file_count}"
            backup_found=true
        fi
    done
    
    if [[ "${backup_found}" == "false" ]]; then
        log_info "No backups found"
    fi
}

# Clean old backups
clean_old_backups() {
    local days="${1:-30}"
    local backup_base_dir="${HARDN_LIB_DIR}/backups"
    
    log_info "Cleaning backups older than ${days} days..."
    
    if [[ ! -d "${backup_base_dir}" ]]; then
        log_info "No backup directory found"
        return 0
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would clean backups older than ${days} days"
        find "${backup_base_dir}" -type d -name "*" -mtime "+${days}" 2>/dev/null | while read -r old_backup; do
            log_info "[DRY-RUN] Would remove: $(basename "${old_backup}")"
        done
        return 0
    fi
    
    local removed_count=0
    local temp_count_file="/tmp/backup_count_$$"
    echo "0" > "${temp_count_file}"
    
    find "${backup_base_dir}" -type d -name "*" -mtime "+${days}" 2>/dev/null | while read -r old_backup; do
        if [[ "${old_backup}" != "${backup_base_dir}" ]]; then
            local backup_name
            backup_name=$(basename "${old_backup}")
            log_info "Removing old backup: ${backup_name}"
            rm -rf "${old_backup}"
            local count
            count=$(cat "${temp_count_file}")
            echo $((count + 1)) > "${temp_count_file}"
        fi
    done
    
    removed_count=$(cat "${temp_count_file}")
    rm -f "${temp_count_file}"
    
    hardn_status "pass" "Cleaned ${removed_count} old backups"
}

# Export functions
export -f create_system_backup restore_system_backup list_backups clean_old_backups
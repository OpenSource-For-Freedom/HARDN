#!/bin/bash

# HARDN Utilities Module
# Common utility functions used across modules

# Check if running in non-interactive mode
is_non_interactive() {
    [[ "${NON_INTERACTIVE:-false}" == "true" ]]
}

# Check if running in dry-run mode
is_dry_run() {
    [[ "${DRY_RUN:-false}" == "true" ]]
}

# Check if force mode is enabled
is_force_mode() {
    [[ "${FORCE:-false}" == "true" ]]
}

# Simple messaging for non-interactive mode
simple_message() {
    local type="$1"
    shift
    
    case "${type}" in
        infobox|msgbox)
            log_info "$1"
            ;;
        yesno)
            # In non-interactive mode, assume "yes" unless force mode says otherwise
            return 0
            ;;
        inputbox)
            # Return default value if provided
            echo "${3:-}"
            ;;
    esac
}

# Safe command execution with dry-run support
safe_execute() {
    local command="$1"
    local description="${2:-Executing command}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would execute: ${command}"
        return 0
    else
        log_debug "${description}: ${command}"
        eval "${command}"
    fi
}

# Check if a package is installed
is_package_installed() {
    local package="$1"
    dpkg -s "${package}" >/dev/null 2>&1
}

# Install package with error handling
install_package() {
    local package="$1"
    local description="${2:-${package}}"
    
    if is_package_installed "${package}"; then
        log_debug "Package ${package} is already installed"
        return 0
    fi
    
    log_info "Installing ${description}..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would install package: ${package}"
        return 0
    fi
    
    if DEBIAN_FRONTEND=noninteractive apt-get install -y "${package}" >/dev/null 2>&1; then
        hardn_status "pass" "${description} installed successfully"
        return 0
    else
        hardn_status "error" "Failed to install ${description}"
        return 1
    fi
}

# Update package lists
update_package_lists() {
    log_info "Updating package lists..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would update package lists"
        return 0
    fi
    
    if DEBIAN_FRONTEND=noninteractive timeout 60s apt-get update -y >/dev/null 2>&1; then
        hardn_status "pass" "Package lists updated successfully"
        return 0
    else
        hardn_status "warning" "Package list update failed or timed out"
        return 1
    fi
}

# Check if a service exists
service_exists() {
    local service="$1"
    systemctl list-unit-files "${service}.service" >/dev/null 2>&1
}

# Check if a service is enabled
is_service_enabled() {
    local service="$1"
    systemctl is-enabled "${service}" >/dev/null 2>&1
}

# Check if a service is active/running
is_service_active() {
    local service="$1"
    systemctl is-active "${service}" >/dev/null 2>&1
}

# Enable and start a service
enable_service() {
    local service="$1"
    local description="${2:-${service}}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would enable and start service: ${service}"
        return 0
    fi
    
    if service_exists "${service}"; then
        if ! is_service_enabled "${service}"; then
            log_info "Enabling ${description} service..."
            systemctl enable "${service}" >/dev/null 2>&1
        fi
        
        if ! is_service_active "${service}"; then
            log_info "Starting ${description} service..."
            systemctl start "${service}" >/dev/null 2>&1
        fi
        
        if is_service_active "${service}"; then
            hardn_status "pass" "${description} service is running"
            return 0
        else
            hardn_status "error" "Failed to start ${description} service"
            return 1
        fi
    else
        hardn_status "warning" "${description} service not found"
        return 1
    fi
}

# Disable and stop a service
disable_service() {
    local service="$1"
    local description="${2:-${service}}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would disable and stop service: ${service}"
        return 0
    fi
    
    if service_exists "${service}"; then
        if is_service_active "${service}"; then
            log_info "Stopping ${description} service..."
            systemctl stop "${service}" >/dev/null 2>&1
        fi
        
        if is_service_enabled "${service}"; then
            log_info "Disabling ${description} service..."
            systemctl disable "${service}" >/dev/null 2>&1
        fi
        
        hardn_status "pass" "${description} service disabled"
        return 0
    else
        log_debug "${description} service not found"
        return 1
    fi
}

# Backup a file with timestamp
backup_file() {
    local file="$1"
    local backup_dir="${2:-${HARDN_LIB_DIR}/backups}"
    local timestamp
    local backup_file
    
    if [[ ! -f "${file}" ]]; then
        log_debug "File ${file} does not exist, skipping backup"
        return 1
    fi
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="${backup_dir}/$(basename "${file}").${timestamp}.bak"
    
    # Create backup directory if it doesn't exist
    mkdir -p "${backup_dir}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would backup ${file} to ${backup_file}"
        return 0
    fi
    
    if cp "${file}" "${backup_file}"; then
        log_debug "Backed up ${file} to ${backup_file}"
        return 0
    else
        log_error "Failed to backup ${file}"
        return 1
    fi
}

# Restore a file from backup
restore_file() {
    local file="$1"
    local backup_file="$2"
    
    if [[ ! -f "${backup_file}" ]]; then
        log_error "Backup file ${backup_file} does not exist"
        return 1
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would restore ${backup_file} to ${file}"
        return 0
    fi
    
    if cp "${backup_file}" "${file}"; then
        log_info "Restored ${file} from ${backup_file}"
        return 0
    else
        log_error "Failed to restore ${file} from ${backup_file}"
        return 1
    fi
}

# Create a file with content and proper permissions
create_config_file() {
    local file="$1"
    local content="$2"
    local permissions="${3:-644}"
    local owner="${4:-root:root}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would create config file: ${file}"
        return 0
    fi
    
    # Backup existing file if it exists
    if [[ -f "${file}" ]]; then
        backup_file "${file}"
    fi
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "${file}")"
    
    # Write content to file
    echo "${content}" > "${file}"
    
    # Set permissions and ownership
    chmod "${permissions}" "${file}"
    chown "${owner}" "${file}"
    
    log_debug "Created config file: ${file}"
}

# Add line to file if it doesn't exist
add_line_to_file() {
    local line="$1"
    local file="$2"
    local description="${3:-line}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would add ${description} to ${file}"
        return 0
    fi
    
    if [[ ! -f "${file}" ]]; then
        log_debug "File ${file} does not exist, creating it"
        touch "${file}"
    fi
    
    if ! grep -Fxq "${line}" "${file}"; then
        backup_file "${file}"
        echo "${line}" >> "${file}"
        log_debug "Added ${description} to ${file}"
    else
        log_debug "${description} already exists in ${file}"
    fi
}

# Remove line from file
remove_line_from_file() {
    local line="$1"
    local file="$2"
    local description="${3:-line}"
    
    if [[ ! -f "${file}" ]]; then
        log_debug "File ${file} does not exist"
        return 1
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would remove ${description} from ${file}"
        return 0
    fi
    
    if grep -Fxq "${line}" "${file}"; then
        backup_file "${file}"
        grep -Fxv "${line}" "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
        log_debug "Removed ${description} from ${file}"
    else
        log_debug "${description} not found in ${file}"
    fi
}

# Check if user exists
user_exists() {
    local username="$1"
    getent passwd "${username}" >/dev/null 2>&1
}

# Check if group exists
group_exists() {
    local groupname="$1"
    getent group "${groupname}" >/dev/null 2>&1
}

# Get system memory in MB
get_system_memory() {
    local memory_kb
    memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    echo $((memory_kb / 1024))
}

# Get system CPU count
get_cpu_count() {
    nproc
}

# Check if running in a container
is_container() {
    [[ -f /.dockerenv ]] || [[ -n "${container:-}" ]]
}

# Check if running in a virtual machine
is_virtual_machine() {
    local virt_type
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt_type=$(systemd-detect-virt)
        [[ "${virt_type}" != "none" ]]
    else
        # Fallback detection
        dmesg | grep -qi hypervisor || lscpu | grep -qi hypervisor
    fi
}

# Generate random password
generate_password() {
    local length="${1:-16}"
    local chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    
    < /dev/urandom tr -dc "${chars}" | head -c"${length}"
}

# Validate IP address
is_valid_ip() {
    local ip="$1"
    local IFS='.'
    local -a octets
    
    read -ra octets <<< "${ip}"
    
    [[ ${#octets[@]} -eq 4 ]] || return 1
    
    for octet in "${octets[@]}"; do
        [[ "${octet}" =~ ^[0-9]+$ ]] || return 1
        [[ ${octet} -ge 0 && ${octet} -le 255 ]] || return 1
    done
    
    return 0
}

# Wait for user confirmation (respects non-interactive mode)
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if is_non_interactive; then
        if is_force_mode; then
            log_info "Force mode: ${message} - Proceeding automatically"
            return 0
        else
            log_info "Non-interactive mode: ${message} - Skipping"
            return 1
        fi
    fi
    
    local prompt="[y/N]"
    [[ "${default}" == "y" ]] && prompt="[Y/n]"
    
    while true; do
        read -p "${message} ${prompt}: " -n 1 -r
        echo
        
        case "${REPLY}" in
            [Yy]*)
                return 0
                ;;
            [Nn]*|"")
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Export all functions
export -f is_non_interactive is_dry_run is_force_mode simple_message safe_execute
export -f is_package_installed install_package update_package_lists
export -f service_exists is_service_enabled is_service_active enable_service disable_service
export -f backup_file restore_file create_config_file add_line_to_file remove_line_from_file
export -f user_exists group_exists get_system_memory get_cpu_count
export -f is_container is_virtual_machine generate_password is_valid_ip confirm_action
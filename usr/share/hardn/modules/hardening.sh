#!/bin/bash

# HARDN-XDR Hardening Module
# Core system hardening functionality

# Source required modules
# shellcheck source=/usr/share/hardn/modules/logging.sh
source "${HARDN_MODULES_DIR}/logging.sh"
# shellcheck source=/usr/share/hardn/modules/utils.sh
source "${HARDN_MODULES_DIR}/utils.sh"

# Print welcome banner
show_welcome_banner() {
    cat << 'EOF'

   ▄█    █▄            ▄████████         ▄████████      ████████▄       ███▄▄▄▄   
  ███    ███          ███    ███        ███    ███      ███   ▀███      ███▀▀▀██▄ 
  ███    ███          ███    ███        ███    ███      ███    ███      ███   ███ 
 ▄███▄▄▄▄███▄▄        ███    ███       ▄███▄▄▄▄██▀      ███    ███      ███   ███ 
▀▀███▀▀▀▀███▀       ▀███████████      ▀▀███▀▀▀▀▀        ███    ███      ███   ███ 
  ███    ███          ███    ███      ▀███████████      ███    ███      ███   ███ 
  ███    ███          ███    ███        ███    ███      ███   ▄███      ███   ███ 
  ███    █▀           ███    █▀         ███    ███      ████████▀        ▀█   █▀  
                                        ███    ███ 
                           
                            Extended Detection and Response
                                   Version 2.0.0
                            by Security International Group

EOF

    log_separator "="
    log_info "HARDN-XDR v${HARDN_VERSION} - Linux Security Hardening Sentinel"
    log_separator "="
    log_system_info
}

# Show welcome message and get user confirmation
show_welcome_message() {
    if is_non_interactive; then
        log_info "Running in non-interactive mode - proceeding with automatic hardening"
        return 0
    fi
    
    whiptail_wrapper msgbox \
        "Welcome to HARDN-XDR v${HARDN_VERSION}\n\nThis will apply STIG compliance, security tools, and comprehensive system hardening to your system.\n\nIMPORTANT: This process will make significant changes to your system configuration. Please ensure you have backups and understand the implications.\n\nPress OK to continue or Cancel to exit." \
        15 70
}

# Install packages from the progs.csv file
install_security_packages() {
    log_info "Installing security packages..."
    
    local progs_csv="${HARDN_DATA_DIR}/../../../progs.csv"
    
    # Use the original progs.csv if new one doesn't exist yet
    if [[ ! -f "${progs_csv}" ]]; then
        progs_csv="/home/runner/work/HARDN/HARDN/progs.csv"
    fi
    
    if [[ ! -f "${progs_csv}" ]]; then
        log_error "Package list file not found: ${progs_csv}"
        return 1
    fi
    
    # Update package lists first
    update_package_lists
    
    local total_packages
    local current_package=0
    
    # Count total packages (excluding header and comments)
    total_packages=$(grep -v '^#' "${progs_csv}" | grep -v '^[[:space:]]*$' | tail -n +2 | wc -l)
    
    log_info "Installing ${total_packages} security packages..."
    
    # Read and install packages
    while IFS=, read -r name _version _debian_min_version _debian_codenames_str rest || [[ -n "${name}" ]]; do
        # Skip comments and empty lines
        [[ -z "${name}" || "${name}" =~ ^[[:space:]]*# ]] && continue
        
        # Clean up the package name
        name=$(echo "${name}" | xargs)
        
        ((current_package++))
        
        if ! is_non_interactive; then
            show_progress ${current_package} ${total_packages} "Installing packages"
        fi
        
        log_debug "Processing package ${current_package}/${total_packages}: ${name}"
        
        # Install the package
        if install_package "${name}"; then
            log_debug "Successfully installed ${name}"
        else
            log_warn "Failed to install ${name}, continuing..."
        fi
        
    done < <(tail -n +2 "${progs_csv}")
    
    hardn_status "pass" "Security package installation completed"
}

# Apply kernel security hardening
apply_kernel_hardening() {
    log_info "Applying kernel security hardening..."
    
    local sysctl_conf="/etc/sysctl.d/99-hardn-security.conf"
    
    # Create kernel security configuration
    local kernel_config='# HARDN-XDR Kernel Security Configuration
# Applied by HARDN-XDR v2.0.0

# Memory Protection
fs.protected_fifos = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.suid_dumpable = 0

# Information Leak Prevention
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
net.core.bpf_jit_harden = 2

# Network Security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1

# IPv6 Security (if enabled)
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Process restrictions
kernel.yama.ptrace_scope = 1
kernel.unprivileged_bpf_disabled = 1
kernel.kexec_load_disabled = 1

# Additional hardening
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16
kernel.randomize_va_space = 2'

    create_config_file "${sysctl_conf}" "${kernel_config}" "644" "root:root"
    
    # Apply the settings immediately
    if ! is_dry_run; then
        sysctl -p "${sysctl_conf}" >/dev/null 2>&1
    fi
    
    hardn_status "pass" "Kernel security hardening applied"
}

# Configure secure DNS servers
configure_secure_dns() {
    log_info "Configuring secure DNS servers..."
    
    local resolv_conf="/etc/resolv.conf"
    local systemd_resolved_conf="/etc/systemd/resolved.conf.d/hardn-dns.conf"
    
    # Check if systemd-resolved is active
    if is_service_active "systemd-resolved"; then
        log_info "Configuring systemd-resolved for secure DNS..."
        
        # Create systemd-resolved configuration directory
        mkdir -p "$(dirname "${systemd_resolved_conf}")"
        
        local resolved_config='# HARDN-XDR DNS Configuration
[Resolve]
DNS=9.9.9.9 149.112.112.112 1.1.1.1 1.0.0.1
Domains=~.
DNSSEC=yes
DNSOverTLS=yes
Cache=yes'

        create_config_file "${systemd_resolved_conf}" "${resolved_config}" "644" "root:root"
        
        # Restart systemd-resolved to apply changes
        if ! is_dry_run; then
            systemctl restart systemd-resolved
        fi
        
    else
        log_info "Configuring direct DNS resolution..."
        
        local dns_config='# HARDN-XDR DNS Configuration
# Quad9 (primary)
nameserver 9.9.9.9
nameserver 149.112.112.112
# Cloudflare (backup)
nameserver 1.1.1.1
nameserver 1.0.0.1

options timeout:2
options attempts:3
options rotate
options single-request-reopen'

        backup_file "${resolv_conf}"
        create_config_file "${resolv_conf}" "${dns_config}" "644" "root:root"
    fi
    
    hardn_status "pass" "Secure DNS servers configured"
}

# Configure audit system
configure_audit_system() {
    log_info "Configuring audit system..."
    
    if ! is_package_installed "auditd"; then
        log_warn "auditd not installed, skipping audit configuration"
        return 1
    fi
    
    local audit_rules="/etc/audit/rules.d/hardn-audit.rules"
    
    local audit_config='# HARDN-XDR Audit Rules
# Delete all previous rules
-D

# Buffer size (increase if losing events)
-b 8192

# Failure mode (0=silent, 1=printk, 2=panic)
-f 1

# Monitor authentication and authorization
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Monitor system configuration
-w /etc/sysctl.conf -p wa -k sysctl
-w /etc/sysctl.d/ -p wa -k sysctl

# Monitor privileged commands
-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged
-a always,exit -F arch=b32 -S execve -F euid=0 -k privileged

# Monitor network configuration
-w /etc/hosts -p wa -k network
-w /etc/hostname -p wa -k network
-w /etc/resolv.conf -p wa -k network

# Monitor time changes
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change

# Monitor module loading
-a always,exit -F arch=b64 -S init_module,delete_module -k modules
-a always,exit -F arch=b32 -S init_module,delete_module -k modules

# Make rules immutable
-e 2'

    create_config_file "${audit_rules}" "${audit_config}" "644" "root:root"
    
    # Enable and start auditd
    enable_service "auditd" "audit system"
    
    hardn_status "pass" "Audit system configured"
}

# Configure system integrity monitoring with AIDE
configure_aide() {
    log_info "Configuring AIDE system integrity monitoring..."
    
    if ! is_package_installed "aide"; then
        log_warn "AIDE not installed, skipping configuration"
        return 1
    fi
    
    local aide_conf="/etc/aide/aide.conf.d/hardn-aide.conf"
    
    local aide_config='# HARDN-XDR AIDE Configuration
# Monitor critical system files

# System binaries
/bin f+p+u+g+s+b+m+c+md5+sha256
/sbin f+p+u+g+s+b+m+c+md5+sha256
/usr/bin f+p+u+g+s+b+m+c+md5+sha256
/usr/sbin f+p+u+g+s+b+m+c+md5+sha256

# System libraries
/lib f+p+u+g+s+b+m+c+md5+sha256
/usr/lib f+p+u+g+s+b+m+c+md5+sha256

# Configuration files
/etc f+p+u+g+s+b+m+c+md5+sha256

# Boot files
/boot f+p+u+g+s+b+m+c+md5+sha256

# Exclude volatile directories
!/var/log
!/var/tmp
!/tmp
!/proc
!/sys
!/dev'

    create_config_file "${aide_conf}" "${aide_config}" "644" "root:root"
    
    # Initialize AIDE database
    if ! is_dry_run; then
        log_info "Initializing AIDE database (this may take a while)..."
        aideinit >/dev/null 2>&1 &
        local aide_pid=$!
        log_info "AIDE initialization running in background (PID: ${aide_pid})"
    fi
    
    hardn_status "pass" "AIDE system integrity monitoring configured"
}

# Configure firewall (UFW)
configure_firewall() {
    log_info "Configuring UFW firewall..."
    
    if ! is_package_installed "ufw"; then
        log_warn "UFW not installed, skipping firewall configuration"
        return 1
    fi
    
    if ! is_dry_run; then
        # Reset to defaults
        echo "y" | ufw --force reset >/dev/null 2>&1
        
        # Set default policies
        ufw default deny incoming >/dev/null 2>&1
        ufw default allow outgoing >/dev/null 2>&1
        
        # Allow SSH (be careful not to lock ourselves out)
        ufw allow ssh >/dev/null 2>&1
        
        # Enable firewall
        echo "y" | ufw --force enable >/dev/null 2>&1
    fi
    
    hardn_status "pass" "UFW firewall configured and enabled"
}

# Configure Fail2Ban
configure_fail2ban() {
    log_info "Configuring Fail2Ban intrusion prevention..."
    
    if ! is_package_installed "fail2ban"; then
        log_warn "Fail2Ban not installed, skipping configuration"
        return 1
    fi
    
    local fail2ban_conf="/etc/fail2ban/jail.d/hardn-jail.conf"
    
    local fail2ban_config='# HARDN-XDR Fail2Ban Configuration
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3

[apache-auth]
enabled = true
maxretry = 3

[apache-noscript]
enabled = true
maxretry = 3

[apache-overflows]
enabled = true
maxretry = 2'

    create_config_file "${fail2ban_conf}" "${fail2ban_config}" "644" "root:root"
    
    # Enable and start Fail2Ban
    enable_service "fail2ban" "Fail2Ban intrusion prevention"
    
    hardn_status "pass" "Fail2Ban intrusion prevention configured"
}

# Disable unnecessary services
disable_unnecessary_services() {
    log_info "Disabling unnecessary services..."
    
    local services_to_disable=(
        "bluetooth"
        "cups"
        "avahi-daemon"
        "telnet"
        "rsh-server"
        "rlogin"
        "vsftpd"
        "wu-ftpd"
        "postfix"
        "sendmail"
        "xinetd"
    )
    
    for service in "${services_to_disable[@]}"; do
        if service_exists "${service}"; then
            disable_service "${service}"
        fi
    done
    
    hardn_status "pass" "Unnecessary services disabled"
}

# Configure AppArmor
configure_apparmor() {
    log_info "Configuring AppArmor..."
    
    if ! is_package_installed "apparmor"; then
        log_warn "AppArmor not installed, skipping configuration"
        return 1
    fi
    
    # Enable AppArmor service
    enable_service "apparmor" "AppArmor mandatory access control"
    
    # Load additional profiles if available
    if ! is_dry_run && command -v aa-enforce >/dev/null 2>&1; then
        log_info "Enabling AppArmor profiles..."
        find /etc/apparmor.d/ -type f -name "*" -exec aa-enforce {} \; 2>/dev/null || true
    fi
    
    hardn_status "pass" "AppArmor configured"
}

# Configure system logging
configure_logging() {
    log_info "Configuring system logging..."
    
    if ! is_package_installed "rsyslog"; then
        log_warn "rsyslog not installed, skipping logging configuration"
        return 1
    fi
    
    local rsyslog_conf="/etc/rsyslog.d/50-hardn.conf"
    
    local logging_config='# HARDN-XDR Logging Configuration
# Log all authentication attempts
auth,authpriv.*                 /var/log/auth.log

# Log security events
*.info;mail.none;authpriv.none;cron.none    /var/log/messages

# Log cron events
cron.*                          /var/log/cron.log

# Emergency messages to all logged-in users
*.emerg                         :omusrmsg:*

# Log to HARDN log file
local0.*                        /var/log/hardn/security.log'

    create_config_file "${rsyslog_conf}" "${logging_config}" "644" "root:root"
    
    # Restart rsyslog to apply changes
    if ! is_dry_run; then
        systemctl restart rsyslog
    fi
    
    hardn_status "pass" "System logging configured"
}

# Main hardening function for interactive mode
run_hardening_interactive() {
    show_welcome_banner
    
    if ! show_welcome_message; then
        log_info "Installation cancelled by user"
        exit 0
    fi
    
    log_info "Starting interactive system hardening..."
    
    # Run hardening steps
    install_security_packages
    apply_kernel_hardening
    configure_secure_dns
    configure_audit_system
    configure_aide
    configure_firewall
    configure_fail2ban
    configure_apparmor
    configure_logging
    disable_unnecessary_services
    
    # Show completion message
    if ! is_dry_run; then
        whiptail_wrapper msgbox \
            "HARDN-XDR hardening completed successfully!\n\nYour system has been hardened with STIG compliance and security tools.\n\nPlease reboot your system to complete the configuration." \
            12 70
    fi
    
    hardn_status "pass" "Interactive hardening completed successfully"
}

# Main hardening function for non-interactive mode
run_hardening_non_interactive() {
    show_welcome_banner
    
    log_info "Starting non-interactive system hardening..."
    
    # Run hardening steps
    install_security_packages
    apply_kernel_hardening
    configure_secure_dns
    configure_audit_system
    configure_aide
    configure_firewall
    configure_fail2ban
    configure_apparmor
    configure_logging
    disable_unnecessary_services
    
    hardn_status "pass" "Non-interactive hardening completed successfully"
    log_info "Please reboot your system to complete the configuration"
}

# Export functions
export -f show_welcome_banner show_welcome_message install_security_packages
export -f apply_kernel_hardening configure_secure_dns configure_audit_system
export -f configure_aide configure_firewall configure_fail2ban configure_apparmor
export -f configure_logging disable_unnecessary_services
export -f run_hardening_interactive run_hardening_non_interactive
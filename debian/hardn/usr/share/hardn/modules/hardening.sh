#!/bin/bash

# HARDN Hardening Module
# Core system hardening functionality with comprehensive tool selection

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
                           
                        Linux Security Hardening Sentinel
                                   Version 2.0.0
                              by Christopher Bingham and Tim Burns

EOF

    log_separator "="
    log_info "HARDN v${HARDN_VERSION} - Linux Security Hardening Sentinel"
    log_separator "="
    log_system_info
}

# Show welcome message and get user confirmation
show_welcome_message() {
    if is_non_interactive; then
        log_info "Running in non-interactive mode - proceeding with automatic hardening"
        return 0
    fi
    
    log_info "Welcome to HARDN v${HARDN_VERSION}"
    log_info "This will apply STIG compliance, security tools, and comprehensive system hardening to your system."
    log_info "IMPORTANT: This process will make significant changes to your system configuration."
    log_info "Please ensure you have backups and understand the implications."
    log_info "Proceeding with hardening setup..."
    return 0
}

# Security tools menu
show_tools_menu() {
    if is_non_interactive; then
        log_info "Non-interactive mode: Installing all security tools"
        install_all_security_tools
        return
    fi

    log_info "Available Security Tools:"
    log_info "1) AppArmor - Mandatory Access Control"
    log_info "2) UFW - Uncomplicated Firewall"
    log_info "3) Fail2Ban - Intrusion Prevention"
    log_info "4) AIDE - Advanced Intrusion Detection"
    log_info "5) rkhunter - Rootkit Hunter"
    log_info "6) chkrootkit - Check for Rootkits"
    log_info "7) ClamAV - Antivirus Scanner"
    log_info "8) Lynis - Security Auditing Tool"
    log_info "9) Suricata - Network IDS/IPS"
    log_info "10) YARA - Malware Detection"
    log_info "11) OpenSSH - Secure Shell Hardening"
    log_info "12) Audit System - Security Logging"
    log_info "13) Firejail - Application Sandboxing"
    log_info "14) libpam-pwquality - Password Policy"
    log_info "15) Centralized Logging - rsyslog"
    log_info "16) NTP - Network Time Protocol"
    log_info "17) Debsums - Package Integrity"
    log_info "18) Auto Updates - Unattended Upgrades"
    log_info "19) Legion - Network Discovery"
    log_info "20) Firmware Security Updates"
    log_info "21) STIG Compliance - All STIG Rules"
    log_info "22) Kernel Hardening - Security Settings"
    log_info "23) System Cleanup - Remove Unused"
    log_info "24) Prometheus Monitoring"
    log_info "25) QEMU/KVM Security"
    log_info "26) Rust Security Tools"
    log_info "27) LibVirt Security"
    log_info "28) All Tools - Install all security tools"
    
    log_info "Installing all security tools in non-interactive mode..."
    install_all_security_tools
}

# Install selected tools based on menu selection
install_selected_tools() {
    local selected="$1"
    
    if [[ -z "$selected" ]]; then
        log_warn "No tools selected"
        return
    fi

    log_info "Installing selected security tools..."
    
    # Remove quotes and process each selection
    selected=$(echo "$selected" | tr -d '"')
    
    for tool_num in $selected; do
        case "$tool_num" in
            1) run_tool "apparmor" "AppArmor Mandatory Access Control" ;;
            2) run_tool "ufw" "UFW Firewall" ;;
            3) run_tool "fail2ban" "Fail2Ban Intrusion Prevention" ;;
            4) run_tool "aide" "AIDE Intrusion Detection" ;;
            5) run_tool "rkhunter" "rkhunter Rootkit Detection" ;;
            6) run_tool "chkrootkit" "chkrootkit Scanner" ;;  # Note: not in tools but can add
            7) run_tool "clamav" "ClamAV Antivirus" ;;  # Note: not in tools but can add
            8) run_tool "lynis" "Lynis Security Audit" ;;
            9) run_tool "suricata" "Suricata Network IDS" ;;
            10) run_tool "yara" "YARA Malware Detection" ;;
            11) run_tool "openssh" "OpenSSH Hardening" ;;
            12) run_tool "audit" "System Auditing" ;;
            13) run_tool "firejail" "Firejail Sandboxing" ;;
            14) run_tool "libpam-pwquality" "Password Quality" ;;
            15) run_tool "centralized_logging" "Centralized Logging" ;;
            16) run_tool "ntp" "Network Time Protocol" ;;
            17) run_tool "debsums" "Package Integrity Check" ;;
            18) run_tool "auto_update" "Automatic Updates" ;;
            19) run_tool "legion" "Legion Network Discovery" ;;
            20) run_tool "firmware" "Firmware Security" ;;
            21) install_stig_compliance ;;
            22) apply_kernel_hardening ;;
            23) run_tool "cleanup" "System Cleanup" ;;
            24) run_tool "prometheus_monitoring" "Prometheus Monitoring" ;;
            25) run_tool "qemu" "QEMU/KVM Security" ;;
            26) run_tool "rust" "Rust Security Tools" ;;
            27) run_tool "libvirt" "LibVirt Security" ;;
            28) install_all_security_tools ;;
            *) log_warn "Unknown tool selection: $tool_num" ;;
        esac
    done
}

# Run individual security tool
run_tool() {
    local tool_name="$1"
    local tool_description="$2"
    local tool_script="${HARDN_DATA_DIR}/tools/${tool_name}.sh"
    
    if [[ -f "$tool_script" ]]; then
        log_info "Installing $tool_description..."
        
        if is_dry_run; then
            log_info "[DRY RUN] Would execute: $tool_script"
        else
            # Make sure the script is executable
            chmod +x "$tool_script"
            
            # Execute the tool script
            if bash "$tool_script"; then
                hardn_status "pass" "$tool_description installed successfully"
            else
                hardn_status "fail" "$tool_description installation failed"
                log_error "Failed to install $tool_description"
            fi
        fi
    else
        log_warn "Tool script not found: $tool_script"
        hardn_status "skip" "$tool_description - script not found"
    fi
}

# Install all security tools automatically
install_all_security_tools() {
    log_info "Installing all available security tools..."
    
    local tools_dir="${HARDN_DATA_DIR}/tools"
    
    if [[ ! -d "$tools_dir" ]]; then
        log_error "Tools directory not found: $tools_dir"
        return 1
    fi
    
    # Get list of all tool scripts
    local tool_scripts
    tool_scripts=$(find "$tools_dir" -name "*.sh" -not -path "*/stig/*" | sort)
    
    for script in $tool_scripts; do
        local tool_name
        tool_name=$(basename "$script" .sh)
        
        # Skip certain tools that require special handling
        case "$tool_name" in
            "functions"|"test_output") 
                continue ;;
        esac
        
        local tool_description
        tool_description=$(get_tool_description "$tool_name")
        
        run_tool "$tool_name" "$tool_description"
    done
    
    # Also install STIG compliance
    install_stig_compliance
}

# Install STIG compliance rules
install_stig_compliance() {
    log_info "Installing STIG compliance rules..."
    
    local stig_dir="${HARDN_DATA_DIR}/tools/stig"
    
    if [[ ! -d "$stig_dir" ]]; then
        log_warn "STIG directory not found: $stig_dir"
        return 1
    fi
    
    # Get list of STIG scripts
    local stig_scripts
    stig_scripts=$(find "$stig_dir" -name "*.sh" | sort)
    
    for script in $stig_scripts; do
        local stig_name
        stig_name=$(basename "$script" .sh)
        
        log_info "Applying STIG rule: $stig_name"
        
        if is_dry_run; then
            log_info "[DRY RUN] Would execute STIG script: $script"
        else
            chmod +x "$script"
            if bash "$script"; then
                hardn_status "pass" "STIG $stig_name applied successfully"
            else
                hardn_status "fail" "STIG $stig_name failed"
                log_error "Failed to apply STIG rule: $stig_name"
            fi
        fi
    done
}

# Get tool description from script or provide default
get_tool_description() {
    local tool_name="$1"
    
    case "$tool_name" in
        "apparmor") echo "AppArmor Mandatory Access Control" ;;
        "ufw") echo "UFW Firewall Configuration" ;;
        "fail2ban") echo "Fail2Ban Intrusion Prevention" ;;
        "aide") echo "AIDE Intrusion Detection" ;;
        "rkhunter") echo "rkhunter Rootkit Detection" ;;
        "lynis") echo "Lynis Security Audit" ;;
        "suricata") echo "Suricata Network IDS" ;;
        "yara") echo "YARA Malware Detection" ;;
        "openssh") echo "OpenSSH Hardening" ;;
        "audit") echo "System Auditing" ;;
        "firejail") echo "Firejail Sandboxing" ;;
        "libpam-pwquality") echo "Password Quality Control" ;;
        "centralized_logging") echo "Centralized Logging" ;;
        "ntp") echo "Network Time Protocol" ;;
        "debsums") echo "Package Integrity Verification" ;;
        "auto_update") echo "Automatic System Updates" ;;
        "legion") echo "Legion Network Discovery" ;;
        "firmware") echo "Firmware Security Updates" ;;
        "cleanup") echo "System Cleanup" ;;
        "prometheus_monitoring") echo "Prometheus Monitoring" ;;
        "qemu") echo "QEMU/KVM Security" ;;
        "rust") echo "Rust Security Tools" ;;
        "libvirt") echo "LibVirt Security" ;;
        *) echo "Security Tool: $tool_name" ;;
    esac
}

# Install packages from the progs.csv file
install_security_packages() {
    log_info "Installing security packages..."
    
    local progs_csv="${HARDN_DATA_DIR}/../../../progs.csv"
    
    # Try multiple fallback locations for progs.csv
    if [[ ! -f "${progs_csv}" ]]; then
        progs_csv="/usr/share/hardn/progs.csv"
    fi
    if [[ ! -f "${progs_csv}" ]]; then
        progs_csv="/etc/hardn/progs.csv"
    fi
    if [[ ! -f "${progs_csv}" ]]; then
        progs_csv="./progs.csv"
    fi
    
    if [[ ! -f "${progs_csv}" ]]; then
        log_error "Package list file not found: ${progs_csv}"
        log_info "Searched locations: ${HARDN_DATA_DIR}/../../../progs.csv, /usr/share/hardn/progs.csv, /etc/hardn/progs.csv, ./progs.csv"
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
            show_progress "${current_package}" "${total_packages}" "Installing packages"
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
    
    # First, install essential packages and updates
    install_security_packages
    
    # Show tools selection menu
    if show_tools_menu; then
        log_info "Security tools installation completed"
    else
        log_warn "Tool selection was cancelled or failed"
    fi
    
    # Apply basic system hardening
    apply_kernel_hardening
    configure_secure_dns
    configure_logging
    disable_unnecessary_services
    
    # Show completion message
    if ! is_dry_run; then
        log_info "HARDN hardening completed successfully!"
        log_info "Your system has been hardened with STIG compliance and security tools."
        log_info "Please reboot your system to complete the configuration."
    fi
    
    hardn_status "pass" "Interactive hardening completed successfully"
}

# Main hardening function for non-interactive mode
run_hardening_non_interactive() {
    show_welcome_banner
    
    log_info "Starting non-interactive system hardening..."
    
    # Run complete hardening process
    install_security_packages
    install_all_security_tools
    apply_kernel_hardening
    configure_secure_dns
    configure_logging
    disable_unnecessary_services
    
    hardn_status "pass" "Non-interactive hardening completed successfully"
    log_info "Please reboot your system to complete the configuration"
}

# Export functions
export -f show_welcome_banner show_welcome_message show_tools_menu install_selected_tools
export -f run_tool install_all_security_tools install_stig_compliance get_tool_description
export -f install_security_packages apply_kernel_hardening configure_secure_dns
export -f configure_logging disable_unnecessary_services
export -f run_hardening_interactive run_hardening_non_interactive
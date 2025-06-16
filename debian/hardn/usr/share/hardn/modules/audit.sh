#!/bin/bash

# HARDN Audit Module
# Security audit and compliance checking

# Source required modules
# shellcheck source=/usr/share/hardn/modules/logging.sh
source "${HARDN_MODULES_DIR}/logging.sh"
# shellcheck source=/usr/share/hardn/modules/utils.sh
source "${HARDN_MODULES_DIR}/utils.sh"

# Run Lynis security audit
run_lynis_audit() {
    log_info "Running Lynis security audit..."
    
    if ! command -v lynis >/dev/null 2>&1; then
        log_error "Lynis not installed. Please install lynis first."
        return 1
    fi
    
    local timestamp
    local audit_log
    local report_file
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    audit_log="${HARDN_LOG_DIR}/lynis-audit-${timestamp}.log"
    report_file="${HARDN_LOG_DIR}/lynis-report-${timestamp}.dat"
    
    # Create log directory
    mkdir -p "${HARDN_LOG_DIR}"
    
    log_info "Running comprehensive Lynis audit..."
    log_info "This may take several minutes depending on system size..."
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would run Lynis audit"
        return 0
    fi
    
    # Run Lynis audit
    if lynis audit system \
        --quiet \
        --no-colors \
        --log-file "${audit_log}" \
        --report-file "${report_file}" \
        --pentest; then
        
        log_info "Lynis audit completed successfully"
        
        # Extract and display key metrics
        if [[ -f "${report_file}" ]]; then
            local hardening_index
            hardening_index=$(grep "hardening_index=" "${report_file}" | cut -d= -f2)
            
            if [[ -n "${hardening_index}" ]]; then
                log_info "System Hardening Index: ${hardening_index}%"
                
                if [[ ${hardening_index} -ge 90 ]]; then
                    hardn_status "pass" "Excellent security posture (${hardening_index}%)"
                elif [[ ${hardening_index} -ge 70 ]]; then
                    hardn_status "warning" "Good security posture (${hardening_index}%)"
                else
                    hardn_status "warning" "Security improvements needed (${hardening_index}%)"
                fi
            fi
            
            # Show suggestions count
            local suggestions_count
            suggestions_count=$(grep -c "^suggestion\[" "${report_file}")
            log_info "Security suggestions: ${suggestions_count}"
            
            # Show warnings count
            local warnings_count
            warnings_count=$(grep -c "^warning\[" "${report_file}")
            log_info "Security warnings: ${warnings_count}"
        fi
        
        log_info "Audit log: ${audit_log}"
        log_info "Report file: ${report_file}"
        
        return 0
    else
        log_error "Lynis audit failed"
        return 1
    fi
}

# Run network security scan
run_network_scan() {
    log_info "Running network security scan..."
    
    if ! command -v nmap >/dev/null 2>&1; then
        if install_package "nmap" "Network mapper"; then
            log_info "nmap installed successfully"
        else
            log_error "Failed to install nmap"
            return 1
        fi
    fi
    
    local timestamp
    local scan_log
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    scan_log="${HARDN_LOG_DIR}/nmap-scan-${timestamp}.log"
    
    # Create log directory
    mkdir -p "${HARDN_LOG_DIR}"
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would run network scan"
        return 0
    fi
    
    log_info "Scanning localhost for open ports..."
    
    # Run localhost scan
    if nmap -sS -sV -O -p- localhost > "${scan_log}" 2>&1; then
        log_info "Network scan completed"
        
        # Extract open ports
        local open_ports
        open_ports=$(grep "^[0-9]" "${scan_log}" | grep -vc "closed")
        log_info "Open ports detected: ${open_ports}"
        
        # Show critical open ports
        if grep -q "21\|23\|135\|139\|445\|1433\|3389" "${scan_log}"; then
            hardn_status "warning" "Potentially insecure ports detected"
        fi
        
        log_info "Scan results: ${scan_log}"
        return 0
    else
        log_error "Network scan failed"
        return 1
    fi
}

# Check system integrity with AIDE
check_system_integrity() {
    log_info "Checking system integrity with AIDE..."
    
    if ! command -v aide >/dev/null 2>&1; then
        log_warn "AIDE not installed, skipping integrity check"
        return 1
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would check system integrity"
        return 0
    fi
    
    # Check if AIDE database exists
    if [[ ! -f /var/lib/aide/aide.db ]]; then
        log_warn "AIDE database not found. Run 'aide --init' first."
        return 1
    fi
    
    local timestamp
    local integrity_log
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    integrity_log="${HARDN_LOG_DIR}/aide-check-${timestamp}.log"
    
    log_info "Running AIDE integrity check..."
    
    # Run AIDE check
    if aide --check > "${integrity_log}" 2>&1; then
        log_info "System integrity check completed"
        
        # Check for changes
        if grep -q "found differences" "${integrity_log}"; then
            hardn_status "warning" "System file changes detected"
            log_warn "Review the integrity log: ${integrity_log}"
        else
            hardn_status "pass" "No unauthorized system changes detected"
        fi
        
        return 0
    else
        local exit_code=$?
        if [[ ${exit_code} -eq 1 ]]; then
            # Exit code 1 means differences found (not necessarily an error)
            hardn_status "warning" "System file changes detected"
            log_warn "Review the integrity log: ${integrity_log}"
            return 0
        else
            log_error "AIDE integrity check failed"
            return 1
        fi
    fi
}

# Check for rootkits
check_rootkits() {
    log_info "Checking for rootkits..."
    
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Run rkhunter if available
    if command -v rkhunter >/dev/null 2>&1; then
        local rkhunter_log="${HARDN_LOG_DIR}/rkhunter-${timestamp}.log"
        
        log_info "Running rkhunter scan..."
        
        if is_dry_run; then
            log_info "[DRY-RUN] Would run rkhunter scan"
        else
            if rkhunter --check --skip-keypress --report-warnings-only > "${rkhunter_log}" 2>&1; then
                if grep -q "Warning" "${rkhunter_log}"; then
                    hardn_status "warning" "Rootkit warnings detected by rkhunter"
                    log_warn "Review rkhunter log: ${rkhunter_log}"
                else
                    hardn_status "pass" "No rootkits detected by rkhunter"
                fi
            else
                log_error "rkhunter scan failed"
            fi
        fi
    fi
    
    # Run chkrootkit if available
    if command -v chkrootkit >/dev/null 2>&1; then
        local chkrootkit_log="${HARDN_LOG_DIR}/chkrootkit-${timestamp}.log"
        
        log_info "Running chkrootkit scan..."
        
        if is_dry_run; then
            log_info "[DRY-RUN] Would run chkrootkit scan"
        else
            if chkrootkit > "${chkrootkit_log}" 2>&1; then
                if grep -q "INFECTED" "${chkrootkit_log}"; then
                    hardn_status "warning" "Potential infections detected by chkrootkit"
                    log_warn "Review chkrootkit log: ${chkrootkit_log}"
                else
                    hardn_status "pass" "No rootkits detected by chkrootkit"
                fi
            else
                log_error "chkrootkit scan failed"
            fi
        fi
    fi
    
    if ! command -v rkhunter >/dev/null 2>&1 && ! command -v chkrootkit >/dev/null 2>&1; then
        log_warn "No rootkit detection tools installed"
        return 1
    fi
}

# Check malware with ClamAV
check_malware() {
    log_info "Checking for malware with ClamAV..."
    
    if ! command -v clamscan >/dev/null 2>&1; then
        log_warn "ClamAV not installed, skipping malware scan"
        return 1
    fi
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would run malware scan"
        return 0
    fi
    
    local timestamp
    local malware_log
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    malware_log="${HARDN_LOG_DIR}/clamav-scan-${timestamp}.log"
    
    log_info "Updating ClamAV database..."
    
    # Update virus definitions
    if ! freshclam --quiet; then
        log_warn "Failed to update ClamAV database, using existing definitions"
    fi
    
    log_info "Running ClamAV scan on critical directories..."
    log_info "This may take a while depending on system size..."
    
    # Scan critical directories
    local scan_dirs="/bin /sbin /usr/bin /usr/sbin /etc /home"
    
    if clamscan --recursive --infected --log="${malware_log}" "${scan_dirs}" >/dev/null 2>&1; then
        local infected_files
        infected_files=$(grep -c "FOUND" "${malware_log}")
        
        if [[ ${infected_files} -gt 0 ]]; then
            hardn_status "warning" "Malware detected: ${infected_files} infected files"
            log_warn "Review ClamAV log: ${malware_log}"
        else
            hardn_status "pass" "No malware detected by ClamAV"
        fi
        
        log_info "ClamAV scan log: ${malware_log}"
        return 0
    else
        log_error "ClamAV scan failed"
        return 1
    fi
}

# Generate security report
generate_security_report() {
    log_info "Generating comprehensive security audit report..."
    
    local timestamp
    local report_file
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    report_file="${HARDN_LOG_DIR}/security-report-${timestamp}.txt"
    
    # Create report header
    cat > "${report_file}" << EOF
HARDN Security Audit Report
===============================
Generated: $(date)
System: $(hostname)
OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
Kernel: $(uname -r)
HARDN Version: ${HARDN_VERSION}

EOF
    
    if is_dry_run; then
        log_info "[DRY-RUN] Would generate security report: ${report_file}"
        return 0
    fi
    
    # Add system information
    {
        echo "System Information:"
        echo "=================="
        echo "Hostname: $(hostname)"
        echo "Uptime: $(uptime)"
        echo "Memory: $(free -h | grep Mem)"
        echo "Disk: $(df -h / | tail -1)"
        echo ""
    } >> "${report_file}"
    
    # Add service status
    {
        echo "Security Services Status:"
        echo "========================"
    } >> "${report_file}"
    
    {
        local services=("ufw" "fail2ban" "auditd" "apparmor" "clamav-daemon" "rkhunter")
        for service in "${services[@]}"; do
            if service_exists "${service}"; then
                local status="stopped"
                if is_service_active "${service}"; then
                    status="running"
                fi
                echo "${service}: ${status}"
            else
                echo "${service}: not installed"
            fi
        done
        echo ""
    } >> "${report_file}"
    
    # Add recent log entries
    {
        echo "Recent Security Events:"
        echo "======================"
    } >> "${report_file}"
    if [[ -f /var/log/auth.log ]]; then
        {
            echo "Authentication attempts (last 10):"
            tail -10 /var/log/auth.log
            echo ""
        } >> "${report_file}"
    fi
    
    # Add recommendations
    {
        echo "Security Recommendations:"
        echo "========================="
        echo "1. Regularly update system packages"
        echo "2. Review security logs weekly"
        echo "3. Run security audits monthly"
        echo "4. Keep security tools updated"
        echo "5. Monitor system integrity changes"
        echo ""
    } >> "${report_file}"
    
    log_info "Security report generated: ${report_file}"
    hardn_status "pass" "Security audit report completed"
}

# Main audit function
run_security_audit() {
    local audit_type="${1:-full}"
    
    log_separator
    log_info "Starting HARDN security audit (${audit_type})..."
    log_separator
    
    case "${audit_type}" in
        "full"|"comprehensive")
            run_lynis_audit
            run_network_scan
            check_system_integrity
            check_rootkits
            check_malware
            generate_security_report
            ;;
        "quick")
            run_lynis_audit
            check_rootkits
            ;;
        "lynis")
            run_lynis_audit
            ;;
        "network")
            run_network_scan
            ;;
        "integrity")
            check_system_integrity
            ;;
        "malware")
            check_malware
            ;;
        *)
            log_error "Unknown audit type: ${audit_type}"
            log_info "Available types: full, quick, lynis, network, integrity, malware"
            return 1
            ;;
    esac
    
    log_separator
    log_info "Security audit completed"
    log_separator
}

# Export functions
export -f run_lynis_audit run_network_scan check_system_integrity
export -f check_rootkits check_malware generate_security_report
export -f run_security_audit
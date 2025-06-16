#!/bin/bash
# HARDN Cron Security Management Script
# Manages automated security tasks and monitoring

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# Configuration
CRON_DIR="/etc/cron.d"
HARDN_CRON_FILE="$CRON_DIR/hardn-security"
LOG_DIR="/var/log/hardn"
SCRIPT_DIR="/usr/local/bin/hardn-scripts"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$SCRIPT_DIR" 2>/dev/null || true

# Helper function to install HARDN security cron jobs
install_hardn_cron_jobs() {
    HARDN_STATUS "info" "Installing HARDN automated security cron jobs..."
    
    # Create the main HARDN cron file
    cat > "$HARDN_CRON_FILE" << 'EOF'
# HARDN Security Automation Cron Jobs
# Managed by HARDN Security Framework
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# System Updates (Daily at 2:00 AM)
0 2 * * * root /usr/local/bin/hardn-scripts/auto-updates.sh >> /var/log/hardn/auto-updates.log 2>&1

# Dependency Updates (Weekly on Sundays at 3:00 AM)
0 3 * * 0 root /usr/local/bin/hardn-scripts/dependency-updates.sh >> /var/log/hardn/dependency-updates.log 2>&1

# Security Tools Status Check (Every 6 hours)
0 */6 * * * root /usr/local/bin/hardn-scripts/security-tools-check.sh >> /var/log/hardn/security-check.log 2>&1

# RKHunter Scan (Daily at 4:00 AM)
0 4 * * * root /usr/local/bin/hardn-scripts/rkhunter-scan.sh >> /var/log/hardn/rkhunter.log 2>&1

# AIDE File Integrity Check (Daily at 5:00 AM)
0 5 * * * root /usr/local/bin/hardn-scripts/aide-check.sh >> /var/log/hardn/aide.log 2>&1

# YARA Malware Scan (Daily at 6:00 AM)
0 6 * * * root /usr/local/bin/hardn-scripts/yara-scan.sh >> /var/log/hardn/yara.log 2>&1

# Fail2Ban Status Check (Every 2 hours)
0 */2 * * * root /usr/local/bin/hardn-scripts/fail2ban-check.sh >> /var/log/hardn/fail2ban.log 2>&1

# AppArmor Status Check (Every 4 hours)
0 */4 * * * root /usr/local/bin/hardn-scripts/apparmor-check.sh >> /var/log/hardn/apparmor.log 2>&1

# NTP Sync Check (Every hour)
0 * * * * root /usr/local/bin/hardn-scripts/ntp-check.sh >> /var/log/hardn/ntp.log 2>&1

# SELinux Status Check (Every 6 hours)
0 */6 * * * root /usr/local/bin/hardn-scripts/selinux-check.sh >> /var/log/hardn/selinux.log 2>&1

# Suricata Status and Rules Update (Daily at 7:00 AM)
0 7 * * * root /usr/local/bin/hardn-scripts/suricata-check.sh >> /var/log/hardn/suricata.log 2>&1

# Weekly Security Report (Sundays at 8:00 AM)
0 8 * * 0 root /usr/local/bin/hardn-scripts/weekly-security-report.sh >> /var/log/hardn/weekly-report.log 2>&1

# Log Rotation and Cleanup (Daily at 1:00 AM)
0 1 * * * root /usr/local/bin/hardn-scripts/log-cleanup.sh >> /var/log/hardn/cleanup.log 2>&1
EOF

    chmod 644 "$HARDN_CRON_FILE"
    HARDN_STATUS "pass" "HARDN cron jobs installed to $HARDN_CRON_FILE"
}

# Create automated script files
create_automation_scripts() {
    HARDN_STATUS "info" "Creating automation scripts..."

    # Auto Updates Script
    cat > "$SCRIPT_DIR/auto-updates.sh" << 'EOF'
#!/bin/bash
# HARDN Auto Updates Script
echo "[$(date)] Starting system updates..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
apt-get autoremove -y -qq
apt-get autoclean -qq
echo "[$(date)] System updates completed"
EOF

    # Dependency Updates Script
    cat > "$SCRIPT_DIR/dependency-updates.sh" << 'EOF'
#!/bin/bash
# HARDN Dependency Updates Script
echo "[$(date)] Starting dependency updates..."
if [ -f /etc/hardn/progs.csv ]; then
    /usr/share/hardn/tools/install_pkgdeps.sh
    echo "[$(date)] Dependency updates completed"
else
    echo "[$(date)] No progs.csv found, skipping dependency updates"
fi
EOF

    # Security Tools Check Script
    cat > "$SCRIPT_DIR/security-tools-check.sh" << 'EOF'
#!/bin/bash
# HARDN Security Tools Status Check
echo "[$(date)] Checking security tools status..."

services=("ufw" "fail2ban" "apparmor" "auditd")
for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        echo "[$(date)] $service: ACTIVE"
    else
        echo "[$(date)] $service: INACTIVE - attempting restart"
        systemctl restart "$service" 2>/dev/null || echo "[$(date)] Failed to restart $service"
    fi
done
EOF

    # RKHunter Scan Script
    cat > "$SCRIPT_DIR/rkhunter-scan.sh" << 'EOF'
#!/bin/bash
# HARDN RKHunter Automated Scan
echo "[$(date)] Starting RKHunter scan..."
if command -v rkhunter >/dev/null 2>&1; then
    rkhunter --update --quiet
    rkhunter --check --skip-keypress --report-warnings-only
    echo "[$(date)] RKHunter scan completed"
else
    echo "[$(date)] RKHunter not installed"
fi
EOF

    # AIDE Check Script
    cat > "$SCRIPT_DIR/aide-check.sh" << 'EOF'
#!/bin/bash
# HARDN AIDE File Integrity Check
echo "[$(date)] Starting AIDE file integrity check..."
if command -v aide >/dev/null 2>&1; then
    if [ -f /var/lib/aide/aide.db ]; then
        aide --check
        echo "[$(date)] AIDE check completed"
    else
        echo "[$(date)] AIDE database not found, initializing..."
        aide --init
        mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    fi
else
    echo "[$(date)] AIDE not installed"
fi
EOF

    # YARA Scan Script
    cat > "$SCRIPT_DIR/yara-scan.sh" << 'EOF'
#!/bin/bash
# HARDN YARA Malware Scan
echo "[$(date)] Starting YARA malware scan..."
if command -v yara >/dev/null 2>&1; then
    if [ -d /usr/local/share/yara ]; then
        find /home /tmp /var/tmp -type f -size -100M -exec yara /usr/local/share/yara/rules/*.yar {} \; 2>/dev/null
        echo "[$(date)] YARA scan completed"
    else
        echo "[$(date)] YARA rules not found"
    fi
else
    echo "[$(date)] YARA not installed"
fi
EOF

    # Fail2Ban Check Script
    cat > "$SCRIPT_DIR/fail2ban-check.sh" << 'EOF'
#!/bin/bash
# HARDN Fail2Ban Status Check
echo "[$(date)] Checking Fail2Ban status..."
if command -v fail2ban-client >/dev/null 2>&1; then
    fail2ban-client status
    fail2ban-client status sshd 2>/dev/null || echo "SSH jail not active"
    echo "[$(date)] Fail2Ban check completed"
else
    echo "[$(date)] Fail2Ban not installed"
fi
EOF

    # AppArmor Check Script
    cat > "$SCRIPT_DIR/apparmor-check.sh" << 'EOF'
#!/bin/bash
# HARDN AppArmor Status Check
echo "[$(date)] Checking AppArmor status..."
if command -v aa-status >/dev/null 2>&1; then
    aa-status --pretty-print
    echo "[$(date)] AppArmor check completed"
else
    echo "[$(date)] AppArmor not installed"
fi
EOF

    # NTP Check Script
    cat > "$SCRIPT_DIR/ntp-check.sh" << 'EOF'
#!/bin/bash
# HARDN NTP Sync Check
echo "[$(date)] Checking NTP sync status..."
if command -v timedatectl >/dev/null 2>&1; then
    timedatectl status
    if timedatectl status | grep -q "NTP synchronized: yes"; then
        echo "[$(date)] NTP sync: OK"
    else
        echo "[$(date)] NTP sync: FAILED - checking service"
        systemctl status systemd-timesyncd
    fi
else
    echo "[$(date)] timedatectl not available"
fi
EOF

    # SELinux Check Script
    cat > "$SCRIPT_DIR/selinux-check.sh" << 'EOF'
#!/bin/bash
# HARDN SELinux Status Check
echo "[$(date)] Checking SELinux status..."
if command -v sestatus >/dev/null 2>&1; then
    sestatus
    echo "[$(date)] SELinux check completed"
elif command -v getenforce >/dev/null 2>&1; then
    echo "SELinux status: $(getenforce)"
else
    echo "[$(date)] SELinux not installed or configured"
fi
EOF

    # Suricata Check Script
    cat > "$SCRIPT_DIR/suricata-check.sh" << 'EOF'
#!/bin/bash
# HARDN Suricata Status and Rules Update
echo "[$(date)] Checking Suricata status..."
if command -v suricata >/dev/null 2>&1; then
    if systemctl is-active --quiet suricata; then
        echo "[$(date)] Suricata: ACTIVE"
        # Update rules if suricata-update is available
        if command -v suricata-update >/dev/null 2>&1; then
            echo "[$(date)] Updating Suricata rules..."
            suricata-update --quiet
            systemctl reload suricata
        fi
    else
        echo "[$(date)] Suricata: INACTIVE"
    fi
else
    echo "[$(date)] Suricata not installed"
fi
EOF

    # Weekly Security Report Script
    cat > "$SCRIPT_DIR/weekly-security-report.sh" << 'EOF'
#!/bin/bash
# HARDN Weekly Security Report
echo "[$(date)] Generating weekly security report..."

REPORT_FILE="/var/log/hardn/weekly-report-$(date +%Y%m%d).txt"

{
    echo "HARDN Weekly Security Report - $(date)"
    echo "========================================="
    echo
    echo "System Information:"
    uname -a
    echo
    echo "Uptime:"
    uptime
    echo
    echo "Security Services Status:"
    for service in ufw fail2ban apparmor auditd; do
        if systemctl is-active --quiet "$service"; then
            echo "$service: ACTIVE"
        else
            echo "$service: INACTIVE"
        fi
    done
    echo
    echo "Recent Security Events (Last 7 days):"
    grep -h "$(date -d '7 days ago' '+%b %d')" /var/log/auth.log* | tail -20
    echo
    echo "Fail2Ban Statistics:"
    fail2ban-client status 2>/dev/null || echo "Fail2Ban not running"
    echo
    echo "Disk Usage:"
    df -h
    echo
    echo "Report generated at: $(date)"
} > "$REPORT_FILE"

echo "[$(date)] Weekly report saved to $REPORT_FILE"
EOF

    # Log Cleanup Script
    cat > "$SCRIPT_DIR/log-cleanup.sh" << 'EOF'
#!/bin/bash
# HARDN Log Cleanup Script
echo "[$(date)] Starting log cleanup..."

# Rotate HARDN logs older than 30 days
find /var/log/hardn -name "*.log" -mtime +30 -delete 2>/dev/null || true

# Compress logs older than 7 days
find /var/log/hardn -name "*.log" -mtime +7 -exec gzip {} \; 2>/dev/null || true

# Clean system logs
journalctl --vacuum-time=30d >/dev/null 2>&1 || true

echo "[$(date)] Log cleanup completed"
EOF

    # Make all scripts executable
    chmod +x "$SCRIPT_DIR"/*.sh
    HARDN_STATUS "pass" "Automation scripts created and made executable"
}

# Main function
main() {
    check_root
    
    case "$1" in
        "install")
            HARDN_STATUS "info" "Installing HARDN security automation..."
            install_hardn_cron_jobs
            create_automation_scripts
            HARDN_STATUS "pass" "HARDN security automation installed successfully"
            ;;
        "remove")
            HARDN_STATUS "info" "Removing HARDN security automation..."
            rm -f "$HARDN_CRON_FILE"
            rm -rf "$SCRIPT_DIR"
            HARDN_STATUS "pass" "HARDN security automation removed"
            ;;
        "status")
            HARDN_STATUS "info" "HARDN automation status:"
            if [ -f "$HARDN_CRON_FILE" ]; then
                echo "Cron jobs: INSTALLED"
                echo "Script directory: $SCRIPT_DIR"
                echo "Log directory: $LOG_DIR"
                echo
                echo "Active cron jobs:"
                grep -v "^#" "$HARDN_CRON_FILE" | grep -v "^$"
            else
                echo "Cron jobs: NOT INSTALLED"
            fi
            ;;
        "edit")
            echo "Opening crontab for editing..."
            crontab -e
            ;;
        "list")
            echo "Current user cron jobs:"
            crontab -l 2>/dev/null || echo "No crontab for user"
            echo
            echo "System HARDN cron jobs:"
            if [ -f "$HARDN_CRON_FILE" ]; then
                cat "$HARDN_CRON_FILE"
            else
                echo "No HARDN cron jobs installed"
            fi
            ;;
        "add")
            if [ -z "$2" ]; then
                echo "Usage: $0 add '<cron_job>'"
                exit 1
            fi
            echo "$2" | crontab -l 2>/dev/null | { cat; echo "$2"; } | crontab -
            echo "Cron job added: $2"
            ;;
        "remove")
            if [ -z "$2" ]; then
                echo "Usage: $0 remove '<cron_job>'"
                exit 1
            fi
            crontab -l | grep -v "$2" | crontab -
            echo "Cron job removed: $2"
            ;;
        *)
            echo "HARDN Cron Security Management"
            echo "Usage: $0 {install|remove|status|edit|list|add|remove} [cron_job]"
            echo
            echo "Commands:"
            echo "  install  - Install HARDN security automation cron jobs"
            echo "  remove   - Remove HARDN security automation"
            echo "  status   - Show automation status"
            echo "  edit     - Edit user crontab"
            echo "  list     - List all cron jobs"
            echo "  add      - Add a custom cron job"
            echo "  remove   - Remove a custom cron job"
            echo
            echo "HARDN Automation includes:"
            echo "  - Daily system updates and security scans"
            echo "  - Continuous monitoring of security services"
            echo "  - Automated malware and integrity checks"
            echo "  - Weekly security reports"
            exit 1
            ;;
    esac
}

main "$@"
log_tool_execution "cron.sh"
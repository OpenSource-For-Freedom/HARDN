#!/bin/bash

install_and_configure_lynis() {
    printf "\033[1;31m[+] Installing and configuring Lynis security auditing tool...\033[0m\n"
    
    # Check if Lynis is already installed
    if dpkg -s lynis >/dev/null 2>&1; then
        printf "\033[1;32m[+] Lynis is already installed.\033[0m\n"
    else
        printf "\033[1;31m[+] Installing Lynis...\033[0m\n"
        apt update
        apt install -y lynis || {
            printf "\033[1;31m[-] Failed to install Lynis.\033[0m\n"
            return 1
        }
    fi

    printf "\033[1;31m[+] Configuring Lynis...\033[0m\n"
    
    # Create Lynis configuration directory
    mkdir -p /etc/lynis
    
    # Create basic Lynis configuration
    cat > /etc/lynis/custom.prf << 'EOF'
# Custom Lynis profile for HARDN

# Log settings
config:log_file:/var/log/lynis.log
config:log_level:normal

# Skip certain tests that might not apply
skip-test:FIRE-4513
skip-test:FIRE-4524

# Set quick mode for automated scans
config:quick:yes

# Set colors for output
config:colors:yes

# Upload settings (disabled by default)
config:upload:no

# Report settings
config:report_file:/var/log/lynis-report.dat
EOF

    # Create log directory
    mkdir -p /var/log/lynis
    touch /var/log/lynis.log
    chmod 640 /var/log/lynis.log
    
    # Create logrotate configuration for Lynis
    cat > /etc/logrotate.d/lynis << 'EOF'
/var/log/lynis.log {
    weekly
    missingok
    rotate 12
    compress
    delaycompress
    notifempty
    copytruncate
}

/var/log/lynis-report.dat {
    weekly
    missingok
    rotate 4
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF

    # Create a script for regular Lynis audits
    cat > /usr/local/bin/lynis-audit.sh << 'EOF'
#!/bin/bash
# Automated Lynis security audit script

LOG_FILE="/var/log/lynis_audit.log"
REPORT_FILE="/var/log/lynis-report.dat"

# Run Lynis audit
echo "$(date): Starting Lynis security audit" >> "$LOG_FILE"
lynis audit system --cronjob --profile /etc/lynis/custom.prf >> "$LOG_FILE" 2>&1

# Check if audit completed successfully
if [ $? -eq 0 ]; then
    echo "$(date): Lynis audit completed successfully" >> "$LOG_FILE"
else
    echo "$(date): Lynis audit failed with exit code $?" >> "$LOG_FILE"
fi
EOF

    chmod +x /usr/local/bin/lynis-audit.sh
    
    printf "\033[1;32m[+] Lynis installed and configured successfully.\033[0m\n"
    printf "\033[1;33m[!] Running initial Lynis audit (this may take a few minutes)...\033[0m\n"
    
    # Run initial audit
    lynis audit system --quick --profile /etc/lynis/custom.prf
    
    printf "\033[1;33m[!] Lynis audit complete. Check /var/log/lynis.log for details.\033[0m\n"
    printf "\033[1;33m[!] To run automated audits, add this to crontab:\033[0m\n"
    printf "0 2 * * * /usr/local/bin/lynis-audit.sh\n"
}

main() {
    install_and_configure_lynis
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

printf "[HARDN] lynis.sh executed at $(date)\n" | tee -a /var/log/hardn/hardn-tools.log

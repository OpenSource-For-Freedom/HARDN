#!/bin/bash


    printf "\033[1;31m[+] Installing and configuring debsums package integrity checker...\033[0m\n"
    
    # Check if debsums is already installed
    if dpkg -s debsums >/dev/null 2>&1; then
        printf "\033[1;32m[+] debsums is already installed.\033[0m\n"
    else
        printf "\033[1;31m[+] Installing debsums...\033[0m\n"
        apt update
        apt install -y debsums || {
            printf "\033[1;31m[-] Failed to install debsums.\033[0m\n"
            return 1
        }
    fi

    printf "\033[1;31m[+] Configuring debsums...\033[0m\n"
    
    # Create debsums configuration
    cat > /etc/debsums-init << 'EOF'
# Configuration for debsums
# Generate checksums for installed packages

CRON_CHECK=weekly
EOF

    # Create directory for debsums data
    mkdir -p /var/lib/debsums
    
    # Create log directory
    mkdir -p /var/log/debsums
    touch /var/log/debsums.log
    chmod 640 /var/log/debsums.log
    
    # Create logrotate configuration for debsums
    cat > /etc/logrotate.d/debsums << 'EOF'
/var/log/debsums.log {
    weekly
    missingok
    rotate 12
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF

    # Create a script for regular debsums checks
    cat > /usr/local/bin/debsums-check.sh << 'EOF'
#!/bin/bash
# Automated debsums integrity check script

LOG_FILE="/var/log/debsums.log"
REPORT_FILE="/var/log/debsums-report.txt"

echo "$(date): Starting debsums integrity check" >> "$LOG_FILE"

# Check all installed packages
debsums -s > "$REPORT_FILE" 2>&1

# Check if any files were modified
if [ -s "$REPORT_FILE" ]; then
    echo "$(date): WARNING - Modified files detected:" >> "$LOG_FILE"
    cat "$REPORT_FILE" >> "$LOG_FILE"
    
    # Count modified files
    COUNT=$(wc -l < "$REPORT_FILE")
    echo "$(date): Total modified files: $COUNT" >> "$LOG_FILE"
else
    echo "$(date): No modified files detected - system integrity OK" >> "$LOG_FILE"
fi

echo "$(date): debsums check completed" >> "$LOG_FILE"
EOF

    chmod +x /usr/local/bin/debsums-check.sh
    
    printf "\033[1;31m[+] Generating initial checksums (this may take several minutes)...\033[0m\n"
    
    # Generate checksums for installed packages
    debsums-init || {
        printf "\033[1;33m[!] Some packages may not have checksums available.\033[0m\n"
    }
    
    printf "\033[1;32m[+] debsums installed and configured successfully.\033[0m\n"
    printf "\033[1;33m[!] Running initial integrity check...\033[0m\n"
    
    # Run initial check
    /usr/local/bin/debsums-check.sh
    
    printf "\033[1;33m[!] debsums check complete. Check /var/log/debsums.log for details.\033[0m\n"
    printf "\033[1;33m[!] To run automated checks, add this to crontab:\033[0m\n"
    printf "0 3 * * 0 /usr/local/bin/debsums-check.sh\n"

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

printf "[HARDN] debsums.sh executed at $(date)\n" | tee -a /var/log/hardn/hardn-tools.log

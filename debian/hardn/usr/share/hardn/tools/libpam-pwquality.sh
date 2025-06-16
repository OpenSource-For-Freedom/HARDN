#!/bin/bash


    printf "\033[1;31m[+] Installing and configuring PAM password quality checking...\033[0m\n"
    
    # Check if libpam-pwquality is already installed
    if dpkg -s libpam-pwquality >/dev/null 2>&1; then
        printf "\033[1;32m[+] libpam-pwquality is already installed.\033[0m\n"
    else
        printf "\033[1;31m[+] Installing libpam-pwquality...\033[0m\n"
        apt update
        apt install -y libpam-pwquality || {
            printf "\033[1;31m[-] Failed to install libpam-pwquality.\033[0m\n"
            return 1
        }
    fi

    printf "\033[1;31m[+] Configuring PAM password quality requirements...\033[0m\n"
    
    # Backup original configuration
    cp /etc/security/pwquality.conf /etc/security/pwquality.conf.backup 2>/dev/null || true
    
    # Configure password quality requirements
    cat > /etc/security/pwquality.conf << 'EOF'
# Configuration for systemwide password quality limits
# See pwquality.conf(5) for more information

# Number of characters in the new password that must not be present in the old password
difok = 3

# Minimum acceptable size for the new password
minlen = 12

# Maximum credit for having digits in the new password
dcredit = -1

# Maximum credit for having uppercase characters in the new password
ucredit = -1

# Maximum credit for having lowercase characters in the new password
lcredit = -1

# Maximum credit for having other characters in the new password
ocredit = -1

# Minimum number of required classes of characters for the new password
minclass = 3

# Maximum number of allowed consecutive characters of the same class
maxrepeat = 3

# Maximum number of allowed consecutive characters from the same class
maxclassrepeat = 3

# Whether to check if the password contains the user name in some form
usercheck = 1

# Maximum number of characters that the password can grow with when being strengthened
enforcing = 1

# The length of the generated random passwords
authtok_type = 
EOF

    # Configure PAM to use pwquality for password changes
    printf "\033[1;31m[+] Configuring PAM modules...\033[0m\n"
    
    # Backup PAM configuration files
    cp /etc/pam.d/common-password /etc/pam.d/common-password.backup 2>/dev/null || true
    
    # Update common-password to use pwquality
    if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
        # Add pwquality module
        sed -i '/^password.*pam_unix.so/i password\trequired\tpam_pwquality.so retry=3' /etc/pam.d/common-password
        printf "\033[1;32m[+] Added pwquality to PAM configuration.\033[0m\n"
    else
        printf "\033[1;33m[!] pwquality already configured in PAM.\033[0m\n"
    fi
    
    # Configure password aging in login.defs
    printf "\033[1;31m[+] Configuring password aging policies...\033[0m\n"
    
    cp /etc/login.defs /etc/login.defs.backup 2>/dev/null || true
    
    # Set password aging parameters
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS\t90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS\t7/' /etc/login.defs
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE\t14/' /etc/login.defs
    
    # Add lines if they don't exist
    if ! grep -q "^PASS_MAX_DAYS" /etc/login.defs; then
        echo "PASS_MAX_DAYS	90" >> /etc/login.defs
    fi
    if ! grep -q "^PASS_MIN_DAYS" /etc/login.defs; then
        echo "PASS_MIN_DAYS	7" >> /etc/login.defs
    fi
    if ! grep -q "^PASS_WARN_AGE" /etc/login.defs; then
        echo "PASS_WARN_AGE	14" >> /etc/login.defs
    fi
    
    printf "\033[1;32m[+] PAM password quality checking installed and configured successfully.\033[0m\n"
    printf "\033[1;33m[!] Password policy requirements:\033[0m\n"
    printf "  - Minimum length: 12 characters\n"
    printf "  - Must contain: uppercase, lowercase, digit, and special character\n"
    printf "  - Maximum password age: 90 days\n"
    printf "  - Minimum password age: 7 days\n"
    printf "  - Warning period: 14 days\n"
    printf "\033[1;33m[!] These settings will apply to new passwords only.\033[0m\n"

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

printf "[HARDN] libpam-pwquality.sh executed at $(date)\n" | tee -a /var/log/hardn/hardn-tools.log

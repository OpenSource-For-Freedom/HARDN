#!/bin/bash

install_and_configure_ufw() {
    printf "\033[1;31m[+] Installing and configuring UFW (Uncomplicated Firewall)...\033[0m\n"
    
    # Check if UFW is already installed
    if dpkg -s ufw >/dev/null 2>&1; then
        printf "\033[1;32m[+] UFW is already installed.\033[0m\n"
    else
        printf "\033[1;31m[+] Installing UFW...\033[0m\n"
        apt update
        apt install -y ufw || {
            printf "\033[1;31m[-] Failed to install UFW.\033[0m\n"
            return 1
        }
    fi

    printf "\033[1;31m[+] Configuring UFW firewall rules...\033[0m\n"
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (be careful not to lock yourself out)
    ufw allow ssh
    
    # Allow common outbound ports
    ufw allow out 53/tcp    # DNS
    ufw allow out 53/udp    # DNS
    ufw allow out 80/tcp    # HTTP
    ufw allow out 443/tcp   # HTTPS
    ufw allow out 123/udp   # NTP
    ufw allow out 67/udp    # DHCP client
    ufw allow out 68/udp    # DHCP client
    
    # Enable UFW
    ufw --force enable
    
    # Enable UFW service
    systemctl enable --now ufw
    
    printf "\033[1;32m[+] UFW installed and configured successfully.\033[0m\n"
    printf "\033[1;33m[!] UFW Status:\033[0m\n"
    ufw status verbose
}

main() {
    install_and_configure_ufw
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

printf "[HARDN] ufw.sh executed at $(date)\n" | tee -a /var/log/hardn/hardn-tools.log

#!/bin/bash


    echo "[INFO] Installing and configuring TCP Wrappers (tcpd)..."
    
    # Check if tcpd is already installed
    if dpkg -s tcpd >/dev/null 2>&1; then
        echo "[SUCCESS] TCP Wrappers (tcpd) is already installed."
    else
        echo "[INFO] Installing TCP Wrappers (tcpd)..."
        apt update
        apt install -y tcpd || {
            echo "[ERROR] Failed to install TCP Wrappers."
            return 1
        }
    fi

    echo "[INFO] Configuring TCP Wrappers access control..."
    
    # Create /etc/hosts.allow with basic SSH access
    if [ ! -f /etc/hosts.allow ]; then
        cat > /etc/hosts.allow << 'EOF'
# /etc/hosts.allow: list of hosts that are allowed to access the system.
# See the manual pages hosts_access(5) and hosts_options(5).

# Allow SSH from local network (adjust as needed)
sshd: 127.0.0.1
sshd: 192.168.0.0/16
sshd: 10.0.0.0/8
sshd: 172.16.0.0/12

# Allow local services
ALL: 127.0.0.1
EOF
        echo "[SUCCESS] Created /etc/hosts.allow with basic rules."
    else
        echo "[WARNING] /etc/hosts.allow already exists, not overwriting."
    fi
    
    # Create /etc/hosts.deny to deny all others
    if [ ! -f /etc/hosts.deny ]; then
        cat > /etc/hosts.deny << 'EOF'
# /etc/hosts.deny: list of hosts that are _not_ allowed to access the system.
# See the manual pages hosts_access(5) and hosts_options(5).

# Deny all other connections by default
ALL: ALL
EOF
        echo "[SUCCESS] Created /etc/hosts.deny to deny all unlisted connections."
    else
        echo "[WARNING] /etc/hosts.deny already exists, not overwriting."
    fi
    
    echo "[SUCCESS] TCP Wrappers installed and configured successfully."
    echo "[INFO] Current TCP Wrappers configuration:"
    echo "=== /etc/hosts.allow ==="
    cat /etc/hosts.allow 2>/dev/null || echo "File not found"
    echo "=== /etc/hosts.deny ==="
    cat /etc/hosts.deny 2>/dev/null || echo "File not found"

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

printf "[HARDN] tcpd.sh executed at $(date)\n" | tee -a /var/log/hardn/hardn-tools.log

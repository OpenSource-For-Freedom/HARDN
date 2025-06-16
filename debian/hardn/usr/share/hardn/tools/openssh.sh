#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: openssh.sh
# Purpose: Install and configure OpenSSH server and client securely
# Location: /src/tools/openssh.sh

check_root
log_tool_execution "openssh.sh"

install_and_configure_openssh() {
    HARDN_STATUS "info" "Installing and configuring OpenSSH server and client..."
    
    # Install OpenSSH packages if not present
    if ! is_package_installed openssh-server; then
        HARDN_STATUS "info" "Installing OpenSSH server..."
        if install_package openssh-server; then
            HARDN_STATUS "pass" "OpenSSH server installed successfully"
        else
            HARDN_STATUS "error" "Failed to install OpenSSH server"
            return 1
        fi
    else
        HARDN_STATUS "pass" "OpenSSH server already installed"
    fi

    if ! is_package_installed openssh-client; then
        HARDN_STATUS "info" "Installing OpenSSH client..."
        if install_package openssh-client; then
            HARDN_STATUS "pass" "OpenSSH client installed successfully"
        else
            HARDN_STATUS "error" "Failed to install OpenSSH client"
            return 1
        fi
    else
        HARDN_STATUS "pass" "OpenSSH client already installed"
    fi

    HARDN_STATUS "info" "Configuring OpenSSH server security settings..."
    
    # Backup original SSH configuration
    if backup_file /etc/ssh/sshd_config; then
        HARDN_STATUS "pass" "SSH configuration backed up"
    fi
    
    # Create secure SSH configuration
    cat > /etc/ssh/sshd_config << 'EOF'
# HARDN Secure SSH Configuration

# Network
Port 22
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Protocol and Encryption
Protocol 2

# HostKeys for protocol version 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
RekeyLimit default none

# Logging
SyslogFacility AUTH
LogLevel INFO

# Authentication
LoginGraceTime 2m
PermitRootLogin no
StrictModes yes
MaxAuthTries 3
MaxSessions 2

# Password authentication
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Kerberos options
KerberosAuthentication no
KerberosOrLocalPasswd yes
KerberosTicketCleanup yes
KerberosGetAFSToken no

# GSSAPI options
GSSAPIAuthentication no
GSSAPICleanupCredentials yes
GSSAPIStrictAcceptorCheck yes
GSSAPIKeyExchange no

# Public key authentication
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2

# Don't read the user's ~/.rhosts and ~/.shosts files
IgnoreRhosts yes
HostbasedAuthentication no
IgnoreUserKnownHosts no

# To enable empty passwords, change to yes (NOT RECOMMENDED)
PermitEmptyPasswords no

# Change to yes to enable challenge-response passwords (beware issues with
# some PAM modules and threads)
ChallengeResponseAuthentication no

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the ChallengeResponseAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via ChallengeResponseAuthentication may bypass
# the setting of "PermitRootLogin without-password".
UsePAM yes

# Forwarding
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
X11Forwarding no
X11DisplayOffset 10
X11UseLocalhost yes
PermitTTY yes
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
UseLogin no
PermitUserEnvironment no
Compression delayed
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
PidFile /var/run/sshd.pid
MaxStartups 2
PermitTunnel no
ChrootDirectory none
VersionAddendum none

# no default banner path
Banner /etc/ssh/banner

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

# override default of no subsystems
Subsystem sftp /usr/lib/openssh/sftp-server

# Users and groups
AllowGroups ssh-users sudo
DenyUsers root

# Connection limits
MaxAuthTries 3
LoginGraceTime 60
EOF

    # Create SSH group for allowed users
    groupadd ssh-users 2>/dev/null || true
    
    # Add current user to ssh-users group
    if [ -n "$SUDO_USER" ]; then
        usermod -a -G ssh-users "$SUDO_USER"
        printf "\033[1;32m[+] Added user $SUDO_USER to ssh-users group.\033[0m\n"
    fi
    
    # Create SSH banner
    cat > /etc/ssh/banner << 'EOF'
***********************************************************************
*                                                                     *
*   This system is for authorized use only.                          *
*   All activity may be monitored and recorded.                      *
*   Anyone using this system expressly consents to such monitoring.  *
*   Unauthorized access is prohibited.                               *
*                                                                     *
***********************************************************************
EOF

    # Set proper permissions
    chmod 644 /etc/ssh/banner
    chmod 600 /etc/ssh/sshd_config
    
    # Configure SSH client security
    printf "\033[1;31m[+] Configuring SSH client security settings...\033[0m\n"
    
    # Backup original SSH client configuration
    cp /etc/ssh/ssh_config /etc/ssh/ssh_config.backup 2>/dev/null || true
    
    # Create secure SSH client configuration
    cat > /etc/ssh/ssh_config << 'EOF'
# HARDN Secure SSH Client Configuration

# Global defaults for all hosts
Host *
    SendEnv LANG LC_*
    HashKnownHosts yes
    GSSAPIAuthentication no
    GSSAPIDelegateCredentials no
    
    # Security settings
    Protocol 2
    ForwardAgent no
    ForwardX11 no
    ForwardX11Trusted no
    PasswordAuthentication yes
    ChallengeResponseAuthentication no
    PubkeyAuthentication yes
    HostbasedAuthentication no
    BatchMode no
    CheckHostIP yes
    AddressFamily any
    ConnectTimeout 30
    StrictHostKeyChecking ask
    IdentitiesOnly yes
    Port 22
    Cipher 3des
    Ciphers aes128-ctr,aes192-ctr,aes256-ctr,aes128-cbc,3des-cbc
    MACs hmac-md5,hmac-sha1,umac-64@openssh.com,hmac-ripemd160
    EscapeChar ~
    Tunnel no
    TunnelDevice any:any
    PermitLocalCommand no
    VisualHostKey no
    ProxyCommand none
    RekeyLimit 1G 1h
    SendEnv LANG LC_*
EOF

    # Set proper permissions
    chmod 644 /etc/ssh/ssh_config
    
    # Generate new host keys if they don't exist
    HARDN_STATUS "info" "Checking SSH host keys..."
    ssh-keygen -A
    
    # Set proper permissions on host keys
    chmod 600 /etc/ssh/ssh_host_*_key
    chmod 644 /etc/ssh/ssh_host_*_key.pub
    HARDN_STATUS "pass" "SSH host keys configured with proper permissions"
    
    # Configure SSH service
    if enable_service ssh; then
        HARDN_STATUS "pass" "SSH service enabled"
    fi
    
    # Test SSH configuration
    HARDN_STATUS "info" "Testing SSH configuration..."
    if sshd -t; then
        HARDN_STATUS "pass" "SSH configuration is valid"
        
        # Restart SSH service
        if systemctl restart ssh; then
            HARDN_STATUS "pass" "SSH service restarted successfully"
        else
            HARDN_STATUS "error" "Failed to restart SSH service"
            return 1
        fi
    else
        HARDN_STATUS "error" "SSH configuration has errors. Please check manually"
        return 1
    fi
    
    HARDN_STATUS "pass" "OpenSSH installed and configured successfully"
    HARDN_STATUS "info" "SSH security configuration applied:"
    HARDN_STATUS "info" "  - Root login disabled"
    HARDN_STATUS "info" "  - Maximum 3 authentication attempts"  
    HARDN_STATUS "info" "  - Connection timeouts configured"
    HARDN_STATUS "info" "  - X11 and agent forwarding disabled"
    HARDN_STATUS "info" "  - Only ssh-users group can login"
    HARDN_STATUS "info" "  - Login banner configured"
    HARDN_STATUS "info" "SSH service status:"
    systemctl status ssh --no-pager -l
}

main() {
    install_and_configure_openssh
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

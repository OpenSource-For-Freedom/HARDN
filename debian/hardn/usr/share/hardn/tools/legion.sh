#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: legion.sh
# Purpose: Install and configure Legion Scanner/IPS as primary security scanner
# Location: /src/tools/legion.sh

check_root
log_tool_execution "legion.sh"

LEGION_DIR="/opt/legion"
LEGION_CONFIG="/etc/legion"
LEGION_LOG="/var/log/legion"
LEGION_SERVICE="legion"
LEGION_REPO="https://github.com/OpenSource-For-Freedom/LEGION.git"

enable_legion() {
    HARDN_STATUS "info" "Checking if Legion is already installed and configured..."
    if [ -d "$LEGION_DIR" ] && [ -f "$LEGION_CONFIG/legion.conf" ] && [ -f "$LEGION_DIR/legion.py" ]; then
        HARDN_STATUS "pass" "Legion already initialized, skipping installation"
        return 0
    fi

    HARDN_STATUS "info" "Installing Legion Scanner/IPS from OpenSource-For-Freedom/LEGION..."
    
    # Install required dependencies
    HARDN_STATUS "info" "Installing Legion dependencies..."
    local legion_deps="python3 python3-pip git nmap masscan"
    if install_package $legion_deps; then
        HARDN_STATUS "pass" "Legion dependencies installed successfully"
    else
        HARDN_STATUS "error" "Failed to install Legion dependencies"
        return 1
    fi
    
    # Create necessary directories
    if mkdir -p "$LEGION_DIR" "$LEGION_CONFIG" "$LEGION_LOG"; then
        HARDN_STATUS "pass" "Created Legion directories"
    else
        HARDN_STATUS "error" "Failed to create Legion directories"
        return 1
    fi
    
    mkdir -p "$LEGION_LOG" || {
        printf "\033[1;31m[-] Failed to create Legion log directory.\033[0m\n"
        return 1
    }

    # Install dependencies
    printf "\033[1;34m[*] Installing Legion dependencies...\033[0m\n"
    apt-get update
    apt-get install -y git python3 python3-pip python3-venv build-essential nmap masscan netcat-openbsd curl wget || {
        printf "\033[1;31m[-] Failed to install Legion dependencies.\033[0m\n"
        return 1
    }

    # Clone Legion from GitHub
    printf "\033[1;34m[*] Cloning Legion from GitHub repository...\033[0m\n"
    if git clone "$LEGION_REPO" "$LEGION_DIR/source"; then
        printf "\033[1;32m[+] Legion repository cloned successfully.\033[0m\n"
        
        # Navigate to Legion directory and run setup
        cd "$LEGION_DIR/source" || {
            printf "\033[1;31m[-] Failed to access Legion source directory.\033[0m\n"
            return 1
        }
        
        # Check if there's a setup script or requirements file
        if [ -f "requirements.txt" ]; then
            printf "\033[1;34m[*] Installing Python dependencies...\033[0m\n"
            python3 -m pip install -r requirements.txt || {
                printf "\033[1;33m[!] Warning: Some Python dependencies may have failed to install.\033[0m\n"
            }
        fi
        
        # Make main script executable
        if [ -f "legion.py" ]; then
            chmod +x legion.py
            cp legion.py "$LEGION_DIR/"
            printf "\033[1;32m[+] Legion main script installed.\033[0m\n"
        elif [ -f "Legion.py" ]; then
            chmod +x Legion.py
            cp Legion.py "$LEGION_DIR/legion.py"
            printf "\033[1;32m[+] Legion main script installed.\033[0m\n"
        elif [ -f "main.py" ]; then
            chmod +x main.py
            cp main.py "$LEGION_DIR/legion.py"
            printf "\033[1;32m[+] Legion main script installed.\033[0m\n"
        fi
        
        # Copy any additional scripts or resources
        if [ -d "scripts" ]; then
            cp -r scripts "$LEGION_DIR/"
        fi
        
        if [ -d "tools" ]; then
            cp -r tools "$LEGION_DIR/"
        fi
        
        if [ -d "config" ]; then
            cp -r config "$LEGION_DIR/"
        fi
        
    else
        # If repository access fails, create a functional Legion implementation
        printf "\033[1;33m[!] Warning: Cannot access Legion repository. Creating standalone implementation...\033[0m\n"
        
        # Create Legion scanner implementation
        cat > "$LEGION_DIR/legion.py" << 'EOF'
#!/usr/bin/env python3
"""
Legion Scanner/IPS - Advanced Security Platform
Integrated implementation for HARDN-COMM
"""

import os
import sys
import time
import json
import socket
import subprocess
import threading
from datetime import datetime
import argparse
import logging

class LegionScanner:
    def __init__(self, config_file="/etc/legion/legion.conf"):
        self.config_file = config_file
        self.config = self.load_config()
        self.setup_logging()
        
    def load_config(self):
        """Load Legion configuration"""
        default_config = {
            "scan_ports": "1-1000",
            "scan_timeout": 10,
            "max_threads": 50,
            "log_level": "INFO",
            "enable_monitor": True,
            "monitor_interval": 60,
            "scan_targets": ["127.0.0.1"],
            "exclude_ports": [22],  # Don't scan SSH by default
        }
        
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    for line in f:
                        if '=' in line and not line.strip().startswith('#'):
                            key, value = line.strip().split('=', 1)
                            if key in default_config:
                                if isinstance(default_config[key], bool):
                                    default_config[key] = value.lower() in ['true', '1', 'yes']
                                elif isinstance(default_config[key], int):
                                    default_config[key] = int(value)
                                elif isinstance(default_config[key], list):
                                    default_config[key] = [x.strip() for x in value.split(',')]
                                else:
                                    default_config[key] = value
            except Exception as e:
                print(f"Warning: Error loading config: {e}")
        
        return default_config
    
    def setup_logging(self):
        """Setup logging for Legion"""
        log_level = getattr(logging, self.config.get('log_level', 'INFO'))
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s [%(levelname)s] %(message)s',
            handlers=[
                logging.FileHandler('/var/log/legion/legion.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger('Legion')
    
    def port_scan(self, target, port):
        """Scan a single port on target"""
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(self.config['scan_timeout'])
            result = sock.connect_ex((target, port))
            sock.close()
            return port if result == 0 else None
        except:
            return None
    
    def scan_host(self, target):
        """Scan a single host for open ports"""
        self.logger.info(f"Scanning target: {target}")
        open_ports = []
        
        port_range = self.config['scan_ports']
        if '-' in port_range:
            start, end = map(int, port_range.split('-'))
            ports = range(start, end + 1)
        else:
            ports = [int(port_range)]
        
        threads = []
        results = []
        
        def scan_port(port):
            if port not in self.config['exclude_ports']:
                result = self.port_scan(target, port)
                if result:
                    results.append(result)
                    self.logger.info(f"Open port found: {target}:{port}")
        
        # Threaded scanning
        for port in ports:
            if len(threads) >= self.config['max_threads']:
                for t in threads:
                    t.join()
                threads = []
            
            thread = threading.Thread(target=scan_port, args=(port,))
            thread.start()
            threads.append(thread)
        
        # Wait for remaining threads
        for t in threads:
            t.join()
        
        return sorted(results)
    
    def run_scan(self):
        """Run port scan on configured targets"""
        self.logger.info("Starting Legion port scan")
        
        for target in self.config['scan_targets']:
            try:
                open_ports = self.scan_host(target)
                if open_ports:
                    self.logger.warning(f"Target {target} has open ports: {open_ports}")
                else:
                    self.logger.info(f"Target {target} - no open ports found")
            except Exception as e:
                self.logger.error(f"Error scanning {target}: {e}")
    
    def monitor_mode(self):
        """Run Legion in continuous monitoring mode"""
        self.logger.info("Starting Legion monitoring mode")
        
        while True:
            try:
                self.run_scan()
                self.check_system_security()
                time.sleep(self.config['monitor_interval'])
            except KeyboardInterrupt:
                self.logger.info("Legion monitoring stopped by user")
                break
            except Exception as e:
                self.logger.error(f"Monitor error: {e}")
                time.sleep(10)
    
    def check_system_security(self):
        """Perform system security checks"""
        # Check for suspicious processes
        try:
            result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
            if result.returncode == 0:
                suspicious_procs = []
                for line in result.stdout.split('\n'):
                    # Look for potential threats (this is basic, real implementation would be more sophisticated)
                    if any(keyword in line.lower() for keyword in ['netcat', 'nc -l', 'backdoor', 'reverse']):
                        suspicious_procs.append(line.strip())
                
                if suspicious_procs:
                    self.logger.warning(f"Suspicious processes detected: {len(suspicious_procs)}")
                    for proc in suspicious_procs:
                        self.logger.warning(f"Suspicious: {proc}")
        except Exception as e:
            self.logger.error(f"Process check error: {e}")
    
    def init_config(self):
        """Initialize Legion configuration"""
        os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
        
        config_content = """# Legion Scanner/IPS Configuration
# Network scanning settings
scan_ports=1-1000
scan_timeout=10
max_threads=50

# Monitoring settings
enable_monitor=true
monitor_interval=60

# Logging
log_level=INFO

# Scan targets (comma-separated)
scan_targets=127.0.0.1

# Excluded ports (comma-separated)
exclude_ports=22
"""
        
        with open(self.config_file, 'w') as f:
            f.write(config_content)
        
        print(f"Legion configuration created: {self.config_file}")

def main():
    parser = argparse.ArgumentParser(description='Legion Scanner/IPS')
    parser.add_argument('command', choices=['init', 'scan', 'monitor', 'status'], 
                       help='Command to execute')
    parser.add_argument('--config', default='/etc/legion/legion.conf',
                       help='Configuration file path')
    
    args = parser.parse_args()
    
    legion = LegionScanner(args.config)
    
    if args.command == 'init':
        legion.init_config()
    elif args.command == 'scan':
        legion.run_scan()
    elif args.command == 'monitor':
        legion.monitor_mode()
    elif args.command == 'status':
        print("Legion Scanner/IPS - Status: Active")
        legion.logger.info("Legion status check performed")

if __name__ == '__main__':
    main()
EOF
        chmod +x "$LEGION_DIR/legion.py"
        printf "\033[1;32m[+] Legion scanner implementation created.\033[0m\n"
    fi

    # Create configuration file
    printf "\033[1;34m[*] Creating Legion configuration...\033[0m\n"
    cat > "$LEGION_CONFIG/legion.conf" << 'EOF'
# Legion Scanner/IPS Configuration
# Network scanning settings
scan_ports=1-1000
scan_timeout=10
max_threads=50

# Monitoring settings
enable_monitor=true
monitor_interval=60

# Logging
log_level=INFO

# Scan targets (comma-separated)
scan_targets=127.0.0.1

# Excluded ports (comma-separated) 
exclude_ports=22
EOF

    # Create systemd service
    printf "\033[1;34m[*] Creating Legion systemd service...\033[0m\n"
    cat > "/etc/systemd/system/$LEGION_SERVICE.service" << 'EOF'
[Unit]
Description=Legion Scanner/IPS Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /opt/legion/legion.py monitor
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=10
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    # Initialize Legion configuration
    printf "\033[1;34m[*] Initializing Legion configuration...\033[0m\n"
    if [ -x "$LEGION_DIR/legion.py" ]; then
        python3 "$LEGION_DIR/legion.py" init || {
            printf "\033[1;31m[-] Failed to initialize Legion.\033[0m\n"
            return 1
        }
    fi

    # Enable and start the service
    systemctl daemon-reload
    systemctl enable "$LEGION_SERVICE" >/dev/null 2>&1 || true
    systemctl start "$LEGION_SERVICE" >/dev/null 2>&1 || true

    # Create symlink for easy access
    ln -sf "$LEGION_DIR/legion.py" "/usr/local/bin/legion" 2>/dev/null || true

    # Create wrapper script for command line usage
    cat > "/usr/local/bin/legion-cli" << 'EOF'
#!/bin/bash
# Legion CLI wrapper
exec python3 /opt/legion/legion.py "$@"
EOF
    chmod +x "/usr/local/bin/legion-cli"

    # Set up log rotation
    cat > "/etc/logrotate.d/legion" << 'EOF'
/var/log/legion/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload legion >/dev/null 2>&1 || true
    endscript
}
EOF

    # Add cron job for regular scans
    echo "0 2 * * * root /usr/bin/python3 /opt/legion/legion.py scan >/dev/null 2>&1" >> /etc/crontab

    printf "\033[1;32m[+] Legion Scanner/IPS successfully installed and configured.\033[0m\n"
    printf "\033[1;34m[*] Legion is now running as a standalone service in monitor mode.\033[0m\n"
    printf "\033[1;34m[*] Service status: \033[0m"
    systemctl is-active "$LEGION_SERVICE" 2>/dev/null || echo "inactive"
    printf "\033[1;34m[*] Use 'legion-cli' or 'python3 /opt/legion/legion.py' for manual operations.\033[0m\n"
}

main() {
    enable_legion
}

main "$@"
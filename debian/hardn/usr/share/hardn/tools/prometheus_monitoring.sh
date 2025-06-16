#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: prometheus_monitoring.sh
# Purpose: Configure Prometheus node exporter and SSH tunnel setup for centralized monitoring
# Location: /src/tools/prometheus_monitoring.sh

check_root
log_tool_execution "prometheus_monitoring.sh"

HARDN_CONFIG="/etc/hardn.conf"

check_chroot() {
    if grep -q 'chroot' /proc/1/environ 2>/dev/null; then
        HARDN_STATUS "info" "Running in chroot mode, skipping monitoring setup"
        return 0
    fi
    return 1
}

install_node_exporter() {
    HARDN_STATUS "info" "Installing Prometheus Node Exporter..."
    
    # Download and install node_exporter
    local EXPORTER_VERSION="1.6.1"
    EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${EXPORTER_VERSION}/node_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz"
    
    cd /tmp
    wget -q "$EXPORTER_URL" -O node_exporter.tar.gz
    local EXPORTER_ARCH="amd64"
    local EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${EXPORTER_VERSION}/node_exporter-${EXPORTER_VERSION}.linux-${EXPORTER_ARCH}.tar.gz"
    
    # Check if node_exporter is already installed
    if command_exists node_exporter; then
        HARDN_STATUS "pass" "Node Exporter already installed"
        return 0
    fi
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || {
        HARDN_STATUS "error" "Failed to create temporary directory"
        return 1
    }
    
    # Download and install
    if wget -q "$EXPORTER_URL" -O node_exporter.tar.gz; then
        HARDN_STATUS "pass" "Downloaded Node Exporter successfully"
    else
        HARDN_STATUS "error" "Failed to download Node Exporter"
        return 1
    fi
    
    tar xzf node_exporter.tar.gz
    sudo mv "node_exporter-${EXPORTER_VERSION}.linux-${EXPORTER_ARCH}/node_exporter" /usr/local/bin/
    sudo chmod +x /usr/local/bin/node_exporter
    
    # Cleanup
    cd /
    rm -rf "$temp_dir"
    
    # Create node_exporter user
    if ! id node_exporter >/dev/null 2>&1; then
        sudo useradd --no-create-home --shell /bin/false node_exporter
        HARDN_STATUS "pass" "Created node_exporter user"
    fi
    
    HARDN_STATUS "pass" "Node Exporter installed successfully"
}

create_systemd_service() {
    HARDN_STATUS "info" "Creating Node Exporter systemd service..."
    
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \\
    --web.listen-address=127.0.0.1:9100 \\
    --collector.systemd \\
    --collector.processes \\
    --collector.filesystem.mount-points-exclude="^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)"

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    if sudo systemctl enable node_exporter && sudo systemctl start node_exporter; then
        HARDN_STATUS "pass" "Node Exporter service created and started"
    else
        HARDN_STATUS "error" "Failed to start Node Exporter service"
        return 1
    fi
}

configure_ssh_tunnel() {
    local central_server="$1"
    local ssh_key_path="$2"
    
    HARDN_STATUS "info" "Configuring SSH tunnel for monitoring connectivity..."
    
    # Create SSH tunnel script
    sudo tee /usr/local/bin/hardn-monitoring-tunnel.sh > /dev/null <<EOF
#!/bin/bash
# HARDN Monitoring SSH Tunnel Script

CENTRAL_SERVER="$central_server"
SSH_KEY="$ssh_key_path"
LOCAL_PORT=9100
REMOTE_PORT=\$(shuf -i 19100-19999 -n 1)

# Create reverse SSH tunnel
ssh -i "\$SSH_KEY" \\
    -o StrictHostKeyChecking=no \\
    -o UserKnownHostsFile=/dev/null \\
    -o ServerAliveInterval=60 \\
    -o ServerAliveCountMax=3 \\
    -R "\$REMOTE_PORT:127.0.0.1:\$LOCAL_PORT" \\
    -N "\$CENTRAL_SERVER"
EOF

    sudo chmod +x /usr/local/bin/hardn-monitoring-tunnel.sh
    
    # Create systemd service for SSH tunnel
    sudo tee /etc/systemd/system/hardn-monitoring-tunnel.service > /dev/null <<EOF
[Unit]
Description=HARDN Monitoring SSH Tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hardn-monitoring-tunnel.sh
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable hardn-monitoring-tunnel.service
    
    log_message "SSH tunnel configured for monitoring"
}

create_custom_metrics() {
    log_message "Setting up custom HARDN metrics..."
    
    # Create directory for custom metrics
    sudo mkdir -p /var/lib/node_exporter/textfile_collector
    
    # Create HARDN compliance metrics script
    sudo tee /usr/local/bin/hardn-metrics-collector.sh > /dev/null <<'EOF'
#!/bin/bash
# HARDN Custom Metrics Collector

METRICS_FILE="/var/lib/node_exporter/textfile_collector/hardn.prom"
HARDN_CONFIG="/etc/hardn.conf"

# Initialize metrics file
cat > "$METRICS_FILE" <<METRICS
# HELP hardn_compliance_status HARDN compliance status (1=compliant, 0=non-compliant)
# TYPE hardn_compliance_status gauge
# HELP hardn_last_run_timestamp Unix timestamp of last HARDN run
# TYPE hardn_last_run_timestamp gauge
# HELP hardn_security_events_total Total number of security events detected
# TYPE hardn_security_events_total counter
METRICS

# Check HARDN completion status
if [[ -f "$HARDN_CONFIG" ]] && grep -q "HARDN_COMPLETE=true" "$HARDN_CONFIG"; then
    echo "hardn_compliance_status 1" >> "$METRICS_FILE"
else
    echo "hardn_compliance_status 0" >> "$METRICS_FILE"
fi

# Last run timestamp
if [[ -f "/var/log/hardn.log" ]]; then
    LAST_RUN=$(stat -c %Y /var/log/hardn.log)
    echo "hardn_last_run_timestamp $LAST_RUN" >> "$METRICS_FILE"
fi

# Security events from logs
SECURITY_EVENTS=$(grep -c "SECURITY_EVENT" /var/log/hardn.log 2>/dev/null || echo 0)
echo "hardn_security_events_total $SECURITY_EVENTS" >> "$METRICS_FILE"

# System hardening metrics
echo "hardn_ssh_hardened $(systemctl is-active ssh >/dev/null && echo 1 || echo 0)" >> "$METRICS_FILE"
echo "hardn_firewall_active $(ufw status | grep -q "Status: active" && echo 1 || echo 0)" >> "$METRICS_FILE"
echo "hardn_auditd_active $(systemctl is-active auditd >/dev/null && echo 1 || echo 0)" >> "$METRICS_FILE"
EOF

    sudo chmod +x /usr/local/bin/hardn-metrics-collector.sh
    
    # Create cron job for metrics collection
    echo "*/1 * * * * root /usr/local/bin/hardn-metrics-collector.sh" | sudo tee /etc/cron.d/hardn-metrics > /dev/null
    
    log_message "Custom HARDN metrics configured"
}

configure_alerting() {
    log_message "Setting up local alerting configuration..."
    
    # Create alert rules for local monitoring
    sudo mkdir -p /etc/hardn/monitoring
    
    sudo tee /etc/hardn/monitoring/alert-rules.yml > /dev/null <<'EOF'
groups:
  - name: hardn-security
    rules:
      - alert: HARDNComplianceFailure
        expr: hardn_compliance_status == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "HARDN compliance check failed"
          description: "Node {{ $labels.instance }} is not HARDN compliant"
      
      - alert: HARDNServiceDown
        expr: up{job="hardn-node"} == 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "HARDN monitoring endpoint down"
          description: "Cannot scrape metrics from {{ $labels.instance }}"
      
      - alert: SecurityEventSpike
        expr: increase(hardn_security_events_total[5m]) > 10
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High number of security events detected"
          description: "{{ $value }} security events in the last 5 minutes"
EOF

    log_message "Alert rules configured"
}

main() {
    local mode="${1:-central}"
    local central_server="${2:-}"
    local ssh_key_path="${3:-/etc/hardn/monitoring/id_rsa}"
    
    HARDN_STATUS "info" "Starting HARDN monitoring setup (mode: $mode)"
    
    # Skip monitoring setup in chroot
    if check_chroot; then
        return 0
    fi
    
    # Install and configure node exporter
    install_node_exporter
    create_systemd_service
    
    # Configure connectivity based on mode
    case "$mode" in
        "central")
            if [[ -n "$central_server" ]]; then
                configure_ssh_tunnel "$central_server" "$ssh_key_path"
                HARDN_STATUS "pass" "Configured for central monitoring server: $central_server"
            else
                HARDN_STATUS "warning" "Central server not specified, skipping tunnel setup"
            fi
            ;;
        "self-hosted")
            HARDN_STATUS "pass" "Self-hosted mode: Node exporter configured for local Prometheus"
            ;;
        "hybrid")
            HARDN_STATUS "info" "Hybrid mode: Supporting both central and local monitoring"
            if [[ -n "$central_server" ]]; then
                configure_ssh_tunnel "$central_server" "$ssh_key_path"
            fi
            ;;
        *)
            HARDN_STATUS "error" "Unknown monitoring mode: $mode"
            return 1
            ;;
    esac
    
    # Update HARDN config
    mkdir -p "$(dirname "$HARDN_CONFIG")"
    echo "HARDN_MONITORING_ENABLED=true" | sudo tee -a "$HARDN_CONFIG" > /dev/null
    echo "HARDN_MONITORING_MODE=$mode" | sudo tee -a "$HARDN_CONFIG" > /dev/null
    
    HARDN_STATUS "pass" "HARDN monitoring setup completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

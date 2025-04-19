#!/bin/bash

# Variables\\\\ test
SERVICE_FILE="/etc/systemd/system/hardn.service"
INSTALL_DIR="/opt/hardn"

# Create systemd service file////// test
echo "Setting up systemd service..."
cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=HARDN Endpoint Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/main.py
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and enable the service/// test
systemctl daemon-reload
systemctl enable hardn.service
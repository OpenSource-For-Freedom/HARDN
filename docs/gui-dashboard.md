# HARDN-XDR GUI Dashboard

The HARDN-XDR GUI Dashboard provides a native GTK interface for monitoring and managing your system's security posture.

## Features

### Real-time Monitoring
- **System Metrics**: Live graphs showing CPU, memory, disk, and network usage
- **Security Services**: Status monitoring for UFW, Fail2Ban, AppArmor, ClamAV, SSH, and more
- **Kernel Parameters**: Display of critical security-related sysctl values
- **System Information**: Hostname, uptime, and load average

### Security Management
- **Service Control**: Enable/disable security services with graphical buttons
- **Live Logs**: Real-time viewing of authentication and security logs
- **Status Dashboard**: Comprehensive overview of system hardening status

### Design
- **Debian Color Scheme**: Uses slate grey, black, and red colors matching Debian environment
- **Professional Interface**: Clean, organized layout with grouped functionality
- **Dark Theme**: Easy on the eyes for extended monitoring sessions

## Installation

The GUI dashboard requires additional Python packages:

```bash
sudo apt install python3-gi python3-gi-cairo python3-matplotlib python3-psutil python3-requests gir1.2-gtk-3.0
```

These dependencies are automatically included when installing HARDN-XDR via the standard installation method.

## Usage

### Command Line Launch

```bash
# Basic launch
hardn dashboard

# Launch with full privileges (recommended)
sudo hardn dashboard

# Direct execution
hardn-dashboard
```

### GUI Features

#### Left Panel
- **Security Services**: List of security services with their current status
- **Security Controls**: Enable/disable buttons for each security service
- **Kernel Parameters**: Display of security-related sysctl values

#### Right Panel
- **System Metrics**: Four real-time graphs showing:
  - CPU Usage (%)
  - Memory Usage (%)
  - Disk Usage (%)
  - Network I/O Rate
- **Security Logs**: Real-time log viewer with color-coded entries

#### Header
- **System Information**: Current hostname, uptime, and load average
- **Status Bar**: Operation feedback and current status

### Service Controls

The dashboard provides buttons to control key security services:

- **UFW Firewall**: Enable/disable the Uncomplicated Firewall
- **Fail2Ban**: Control the intrusion prevention system
- **AppArmor**: Manage mandatory access control
- **ClamAV**: Control the antivirus daemon
- **SSH**: Manage SSH server access

**Note**: Service control operations require root privileges. Run the dashboard with `sudo` for full functionality.

## REST API Integration

The dashboard can work in conjunction with the HARDN-XDR REST API for remote monitoring:

```bash
# Start API server in background
hardn api --port 8080 &

# Launch dashboard (will use local system calls by default)
hardn dashboard
```

## Troubleshooting

### Missing Dependencies
If you receive import errors, install the required packages:

```bash
sudo apt update
sudo apt install python3-gi python3-gi-cairo python3-matplotlib python3-psutil python3-requests gir1.2-gtk-3.0
```

### Display Issues
For remote systems or containers:

```bash
# Ensure X11 forwarding is enabled
ssh -X user@hostname

# Or use VNC/remote desktop for full GUI support
```

### Permission Issues
Some features require elevated privileges:

```bash
# Run with sudo for service control
sudo hardn dashboard

# Or add user to required groups (restart required)
sudo usermod -a -G adm,systemd-journal $USER
```

## Architecture

The GUI dashboard integrates with HARDN-XDR's modular architecture:

- **Frontend**: GTK3-based Python application
- **Backend**: Calls existing HARDN-XDR bash modules via subprocess
- **Data Sources**: systemctl, sysctl, log files, psutil
- **Theme**: Custom CSS with Debian-inspired color scheme

## Development

To modify or extend the dashboard:

1. Edit the Python source: `/usr/share/hardn/gui/hardn-dashboard.py`
2. Modify themes in the `apply_theme()` method
3. Add new metrics in the monitoring loop
4. Extend service controls in the button handlers

The code follows Python best practices with proper error handling and threading for responsive UI updates.
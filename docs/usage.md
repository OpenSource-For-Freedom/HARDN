# HARDN-XDR Usage Guide

This guide explains how to use HARDN-XDR for system security hardening and monitoring.

## Basic Usage

### System Hardening

The primary function of HARDN-XDR is to harden your system. Run the setup command to begin:

```bash
# Interactive setup (recommended for first-time users)
sudo hardn setup

# Automated setup (for scripted installations)
sudo hardn setup --non-interactive

# Dry run to see what would be changed without making modifications
sudo hardn setup --dry-run
```

### System Status

Check the current security status of your system:

```bash
# Basic status check
hardn status

# Detailed status with service information
hardn status --verbose

# Check specific components
hardn status --services
hardn status --firewall
hardn status --malware
```

### Security Auditing

Run comprehensive security audits:

```bash
# Complete security audit
hardn audit

# Quick audit (faster, less comprehensive)
hardn audit --quick

# Generate detailed report
hardn audit --report
```

### Service Management

Monitor and control security services:

```bash
# Start monitoring services
hardn monitor start

# Stop monitoring
hardn monitor stop

# Check service status
hardn monitor status

# Restart specific services
hardn monitor restart fail2ban
hardn monitor restart firewall
```

## Advanced Features

### Backup and Restore

Create and manage system configuration backups:

```bash
# Create backup
hardn backup create

# List available backups
hardn backup list

# Restore from backup
hardn backup restore <backup-name>

# Clean old backups
hardn backup clean
```

### Update Management

Keep security definitions up to date:

```bash
# Update security signatures
hardn update

# Update system packages
hardn update --packages

# Check for available updates
hardn update --check
```

### Configuration Management

Manage HARDN-XDR configuration:

```bash
# View current configuration
hardn config show

# Edit configuration
hardn config edit

# Reset to defaults
hardn config reset

# Validate configuration
hardn config validate
```

## GUI Dashboard

Launch the graphical dashboard for visual monitoring:

```bash
# Launch dashboard
hardn dashboard

# Launch with administrative privileges (recommended)
sudo hardn dashboard
```

The dashboard provides:
- Real-time system metrics
- Security service status
- Log monitoring
- Service control buttons
- System information display

## REST API

Start the HTTP API server for remote monitoring:

```bash
# Start API server (default: localhost:8080)
hardn api

# Start on custom port and host
hardn api --port 9090 --host 0.0.0.0

# Start with SSL/TLS
hardn api --ssl --cert /path/to/cert.pem --key /path/to/key.pem
```

### API Endpoints

- `GET /api/status` - System status information
- `GET /api/services` - Security services status  
- `GET /api/metrics` - Live system metrics
- `GET /api/logs` - Security logs
- `POST /api/service` - Control services

## Command Line Options

### Global Options

- `--help` - Show help information
- `--version` - Display version information
- `--config FILE` - Use custom configuration file
- `--verbose` - Enable verbose output
- `--quiet` - Suppress non-essential output
- `--dry-run` - Show what would be done without making changes

### Setup Options

- `--non-interactive` - Run without user prompts
- `--force` - Force installation even if system is already hardened
- `--skip-packages` - Skip package installation
- `--skip-config` - Skip configuration changes

### Monitoring Options

- `--interval SECONDS` - Set monitoring interval (default: 30)
- `--log-level LEVEL` - Set logging level (debug, info, warn, error)
- `--output FORMAT` - Output format (text, json, xml)

## Configuration Files

HARDN-XDR uses the following configuration files:

- `/etc/hardn/hardn.conf` - Main configuration file
- `/etc/hardn/services.conf` - Service-specific settings
- `/etc/hardn/monitoring.conf` - Monitoring configuration
- `/var/lib/hardn/state.json` - System state information

## Log Files

Monitor HARDN-XDR activity through log files:

- `/var/log/hardn/hardn.log` - Main application log
- `/var/log/hardn/audit.log` - Security audit log
- `/var/log/hardn/monitor.log` - Service monitoring log
- `/var/log/hardn/api.log` - API access log

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure you're running with sufficient privileges (sudo)
2. **Service Failures**: Check service logs for specific error messages
3. **Network Issues**: Verify firewall rules aren't blocking required connections
4. **Package Conflicts**: Use `--force` option if needed, or resolve conflicts manually

### Getting Help

```bash
# Show general help
hardn --help

# Show command-specific help
hardn setup --help
hardn status --help
hardn audit --help
```

### Debug Mode

Enable debug mode for detailed troubleshooting:

```bash
# Run with debug output
hardn --verbose setup

# Enable debug logging
hardn --log-level debug monitor start
```

For additional support, check the [main documentation](README.md) or contact the development team.
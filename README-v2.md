# HARDN-XDR v2.0.0 - Commercial-Ready Linux Security Hardening

![GitHub release](https://img.shields.io/github/v/release/OpenSource-For-Freedom/HARDN?include_prereleases)
![Debian 12+](https://img.shields.io/badge/OS-Debian%2012%2B-red?style=for-the-badge&labelColor=grey)
![Ubuntu 24.04+](https://img.shields.io/badge/OS-Ubuntu%2024.04%2B-orange?style=for-the-badge&labelColor=grey)

<p align="center">
  <img src="docs/assets/HARDN(1).png" alt="HARDN Logo" width="300px" />
</p>

## 🚀 What's New in v2.0.0

HARDN-XDR has been completely refactored into a **commercial-ready Debian application** with:

- ✅ **Modular Architecture** - Clean separation of concerns with dedicated modules
- ✅ **Professional CLI** - Full-featured command-line interface with proper argument parsing
- ✅ **Debian Packaging** - Native `.deb` package with proper dependencies and post-install scripts
- ✅ **FHS Compliance** - Follows Filesystem Hierarchy Standard and LSB guidelines
- ✅ **Systemd Integration** - Native service files with security restrictions
- ✅ **Comprehensive Logging** - Structured logging with multiple levels and file rotation
- ✅ **Backup/Restore** - Automated configuration backup and restore functionality
- ✅ **CI/CD Pipeline** - Automated testing, building, and packaging with GitHub Actions
- ✅ **Security Hardening** - Enhanced STIG compliance implementation targeting 99% Lynis score

## 📋 Overview

HARDN-XDR is a comprehensive security hardening solution designed to transform Debian-based systems into highly secure **"Golden Image"** configurations. It implements multiple layers of defense following industry best practices and government security standards.

### 🎯 Key Features

- **STIG Compliance** - Security Technical Implementation Guide standards
- **Multi-Layer Defense** - Comprehensive security controls across all system layers
- **Automated Hardening** - One-command system transformation
- **Continuous Monitoring** - Real-time security monitoring and alerting
- **Compliance Auditing** - Automated security assessments with detailed reporting
- **Air-Gap Ready** - Designed for offline and air-gapped environments

### 🛡️ Security Components

| Component | Tools | Purpose |
|-----------|-------|---------|
| **Intrusion Detection** | Suricata, Fail2Ban | Network and host-based intrusion detection/prevention |
| **Malware Protection** | ClamAV, YARA | Real-time malware scanning and detection |
| **System Integrity** | AIDE, debsums | File integrity monitoring and verification |
| **Rootkit Detection** | rkhunter, chkrootkit, unhide | Advanced rootkit and steganography detection |
| **Audit Framework** | auditd | Comprehensive system call and file access monitoring |
| **Access Control** | AppArmor, Firejail | Mandatory access control and application sandboxing |
| **Network Security** | UFW, secure DNS | Firewall management and secure networking |
| **System Hardening** | Kernel parameters, sysctl | Low-level system security configuration |

## 🚀 Quick Start

### Installation via Package Manager (Recommended)

```bash
# Download and install the latest release
curl -LO https://github.com/OpenSource-For-Freedom/HARDN/releases/latest/download/hardn-xdr_2.0.0-1_all.deb
sudo dpkg -i hardn-xdr_2.0.0-1_all.deb
sudo apt-get install -f  # Fix any dependency issues
```

### Installation via Script

```bash
# One-command installation
curl -LO https://raw.githubusercontent.com/OpenSource-For-Freedom/HARDN/main/install.sh
sudo chmod +x install.sh
sudo ./install.sh
```

### Build from Source

```bash
# Clone and build
git clone https://github.com/OpenSource-For-Freedom/HARDN.git
cd HARDN
sudo apt-get install -y debhelper-compat devscripts build-essential
dpkg-buildpackage -us -uc -b
sudo dpkg -i ../hardn-xdr_*.deb
```

## 📖 Usage

### Basic Commands

```bash
# Show help and available commands
hardn --help

# Check system status
hardn status

# Perform complete system hardening (interactive)
sudo hardn setup

# Automated hardening for scripts/CI
sudo hardn setup --non-interactive

# Run security audit
sudo hardn audit

# Create system backup
sudo hardn backup

# Monitor service management
sudo hardn monitor start
```

### Advanced Usage

```bash
# Dry-run mode (show what would be done)
sudo hardn setup --dry-run

# Use custom configuration
sudo hardn setup --config /path/to/custom.conf

# Force operations without prompts
sudo hardn setup --force --non-interactive

# Set custom log level
sudo hardn audit --log-level debug

# Run specific audit types
sudo hardn audit lynis
sudo hardn audit network
sudo hardn audit malware
```

## 🏗️ Architecture

HARDN-XDR v2.0.0 features a completely modular architecture:

```
/usr/bin/hardn                     # Main CLI executable
/usr/share/hardn/
├── modules/
│   ├── logging.sh                 # Centralized logging framework
│   ├── utils.sh                   # Common utilities and helpers
│   ├── hardening.sh               # Core system hardening
│   ├── audit.sh                   # Security auditing and scanning
│   ├── status.sh                  # System status and monitoring
│   ├── backup.sh                  # Backup and restore functionality
│   ├── monitor.sh                 # Service monitoring and management
│   ├── update.sh                  # Security updates and maintenance
│   └── uninstall.sh               # Clean removal and restoration
└── templates/
    └── hardn.conf                 # Default configuration template

/etc/hardn/
└── hardn.conf                     # System configuration

/var/log/hardn/                    # Application logs
/var/lib/hardn/                    # Application data and backups
```

### Module Overview

| Module | Responsibility |
|--------|---------------|
| **logging.sh** | Structured logging, color output, log levels, file rotation |
| **utils.sh** | Common functions, dry-run support, privilege checking |
| **hardening.sh** | Core security hardening, STIG implementation |
| **audit.sh** | Security scanning, compliance checking, report generation |
| **status.sh** | System status, service monitoring, performance metrics |
| **backup.sh** | Configuration backup, restore, cleanup |
| **monitor.sh** | Service management, real-time monitoring |
| **update.sh** | Security updates, signature updates, maintenance |
| **uninstall.sh** | Clean removal, system restoration |

## 🔧 Configuration

### Main Configuration File

Edit `/etc/hardn/hardn.conf` to customize behavior:

```bash
# Logging Configuration
LOG_LEVEL="info"                    # debug, info, warn, error
LOG_RETENTION_DAYS="30"
MAX_LOG_SIZE="100M"

# Security Settings
ENABLE_KERNEL_HARDENING="true"
ENABLE_NETWORK_HARDENING="true"
ENABLE_AUDIT_SYSTEM="true"
ENABLE_INTRUSION_DETECTION="true"
ENABLE_MALWARE_PROTECTION="true"

# DNS Settings
USE_SECURE_DNS="true"
PRIMARY_DNS="9.9.9.9"             # Quad9
SECONDARY_DNS="1.1.1.1"           # Cloudflare

# Compliance Settings
ENFORCE_STIG_COMPLIANCE="true"
MINIMUM_HARDENING_SCORE="90"
```

### Environment Variables

For testing and development:

```bash
export HARDN_CONFIG_DIR="/custom/config/path"
export HARDN_LOG_DIR="/custom/log/path"
export LOG_LEVEL="debug"
export DRY_RUN="true"
```

## 📊 Security Compliance

HARDN-XDR targets the highest security standards:

| Standard | Target | Features |
|----------|--------|----------|
| **STIG Compliance** | 95%+ | DOD Security Technical Implementation Guide |
| **Lynis Score** | 99% | System hardening index |
| **CIS Controls** | Level 2 | Center for Internet Security benchmarks |

### Compliance Features

- ✅ Kernel parameter hardening (50+ security settings)
- ✅ Network security configuration
- ✅ File system security and encryption readiness
- ✅ User account and authentication hardening
- ✅ System service minimization
- ✅ Audit trail configuration
- ✅ Intrusion detection and prevention
- ✅ Malware protection and scanning
- ✅ System integrity monitoring

## 🔄 Development & CI/CD

### GitHub Actions Workflow

The project includes comprehensive CI/CD automation:

```yaml
- Lint: shellcheck validation
- Build: Debian package creation
- Test: Multi-distribution testing (Debian 12, Ubuntu 24.04)
- Security: Trivy vulnerability scanning
- Release: Automated package releases
```

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Test your changes: `./test-cli.sh`
4. Build and test package: `dpkg-buildpackage -us -uc -b`
5. Commit changes: `git commit -m 'Add amazing feature'`
6. Push to branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

### Development Setup

```bash
# Clone repository
git clone https://github.com/OpenSource-For-Freedom/HARDN.git
cd HARDN

# Install development dependencies
sudo apt-get install -y shellcheck debhelper-compat devscripts build-essential

# Test CLI without installation
./test-cli.sh

# Build package
dpkg-buildpackage -us -uc -b

# Test package
sudo dpkg -i ../hardn-xdr_*.deb
```

## 📋 System Requirements

### Minimum Requirements

- **OS**: Debian 12+ or Ubuntu 24.04+
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 10GB free space for security tools and logs
- **Network**: Internet access for initial setup (can run offline afterward)

### Recommended Requirements

- **OS**: Fresh Debian 12 or Ubuntu 24.04 installation
- **RAM**: 8GB for optimal performance
- **Storage**: 20GB+ for comprehensive logging and backups
- **CPU**: 2+ cores for parallel security scanning

## 🔒 Security Considerations

### Before Installation

- ⚠️ **Test in non-production environment first**
- ⚠️ **Create full system backup**
- ⚠️ **Review security policies and compliance requirements**
- ⚠️ **Ensure administrative access availability**

### After Installation

- 🔍 **Review audit logs regularly**
- 🔄 **Keep security signatures updated**
- 📊 **Monitor compliance scores**
- 🔧 **Adjust configuration as needed**

## 📄 Documentation

- [Installation Guide](docs/INSTALLATION.md)
- [Configuration Reference](docs/CONFIGURATION.md)
- [Security Features](docs/hardn-security-tools.md)
- [STIG Compliance](docs/deb_stig.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [API Reference](docs/API.md)

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/OpenSource-For-Freedom/HARDN/issues)
- **Documentation**: [Project Wiki](https://github.com/OpenSource-For-Freedom/HARDN/wiki)
- **Email**: office@cybersynapse.ro

## 🤝 Partners

<p align="center">
  <img src="docs/assets/cybersynapse.png" alt="CyberSynapse Logo" width="200px" />
</p>

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Security Community** - For continuous feedback and contributions
- **Debian Project** - For providing an excellent foundation
- **Security Tool Authors** - For creating the tools that make this possible

---

<p align="center">
  <strong>🔒 Making Linux Security Accessible to Everyone 🔒</strong>
</p>
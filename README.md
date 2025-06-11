


# HARDN-XDR

[![Auto Update Dependencies](https://github.com/OpenSource-For-Freedom/HARDN-XDR/actions/workflows/validate.yml/badge.svg)](https://github.com/OpenSource-For-Freedom/HARDN-XDR/actions/workflows/validate.yml)

<p align="center">
  <img src="docs/assets/HARDN(1).png" alt="HARDN Logo" width="200px" />
</p>

**A Linux Security Project for Debian Systems**


## Overview

HARDN-XDR is a robust endpoint security and hardening solution for Debian-based systems that provides:

- **System Hardening**: Comprehensive security hardening following STIG compliance guidelines
- **Endpoint Management**: Advanced monitoring, securing, and maintenance of network devices
- **STIG Compliance**: Alignment with [Security Technical Information Guides](https://public.cyber.mil/stigs/) from the [DOD Cyber Exchange](https://public.cyber.mil/)
- **Automated Security**: Real-time threat detection and response capabilities

## Features

- **Comprehensive Monitoring**: Real-time insights into endpoint performance and security status
- **Enhanced Security**: Advanced security protocols and hardening measures
- **Scalability**: Supports small to large-scale network deployments  
- **STIG Compliance**: Government-grade security for Debian-based information systems
- **Modular Architecture**: Professional CLI interface with specialized security modules


## Installation

### Quick Start

```bash
curl -LO https://raw.githubusercontent.com/opensource-for-freedom/HARDN-XDR/refs/heads/main/install.sh && sudo chmod +x install.sh && sudo ./install.sh
```

### Requirements

- **Debian 12** or **Ubuntu 24.04** (bare-metal or virtual machines)
- Root or sudo access for installation
- Internet connection for package downloads

### What Gets Installed

- Security-focused package collection
- System hardening and STIG compliance settings  
- Malware detection and signature-based response system
- Comprehensive monitoring and reporting tools

For detailed information, see [HARDN.md](docs/HARDN.md) and [deb_stig.md](docs/deb_stig.md).

## Architecture

HARDN-XDR v2.0.0 follows a modular architecture with proper Linux filesystem hierarchy compliance:

### Installation Structure
```
/usr/bin/hardn                    # Main executable
/usr/share/hardn/modules/         # Security modules
/usr/share/hardn/templates/       # Configuration templates  
/usr/share/man/man1/hardn.1       # Manual page
/etc/hardn/hardn.conf             # System configuration
/var/log/hardn/                   # Application logs
/var/lib/hardn/                   # Application data
/lib/systemd/system/             
```

### Core Modules
- **logging.sh** - Centralized logging with rotation
- **utils.sh** - Common utilities and system checks
- **hardening.sh** - Core security hardening and STIG implementation
- **audit.sh** - Security scanning and compliance checking
- **status.sh** - System monitoring and performance metrics
- **backup.sh** - Configuration backup and restore
- **monitor.sh** - Service management and real-time monitoring
- **update.sh** - Security updates and signature maintenance
- **uninstall.sh** - Clean removal and system restoration

### Source Repository Structure
```
HARDN-XDR/
├── docs/                        
│   ├── assets/                  
│   ├── CODE_OF_CONDUCT.md       
│   ├── HARDN.md                  
│   ├── deb_stig.md               
│   └── refactoring-summary.md    
├── debian/                       
├── src/                         
├── systemd/                     
├── usr/                          
├── install.sh                   
└── README.md                    
```

## License

This project is licensed under the MIT License.

## Contact

For questions or support, contact: office@cybersynapse.ro

## Project Partners

<p align="center">
  <img src="docs/assets/cybersynapse.png" alt="CyberSynapse Logo" />
</p>

# Changelog

All notable changes to HARDN-XDR are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-06-11

### Added
- Complete modular architecture with 10 specialized security modules
- Native Debian package (.deb) with proper dependency management
- Professional CLI interface with full argument parsing
- Comprehensive logging framework with file rotation
- Systemd service integration with security restrictions
- FHS-compliant directory structure
- Automated backup and restore functionality
- CI/CD pipeline with GitHub Actions
- Enhanced STIG compliance implementation
- Manual page documentation

### Changed
- Refactored from monolithic 2,300+ line script to modular architecture
- Migrated to FHS-compliant filesystem layout
- Improved error handling and status reporting
- Enhanced user interface with better feedback systems
- Standardized configuration management

### Security
- Implemented comprehensive STIG controls
- Enhanced audit trail capabilities
- Improved security hardening measures
- Added principle of least privilege throughout
- Strengthened system integrity monitoring

## [1.1.8] - Previous Release

### Added
- Enhanced system monitoring capabilities
- Improved performance optimization

### Fixed
- Resolved minor bugs from version 1.1.6

## [1.1.6] - Previous Release

### Added
- Internet connectivity verification
- Linux Malware Detect (maldet) integration
- Audit rules for critical system files

### Improved
- File permissions for critical system files
- System security configuration
- **Service Management**: Enhanced error handling and ensured `Fail2Ban`, `AppArmor`, and `auditd` are enabled and running at boot.
- **SSH Hardening**: Enforced stricter SSH settings for improved security.
- **Kernel Randomization**: Ensured kernel randomization is applied persistently and at runtime.

### Fixed
- **Error Handling**: Improved error handling for services like `Fail2Ban`, `AppArmor`, and `auditd` to prevent setup failures.


---

## Version 1.1.5

### Added
- **Debian Packaging**: Added support for building Debian packages for HARDN.
- **Error Handling**: Enhanced error handling in scripts to prevent disruptions to user logins or system functionality.

### Improved
- **Script Optimization**: Removed redundant steps and consolidated repetitive code blocks in setup scripts.
- **Documentation**: Updated documentation to reflect the latest changes and features.

### Fixed
- **Cron Jobs**: Ensured cron jobs are non-intrusive and do not disrupt user workflows.
- **GRUB BUG**: removed dependant file due to PAM collision and Kernal alerting flaw. 
- **AIDE Initialization**: Improved AIDE initialization process for better reliability.


---

*Note*: For detailed CLI usage instructions, refer to the [documentation](https://github.com/OpenSource-For-Freedom/HARDN/tree/main/docs).

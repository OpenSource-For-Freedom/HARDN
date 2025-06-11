#!/bin/bash

# HARDN-XDR Lynis Remediation Report Generator
# Generates comprehensive reports with necessary fixes to achieve 90%+ Lynis compliance
# Supports both Desktop and Virtual environments

set -e

# Configuration
REPORT_DIR="${REPORT_DIR:-/var/log/hardn-reports}"
LYNIS_REPORT="${LYNIS_REPORT:-/var/log/lynis/hardn-report.dat}"
LYNIS_LOG="${LYNIS_LOG:-/var/log/lynis/hardn-audit.log}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REMEDIATION_REPORT="$REPORT_DIR/remediation_report_$TIMESTAMP.md"
ISSUE_EXPORT="$REPORT_DIR/github_issue_$TIMESTAMP.json"
SCORE_EXPORT="$REPORT_DIR/lynis-score.txt"
SCORE_JSON_EXPORT="$REPORT_DIR/lynis-score.json"

# Status function
HARDN_STATUS() {
    local status="$1"
    local message="$2"
    case "$status" in
        "pass")
            echo -e "\033[1;32m[PASS]\033[0m $message"
            ;;
        "warning")
            echo -e "\033[1;33m[WARNING]\033[0m $message"
            ;;
        "error")
            echo -e "\033[1;31m[ERROR]\033[0m $message"
            ;;
        "info")
            echo -e "\033[1;34m[INFO]\033[0m $message"
            ;;
        *)
            echo -e "\033[1;37m[UNKNOWN]\033[0m $message"
            ;;
    esac
}

# Detect environment type
detect_environment() {
    local env_type="Unknown"
    
    # Check for virtual environment indicators
    if [ -f /sys/class/dmi/id/product_name ]; then
        local product_name
        product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
        case "$product_name" in
            *VirtualBox*|*VMware*|*QEMU*|*KVM*|*Hyper-V*)
                env_type="Virtual Machine"
                ;;
            *Docker*|*Container*)
                env_type="Container"
                ;;
            *)
                env_type="Physical/Desktop"
                ;;
        esac
    fi
    
    # Additional virtual environment checks
    if [ "$env_type" = "Unknown" ]; then
        if [ -f /proc/1/cgroup ] && grep -q docker /proc/1/cgroup; then
            env_type="Container"
        elif [ -d /proc/vz ] || [ -f /proc/user_beancounters ]; then
            env_type="Virtual Machine (OpenVZ)"
        elif dmesg 2>/dev/null | grep -qi "hypervisor detected\|paravirtualized kernel"; then
            env_type="Virtual Machine"
        else
            env_type="Physical/Desktop"
        fi
    fi
    
    echo "$env_type"
}

# Parse Lynis report and extract current score
get_lynis_score() {
    local score=0
    if [ -f "$LYNIS_REPORT" ]; then
        score=$(grep "hardening_index=" "$LYNIS_REPORT" 2>/dev/null | cut -d'=' -f2 | tr -d ' %' 2>/dev/null || echo "0")
        # Validate that score is numeric
        if ! [[ "$score" =~ ^[0-9]+$ ]] 2>/dev/null; then
            score="0"
        fi
        echo "$score"
    else
        echo "0"
    fi
}

# Extract Lynis suggestions and categorize them
extract_suggestions() {
    local report_file="$1"
    local category="$2"
    
    if [ -f "$report_file" ]; then
        case "$category" in
            "critical")
                grep "suggestion\[\]" "$report_file" 2>/dev/null | grep -E "(ROOT|PRIV|AUTH|PASS|CRYPT)" 2>/dev/null | head -10 || true
                ;;
            "security")
                grep "suggestion\[\]" "$report_file" 2>/dev/null | grep -E "(SSH|FIRE|AUDIT|LOG)" 2>/dev/null | head -10 || true
                ;;
            "system")
                grep "suggestion\[\]" "$report_file" 2>/dev/null | grep -E "(KERN|BOOT|PROC|FILE)" 2>/dev/null | head -10 || true
                ;;
            "network")
                grep "suggestion\[\]" "$report_file" 2>/dev/null | grep -E "(NET|PORT|SERV)" 2>/dev/null | head -10 || true
                ;;
            "all")
                grep "suggestion\[\]" "$report_file" 2>/dev/null || true
                ;;
        esac
    fi
}

# Generate environment-specific recommendations
generate_env_recommendations() {
    local env_type="$1"
    local current_score="$2"
    
    cat << EOF

## Environment-Specific Recommendations

**Detected Environment**: $env_type

EOF

    case "$env_type" in
        "Container")
            cat << EOF
### Container Environment Optimizations

Since you're running in a container environment, some recommendations may not apply:

- **Skip kernel parameter changes**: Container cannot modify host kernel
- **Focus on application security**: Prioritize service configuration
- **Network security**: Use container networking features
- **File permissions**: Ensure proper ownership within container

**Container-Specific Actions**:
- Configure proper resource limits
- Use non-root user where possible
- Implement proper secrets management
- Ensure minimal base image usage

EOF
            ;;
        "Virtual Machine"*)
            cat << EOF
### Virtual Machine Environment Optimizations

Virtual machine specific recommendations:

- **Kernel hardening**: Full kernel parameter tuning available
- **Hypervisor security**: Ensure guest additions are updated
- **Resource allocation**: Optimize based on VM resources
- **Network isolation**: Configure proper network segments

**VM-Specific Actions**:
- Enable hypervisor security features
- Configure VM-specific firewall rules
- Implement proper snapshot security
- Monitor hypervisor logs

EOF
            ;;
        "Physical/Desktop")
            cat << EOF
### Physical/Desktop Environment Optimizations

Physical system specific recommendations:

- **Hardware security**: Enable secure boot, TPM if available
- **Desktop environment**: Configure screen lock and session management
- **USB security**: Implement USB device restrictions
- **Physical access**: Configure BIOS/UEFI security

**Desktop-Specific Actions**:
- Configure automatic screen lock
- Implement USB device whitelisting
- Enable disk encryption
- Configure power management security

EOF
            ;;
    esac
}

# Generate priority-based remediation steps
generate_remediation_steps() {
    local current_score="$1"
    local target_score="90"
    local score_gap=$((target_score - current_score))
    
    cat << EOF

## Prioritized Remediation Steps

**Current Score**: $current_score%  
**Target Score**: $target_score%  
**Score Gap**: $score_gap points

### Priority 1: Critical Security Issues (Impact: 15-25 points)

EOF

    # Extract and format critical suggestions
    extract_suggestions "$LYNIS_REPORT" "critical" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            suggestion=$(echo "$line" | sed 's/suggestion\[\]=//' | sed 's/|/ - /' 2>/dev/null || echo "$line")
            echo "- $suggestion"
        fi
    done 2>/dev/null || echo "- No critical suggestions found"

    cat << EOF

### Priority 2: Authentication & Access Control (Impact: 10-15 points)

- Configure stronger password policies
- Implement account lockout mechanisms
- Review and restrict sudo access
- Enable two-factor authentication where possible
- Configure proper SSH key management

### Priority 3: System Hardening (Impact: 5-10 points)

EOF

    # Extract and format system suggestions
    extract_suggestions "$LYNIS_REPORT" "system" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            suggestion=$(echo "$line" | sed 's/suggestion\[\]=//' | sed 's/|/ - /' 2>/dev/null || echo "$line")
            echo "- $suggestion"
        fi
    done 2>/dev/null || echo "- No system suggestions found"

    cat << EOF

### Priority 4: Network Security (Impact: 5-10 points)

EOF

    # Extract and format network suggestions
    extract_suggestions "$LYNIS_REPORT" "network" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            suggestion=$(echo "$line" | sed 's/suggestion\[\]=//' | sed 's/|/ - /' 2>/dev/null || echo "$line")
            echo "- $suggestion"
        fi
    done 2>/dev/null || echo "- No network suggestions found"
}

# Generate detailed command examples
generate_command_examples() {
    cat << EOF

## Implementation Commands

### Quick Wins (Easy to implement)

\`\`\`bash
# Set proper file permissions
find /etc -type f -name "*.conf" -exec chmod 644 {} \;
find /etc -type d -exec chmod 755 {} \;

# Secure log files
find /var/log -type f -exec chmod 640 {} \;
chown root:adm /var/log/*.log

# Remove unnecessary packages
apt autoremove -y
apt autoclean

# Update package database
apt update && apt list --upgradable
\`\`\`

### SSH Hardening

\`\`\`bash
# Backup SSH config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Apply secure SSH settings
echo "PermitRootLogin no" >> /etc/ssh/sshd_config
echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config

# Restart SSH service
systemctl restart ssh
\`\`\`

### Kernel Security

\`\`\`bash
# Apply kernel hardening
cat >> /etc/sysctl.d/99-security.conf << 'EOL'
net.ipv4.ip_forward=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
kernel.dmesg_restrict=1
kernel.kptr_restrict=2
EOL

# Apply settings (run as root)
sysctl -p /etc/sysctl.d/99-security.conf
\`\`\`

EOF
}

# Create comprehensive remediation report
create_remediation_report() {
    local current_score="$1"
    local environment="$2"
    local status="$3"
    
    # Create report directory
    mkdir -p "$REPORT_DIR"
    
    # Generate main report
    cat > "$REMEDIATION_REPORT" << EOF
# HARDN-XDR Lynis Remediation Report

**Generated**: $(date)  
**HARDN Version**: 2.0.0  
**Current Lynis Score**: $current_score%  
**Status**: $status

---

EOF

    # Add environment-specific recommendations
    {
        generate_env_recommendations "$environment" "$current_score"
        generate_remediation_steps "$current_score"
        generate_command_examples
    } >> "$REMEDIATION_REPORT"
    
    # Add raw Lynis data section
    cat >> "$REMEDIATION_REPORT" << EOF

---

## Raw Lynis Analysis

### All Suggestions
\`\`\`
EOF
    
    if [ -f "$LYNIS_REPORT" ]; then
        extract_suggestions "$LYNIS_REPORT" "all" | sed 's/suggestion\[\]=//' 2>/dev/null >> "$REMEDIATION_REPORT" || echo "No suggestions available" >> "$REMEDIATION_REPORT"
    else
        echo "Lynis report not available" >> "$REMEDIATION_REPORT"
    fi
    
    cat >> "$REMEDIATION_REPORT" << EOF
\`\`\`

### Lynis Warnings
\`\`\`
EOF
    
    if [ -f "$LYNIS_REPORT" ]; then
        grep "warning\[\]" "$LYNIS_REPORT" 2>/dev/null | sed 's/warning\[\]=//' >> "$REMEDIATION_REPORT" || echo "No warnings available" >> "$REMEDIATION_REPORT"
    else  
        echo "Lynis report not available" >> "$REMEDIATION_REPORT"
    fi
    
    echo '```' >> "$REMEDIATION_REPORT"
}

# Create GitHub issue export
create_github_issue() {
    local current_score="$1"
    local environment="$2"
    local status="$3"
    
    local title
    if [ "$status" = "PASS" ]; then
        title="OK Lynis Compliance Achieved - Score: ${current_score}%"
    else
        title="WARNING Lynis Remediation Required - Score: ${current_score}%"
    fi
    
    # Create simplified issue content
    local issue_body
    issue_body=$(cat << EOF
## HARDN-XDR Compliance Report

**Environment**: $environment  
**Current Score**: $current_score%  
**Target Score**: 90%  
**Status**: $status

### Summary
$(if [ "$status" = "PASS" ]; then
    echo "Congratulations! HARDN-XDR has successfully achieved Lynis compliance."
else
    echo "Additional remediation steps are required to achieve 90% Lynis compliance."
fi)

### Next Steps
$(if [ "$status" = "PASS" ]; then
    echo "- Monitor compliance with regular Lynis audits"
    echo "- Maintain current security configurations"
    echo "- Review the detailed report for optimization opportunities"
else
    echo "- Review the detailed remediation report at: $REMEDIATION_REPORT"
    echo "- Implement Priority 1 recommendations first"
    echo "- Re-run Lynis audit after each major change"
    echo "- Focus on environment-specific optimizations"
fi)

### Files Generated
- **Detailed Report**: \`$REMEDIATION_REPORT\`
- **Issue Export**: \`$ISSUE_EXPORT\`
- **Lynis Report**: \`$LYNIS_REPORT\`

---
*Generated by HARDN-XDR Remediation Report Generator*
EOF
)

    # Create JSON export for GitHub issue
    {
        # Use safer method to create JSON
        local escaped_body
        escaped_body=$(echo "$issue_body" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g' 2>/dev/null || echo "Error processing issue body")
        cat << EOF
{
  "title": "$title",
  "body": "$escaped_body",
  "labels": [
    "compliance",
    "lynis",
    "security",
    $(if [ "$status" = "PASS" ]; then echo '"success"'; else echo '"remediation"'; fi),
    "$(echo "$environment" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
  ],
  "assignees": ["copilot"],
  "milestone": null,
  "metadata": {
    "hardn_version": "2.0.0",
    "lynis_score": $current_score,
    "environment": "$environment",
    "timestamp": "$(date -Iseconds 2>/dev/null || date)",
    "report_file": "$REMEDIATION_REPORT"
  }
}
EOF
    } > "$ISSUE_EXPORT" 2>/dev/null || {
        # Fallback if JSON generation fails
        echo "{\"error\": \"Failed to generate issue export\", \"lynis_score\": $current_score}" > "$ISSUE_EXPORT"
    }
}

# Export Lynis score as standalone artifacts for GitHub Actions
export_lynis_score_artifacts() {
    local current_score="$1"
    local environment="$2"
    local status="$3"
    
    # Create report directory if it doesn't exist
    mkdir -p "$REPORT_DIR"
    
    # Export simple text file with just the score
    echo "$current_score" > "$SCORE_EXPORT"
    HARDN_STATUS "info" "Exported Lynis score to: $SCORE_EXPORT"
    
    # Export JSON format with additional metadata
    {
        cat << EOF
{
  "lynis_score": $current_score,
  "status": "$status",
  "environment": "$environment",
  "compliance_threshold": 90,
  "compliance_met": $([ "$current_score" -ge 90 ] && echo "true" || echo "false"),
  "timestamp": "$(date -Iseconds 2>/dev/null || date)",
  "hardn_version": "2.0.0"
}
EOF
    } > "$SCORE_JSON_EXPORT" 2>/dev/null || {
        # Fallback if JSON generation fails
        echo "{\"lynis_score\": $current_score, \"status\": \"$status\", \"error\": \"JSON generation failed\"}" > "$SCORE_JSON_EXPORT"
    }
    HARDN_STATUS "info" "Exported Lynis score JSON to: $SCORE_JSON_EXPORT"
}

# Main function
main() {
    HARDN_STATUS "info" "Starting HARDN-XDR Remediation Report Generation..."
    
    # Detect environment
    local environment
    environment=$(detect_environment)
    HARDN_STATUS "info" "Detected environment: $environment"
    
    # Get current Lynis score
    local current_score
    current_score=$(get_lynis_score)
    HARDN_STATUS "info" "Current Lynis score: $current_score%"
    
    # Determine status
    local status
    if [ "$current_score" -ge 90 ]; then
        status="PASS"
        HARDN_STATUS "pass" "Lynis compliance achieved!"
    else
        status="REMEDIATION_REQUIRED"
        HARDN_STATUS "warning" "Remediation required to reach 90% threshold"
    fi
    
    # Create reports
    HARDN_STATUS "info" "Generating comprehensive remediation report..."
    create_remediation_report "$current_score" "$environment" "$status"
    
    HARDN_STATUS "info" "Creating GitHub issue export..."
    create_github_issue "$current_score" "$environment" "$status"
    
    HARDN_STATUS "info" "Exporting Lynis score artifacts..."
    export_lynis_score_artifacts "$current_score" "$environment" "$status"
    
    # Summary
    echo ""
    HARDN_STATUS "pass" "Remediation report generation complete!"
    echo "Reports generated:"
    echo "   • Detailed Report: $REMEDIATION_REPORT"
    echo "   • GitHub Issue: $ISSUE_EXPORT"
    echo "   • Score Artifact: $SCORE_EXPORT"
    echo "   • Score JSON: $SCORE_JSON_EXPORT"
    echo "   • Environment: $environment"
    echo "   • Score: $current_score%"
    echo "   • Status: $status"
    
    return 0
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
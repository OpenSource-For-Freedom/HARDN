#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: yara.sh  
# Purpose: Install and configure YARA malware detection engine
# Location: /src/tools/yara.sh

check_root
log_tool_execution "yara.sh"

setup_yara() {
    HARDN_STATUS "info" "Setting up YARA malware detection engine..."

    # Install YARA if not present
    if ! is_package_installed yara; then
        HARDN_STATUS "info" "Installing YARA package..."
        if install_package yara; then
            HARDN_STATUS "pass" "YARA installed successfully"
        else
            HARDN_STATUS "error" "Failed to install YARA package"
            exit 1
        fi
    else
        HARDN_STATUS "pass" "YARA package already installed"
    fi

    # Check if YARA command exists
    if command_exists yara; then
        HARDN_STATUS "pass" "YARA command found"
        HARDN_STATUS "info" "Creating YARA rules directory..."
        mkdir -p /etc/yara/rules
        chmod 755 /etc/yara/rules
        
        # Install git if needed for rule downloads
        if ! command_exists git; then
            HARDN_STATUS "info" "Installing git for rule downloads..."
            if install_package git; then
                HARDN_STATUS "pass" "Git installed successfully"
            else
                HARDN_STATUS "error" "Failed to install git. Cannot download YARA rules"
                exit 1
            fi
        else
            HARDN_STATUS "pass" "Git command found"
        fi

        local rules_repo_url="https://github.com/Yara-Rules/rules.git"
        local temp_dir
        temp_dir=$(mktemp -d -t yara-rules-XXXXXXXX)

    if [[ ! -d "$temp_dir" ]]; then
        HARDN_STATUS "error" "Failed to create temporary directory for YARA rules"
        exit 1
    fi

    HARDN_STATUS "info" "Cloning YARA rules from repository..."
    if git clone --depth 1 "$rules_repo_url" "$temp_dir"; then
        HARDN_STATUS "pass" "YARA rules cloned successfully"

        HARDN_STATUS "info" "Copying .yar rules to /etc/yara/rules/..."
        local copied_count=0
        # Find all .yar files in the cloned repo and copy them
        while IFS= read -r -d $'\0' yar_file; do
            if cp "$yar_file" /etc/yara/rules/; then
                ((copied_count++))
            else
                HARDN_STATUS "warning" "Failed to copy rule file: $yar_file"
            fi
        done < <(find "$temp_dir" -name "*.yar" -print0)

        if [[ "$copied_count" -gt 0 ]]; then
            HARDN_STATUS "pass" "Copied $copied_count YARA rule files to /etc/yara/rules/"
        else
            HARDN_STATUS "warning" "No .yar files found or copied from the repository"
        fi

    else
        HARDN_STATUS "error" "Failed to clone YARA rules repository"
    fi

    HARDN_STATUS "info" "Cleaning up temporary directory..."
    rm -rf "$temp_dir"
    HARDN_STATUS "pass" "Cleanup complete"

    # Configure YARA integration with Legion
    HARDN_STATUS "info" "Configuring YARA integration..."
    if [ -d "/etc/legion" ]; then
        # Create Legion-specific YARA configuration
        cat > /etc/legion/yara-integration.conf << 'EOF'
# YARA Integration Configuration for Legion
yara_rules_path=/etc/yara/rules
enable_yara_scanning=true
yara_scan_on_access=true
yara_realtime_monitoring=true
yara_alert_threshold=1
EOF
        HARDN_STATUS "pass" "YARA-Legion integration configured"
    else
        HARDN_STATUS "info" "Legion not found. YARA integration will be configured when Legion is installed"
    fi
    
    # Create basic YARA configuration
    cat > /etc/yara/yara.conf << 'EOF'
# YARA Configuration
rules_directory = /etc/yara/rules
max_scan_size = 100MB
timeout = 60
threads = 4
recursive = true
EOF
    HARDN_STATUS "pass" "YARA configuration file created"
    
    else
        HARDN_STATUS "warning" "YARA command not found. Skipping rule setup"
    fi

    HARDN_STATUS "pass" "YARA setup completed"
}

main() {
    setup_yara
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

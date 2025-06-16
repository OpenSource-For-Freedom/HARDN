#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: rust.sh
# Purpose: Install Rust development tools and environment
# Location: /src/tools/rust.sh

check_root
log_tool_execution "rust.sh"

install_rust() {
    HARDN_STATUS "info" "Installing Rust and setting up environment..."
    
    if ! command_exists rustc; then
        HARDN_STATUS "info" "Downloading and installing Rust..."
        if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
            HARDN_STATUS "pass" "Rust installed successfully"
        else
            HARDN_STATUS "error" "Failed to install Rust"
            return 1
        fi
    else
        HARDN_STATUS "pass" "Rust is already installed"
    fi
    
    # Source Rust environment
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
        HARDN_STATUS "pass" "Rust environment sourced successfully"
    else
        HARDN_STATUS "error" "Failed to find Rust environment file"
        return 1
    fi
    
    # Install Rust components
    HARDN_STATUS "info" "Installing Rust components..."
    if rustup component add rustfmt clippy; then
        HARDN_STATUS "pass" "Rust components installed successfully"
    else
        HARDN_STATUS "error" "Failed to install Rust components"
        return 1
    fi
    
    # Install Rust toolchain
    HARDN_STATUS "info" "Installing Rust stable toolchain..."
    if rustup toolchain install stable; then
        HARDN_STATUS "pass" "Rust toolchain installed successfully"
    else
        HARDN_STATUS "error" "Failed to install Rust toolchain"
        return 1
    fi
    
    # Set default Rust toolchain
    HARDN_STATUS "info" "Setting default Rust toolchain..."
    if rustup default stable; then
        HARDN_STATUS "pass" "Default Rust toolchain set successfully"
    else
        HARDN_STATUS "error" "Failed to set default Rust toolchain"
        return 1
    fi
    
    # Update Rust toolchain
    HARDN_STATUS "info" "Updating Rust toolchain..."
    if rustup update; then
        HARDN_STATUS "pass" "Rust toolchain updated successfully"
    else
        HARDN_STATUS "warning" "Failed to update Rust toolchain"
    fi
    
    # Install useful Rust packages
    HARDN_STATUS "info" "Installing useful Rust packages..."
    local packages=(ripgrep fd-find bat exa cargo-audit cargo-outdated cargo-tree)
    for pkg in "${packages[@]}"; do
        if cargo install "$pkg"; then
            HARDN_STATUS "pass" "Installed $pkg successfully"
        else
            HARDN_STATUS "warning" "Failed to install $pkg"
        fi
    done
    
    # Add Rust binaries to PATH
    HARDN_STATUS "info" "Adding Rust binaries to PATH..."
    if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$HOME/.bashrc"
        source "$HOME/.bashrc" || true
        HARDN_STATUS "pass" "Rust binaries added to PATH successfully"
    else
        HARDN_STATUS "pass" "Rust binaries already in PATH"
    fi
    
    # Verify installation
    HARDN_STATUS "info" "Verifying Rust installation..."
    if command_exists rustc && command_exists cargo; then
        local rust_version=$(rustc --version)
        local cargo_version=$(cargo --version)
        HARDN_STATUS "pass" "Rust installation verified: $rust_version"
        HARDN_STATUS "pass" "Cargo installation verified: $cargo_version"
    else
        HARDN_STATUS "error" "Rust installation verification failed"
        return 1
    fi
    
    HARDN_STATUS "pass" "Rust installation and setup completed successfully"
}

main() {
    install_rust
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

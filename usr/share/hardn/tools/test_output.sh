#!/bin/bash

source "$(cd "$(dirname "$0")" && pwd)/functions.sh"

# HARDN Tool: test_output.sh
# Purpose: Test output visibility and real-time display functionality
# Location: /src/tools/test_output.sh

check_root
log_tool_execution "test_output.sh"

test_output_visibility() {
    HARDN_STATUS "info" "Testing output visibility and real-time display..."
    
    echo "This is regular stdout output"
    echo "This message should be visible in real-time"
    
    # Simulate package installation progress
    HARDN_STATUS "info" "Simulating package installation progress..."
    for i in {1..5}; do
        printf "Progress: %d/5 - Installing component %d...\n" "$i" "$i"
        sleep 1
    done
    
    # Test stderr output
    echo "This is stderr output test" >&2
    
    # Test HARDN_STATUS functions
    HARDN_STATUS "info" "Testing HARDN_STATUS info message"
    HARDN_STATUS "pass" "Testing HARDN_STATUS pass message"
    HARDN_STATUS "warning" "Testing HARDN_STATUS warning message"
    
    # Simulate apt-style output
    HARDN_STATUS "pass" "Installation simulation completed successfully"
    
    # Test command output
    HARDN_STATUS "info" "Running system command test:"
    ls -la /tmp | head -3
    
    # Test progress with color output
    for color in "32" "33" "34" "35" "36"; do
        printf "\033[1;%sm[COLOR TEST] This is color test %s\033[0m\n" "$color" "$color"
        sleep 0.5
    done
    
    HARDN_STATUS "pass" "Output visibility test completed successfully"
}

main() {
    test_output_visibility
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

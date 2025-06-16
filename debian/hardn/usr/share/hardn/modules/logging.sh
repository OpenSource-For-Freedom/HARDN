#!/bin/bash

# HARDN Logging Module
# Provides centralized logging functionality with different log levels

# ANSI color codes for colored output
if [[ ! -v RED ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    # readonly BLUE='\033[0;34m'     # Unused - available for future use
    # readonly PURPLE='\033[0;35m'   # Unused - available for future use
    readonly CYAN='\033[0;36m'
    # readonly WHITE='\033[1;37m'    # Unused - available for future use
    readonly NC='\033[0m' # No Color
fi

# Default log level (can be overridden by environment variable)
LOG_LEVEL=${LOG_LEVEL:-info}

# Log file path
if [[ ! -v LOG_FILE ]]; then
    readonly LOG_FILE="${HARDN_LOG_DIR:-/var/log/hardn}/hardn.log"
fi

# Initialize logging system
init_logging() {
    # Create log directory if it doesn't exist
    if [[ ! -d "$(dirname "${LOG_FILE}")" ]]; then
        mkdir -p "$(dirname "${LOG_FILE}")"
    fi
    
    # Set proper permissions
    if [[ -w "$(dirname "${LOG_FILE}")" ]]; then
        touch "${LOG_FILE}"
        chmod 640 "${LOG_FILE}"
        if getent passwd hardn >/dev/null 2>&1; then
            chown hardn:hardn "${LOG_FILE}" 2>/dev/null || true
        fi
    fi
}

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Get log level priority (higher number = higher priority)
get_log_level_priority() {
    case "$1" in
        debug) echo 0 ;;
        info)  echo 1 ;;
        warn)  echo 2 ;;
        error) echo 3 ;;
        *)     echo 1 ;; # default to info
    esac
}

# Check if message should be logged based on current log level
should_log() {
    local msg_level="$1"
    local current_priority
    local msg_priority
    
    current_priority=$(get_log_level_priority "${LOG_LEVEL}")
    msg_priority=$(get_log_level_priority "${msg_level}")
    
    [[ ${msg_priority} -ge ${current_priority} ]]
}

# Write log entry to file
write_log_file() {
    local level="$1"
    local message="$2"
    local timestamp
    
    timestamp=$(get_timestamp)
    
    if [[ -w "${LOG_FILE}" ]]; then
        echo "[${timestamp}] [${level^^}] ${message}" >> "${LOG_FILE}"
    fi
}

# Generic logging function
do_log() {
    local level="$1"
    local color="$2"
    local message="$3"
    
    if should_log "${level}"; then
        # Write to log file
        write_log_file "${level}" "${message}"
        
        # Print to stdout/stderr with color
        if [[ -t 1 ]]; then
            # Terminal supports colors
            echo -e "${color}[${level^^}]${NC} ${message}" >&2
        else
            # No color support
            echo "[${level^^}] ${message}" >&2
        fi
    fi
}

# Logging functions for different levels
log_debug() {
    do_log "debug" "${CYAN}" "$*"
}

log_info() {
    do_log "info" "${GREEN}" "$*"
}

log_warn() {
    do_log "warn" "${YELLOW}" "$*"
}

log_error() {
    do_log "error" "${RED}" "$*"
}

# Status logging functions (for backward compatibility with original script)
hardn_status() {
    local status="$1"
    local message="$2"
    
    case "${status}" in
        "pass")
            log_info "OK ${message}"
            ;;
        "warning"|"warn")
            log_warn "WARNING ${message}"
            ;;
        "error"|"fail")
            log_error "ERROR ${message}"
            ;;
        "info")
            log_info "ℹ️  ${message}"
            ;;
        *)
            log_info "${message}"
            ;;
    esac
}

# Function to log command execution
log_command() {
    local command="$1"
    local success_msg="${2:-Command executed successfully}"
    local error_msg="${3:-Command failed}"
    
    log_debug "Executing: ${command}"
    
    if eval "${command}"; then
        log_debug "${success_msg}"
        return 0
    else
        local exit_code=$?
        log_error "${error_msg} (exit code: ${exit_code})"
        return ${exit_code}
    fi
}

# Function to log and execute command with output capture
execute_and_log() {
    local command="$1"
    local success_msg="${2:-}"
    local error_msg="${3:-}"
    local output
    local exit_code
    
    log_debug "Executing: ${command}"
    
    # Capture both stdout and stderr
    output=$(eval "${command}" 2>&1)
    exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]]; then
        [[ -n "${success_msg}" ]] && log_info "${success_msg}"
        [[ -n "${output}" ]] && log_debug "Output: ${output}"
        return 0
    else
        [[ -n "${error_msg}" ]] && log_error "${error_msg}"
        [[ -n "${output}" ]] && log_error "Error output: ${output}"
        return ${exit_code}
    fi
}

# Function to show progress bar (for long operations)
show_progress() {
    local current="$1"
    local total="$2"
    local description="${3:-Processing}"
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r%s: [" "${description}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d%% (%d/%d)" "${percentage}" "${current}" "${total}"
    
    if [[ ${current} -eq ${total} ]]; then
        echo # New line when complete
    fi
}

# Function to create a separator line in logs
# shellcheck disable=SC2120
log_separator() {
    local char="${1:-=}"
    local length="${2:-80}"
    local line
    
    printf -v line "%${length}s"
    line=${line// /${char}}
    
    log_info "${line}"
}

# Function to log system information
log_system_info() {
    log_separator
    log_info "HARDN System Information"
    log_separator
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/etc/os-release
        source /etc/os-release
        log_info "OS: ${PRETTY_NAME:-Unknown}"
        log_info "Version: ${VERSION_ID:-Unknown}"
        log_info "Codename: ${VERSION_CODENAME:-Unknown}"
    fi
    
    log_info "Kernel: $(uname -r)"
    log_info "Architecture: $(uname -m)"
    log_info "Hostname: $(hostname)"
    log_info "Date: $(date)"
    log_info "User: $(whoami)"
    
    log_separator
}

# Export functions for use in other modules
export -f init_logging get_timestamp should_log write_log_file do_log
export -f log_debug log_info log_warn log_error hardn_status
export -f log_command execute_and_log show_progress log_separator log_system_info
#!/bin/bash

# SSL Certificate Generator
# Author: Philip S. Wright
# Version: 1.1.0
# Description: A script to generate self-signed SSL certificates with customizable attributes

# Exit on any error
set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration file paths
CONFIG_TEMPLATE="$SCRIPT_DIR/config.template.conf"
CONFIG_FILE="$SCRIPT_DIR/config.conf"

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    elif [ -f "$CONFIG_TEMPLATE" ]; then
        source "$CONFIG_TEMPLATE"
    else
        echo "Warning: No configuration file found. Using hardcoded defaults." >&2
    fi

    # Set defaults if not defined in config
    OUTPUT_DIR="${OUTPUT_DIR:-${DEFAULT_OUTPUT_DIR:-"."}}"
    VALIDITY_DAYS="${VALIDITY_DAYS:-${DEFAULT_VALIDITY_DAYS:-365}}"
    KEY_SIZE="${KEY_SIZE:-${DEFAULT_KEY_SIZE:-2048}}"
}

# Function to validate email address
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "Error: Invalid email address format: $email" >&2
        return 1
    fi
}

# Function to validate domain name
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        echo "Error: Invalid domain name format: $domain" >&2
        return 1
    fi
}

# Function to validate numeric value
validate_numeric() {
    local value="$1"
    local name="$2"
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        echo "Error: $name must be a positive number: $value" >&2
        return 1
    fi
}

# Enhanced help function
show_help() {
    cat << EOF
SSL Certificate Generator v1.1.0

Usage: $(basename "$0") [OPTIONS]

Generate self-signed SSL certificates with customizable attributes.

Options:
    -h, --help              Show this help message
    -o, --output DIR       Output directory for certificate files (default: $OUTPUT_DIR)
    -d, --domain DOMAIN    Domain name for the certificate (Common Name)
    -c, --country CODE     Two-letter country code (default: ${DEFAULT_COUNTRY:-US})
    -s, --state STATE      State or province name (default: ${DEFAULT_STATE})
    -l, --locality CITY    City name (default: ${DEFAULT_LOCALITY})
    -org, --organization ORG Organization name (default: ${DEFAULT_ORGANIZATION})
    -ou, --unit UNIT       Organizational unit name (default: ${DEFAULT_ORG_UNIT})
    -e, --email EMAIL      Email address (default: ${DEFAULT_EMAIL})
    -v, --validity DAYS    Validity period in days (default: $VALIDITY_DAYS)
    -k, --key-size BITS    Key size in bits (default: $KEY_SIZE)
    --config FILE          Use specific configuration file

Configuration:
    The script looks for config.conf in the script directory.
    If not found, it uses config.template.conf.
    Command line arguments override configuration file settings.

Example:
    $(basename "$0") -d example.com -o /etc/ssl/certs -c US -s "New York"

EOF
}

# Function to log messages with timestamp
log_message() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Function to log errors
log_error() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ERROR: $1" >&2
}

# Enhanced parameter validation
validate_parameters() {
    local errors=0

    if [ -z "$DOMAIN" ]; then
        log_error "Domain name is required (-d or --domain)"
        errors=$((errors + 1))
    else
        validate_domain "$DOMAIN" || errors=$((errors + 1))
    fi

    if [ ! -z "$EMAIL" ]; then
        validate_email "$EMAIL" || errors=$((errors + 1))
    fi

    validate_numeric "$VALIDITY_DAYS" "Validity days" || errors=$((errors + 1))
    validate_numeric "$KEY_SIZE" "Key size" || errors=$((errors + 1))

    if [ $errors -gt 0 ]; then
        log_error "Found $errors error(s). Please fix them and try again."
        exit 1
    fi
}

# Enhanced OpenSSL check
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL is not installed or not in PATH"
        exit 1
    fi

    # Check OpenSSL version
    local version=$(openssl version)
    log_message "Using $version"
}

# Rest of the script remains the same...


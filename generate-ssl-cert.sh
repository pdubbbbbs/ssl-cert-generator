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

# Function to validate domain name, including wildcard domains
validate_domain() {
    local domain="$1"
    local domain_pattern="^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
    local wildcard_pattern="^\*\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
    
    # Check if it's a standard domain or a wildcard domain
    if [[ "$domain" =~ $domain_pattern ]] || [[ "$domain" =~ $wildcard_pattern ]]; then
        return 0
    else
        echo "Error: Invalid domain name format: $domain" >&2
        echo "       Domain should be a valid hostname or a wildcard domain (*.example.com)" >&2
        return 1
    fi
}

# Function to validate email address
validate_email() {
    local email="$1"
    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        echo "Error: Invalid email address format: $email" >&2
        return 1
    fi
}

# Function to validate IP address
validate_ip() {
    local ip="$1"
    if [[ ! "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP address format: $ip" >&2
        return 1
    fi
    
    # Validate each octet
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ "$octet" -gt 255 ]]; then
            echo "Error: Invalid IP address (octet > 255): $ip" >&2
            return 1
        fi
    done
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
                          Supports wildcard domains (e.g., *.example.com)
    -i, --ip IP_ADDR       IP address to include in the certificate (can be used multiple times)
    -c, --country CODE     Two-letter country code (default: ${DEFAULT_COUNTRY:-US})
    -s, --state STATE      State or province name (default: ${DEFAULT_STATE})
    -l, --locality CITY    City name (default: ${DEFAULT_LOCALITY})
    -org, --organization ORG Organization name (default: ${DEFAULT_ORGANIZATION})
    -ou, --unit UNIT       Organizational unit name (default: ${DEFAULT_ORG_UNIT})
    -e, --email EMAIL      Email address (default: ${DEFAULT_EMAIL})
    -v, --validity DAYS    Validity period in days (default: $VALIDITY_DAYS)
    -k, --key-size BITS    Key size in bits (default: $KEY_SIZE)
    --config FILE          Use specific configuration file

Examples:
    # Regular domain certificate
    $(basename "$0") -d example.com -o /etc/ssl/certs -c US -s "New York"

    # Wildcard certificate
    $(basename "$0") -d "*.example.com" -o /etc/ssl/certs -c US -s "California"


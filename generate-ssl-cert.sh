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

    # Validate IP addresses if provided
    for ip in "${IP_ADDRESSES[@]}"; do
        validate_ip "$ip" || errors=$((errors + 1))
    done

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

# Main function to generate SSL certificate
main() {
    local OPTIND opt
    
    # Load defaults from config
    load_config

    # Parse command line arguments
    # Initialize IP address array
    declare -a IP_ADDRESSES
    
    while getopts ":ho:d:i:c:s:l:e:v:k:-:" opt; do
        case $opt in
            -)
                case "${OPTARG}" in
                    help)
                        show_help
                        exit 0
                        ;;
                    output)
                        OUTPUT_DIR="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    domain)
                        DOMAIN="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    ip)
                        IP_ADDRESSES+=("${!OPTIND}"); OPTIND=$((OPTIND+1))
                        ;;
                    country)
                        COUNTRY="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    state)
                        STATE="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    locality)
                        LOCALITY="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    organization)
                        ORGANIZATION="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    unit)
                        ORG_UNIT="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    email)
                        EMAIL="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    validity)
                        VALIDITY_DAYS="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    key-size)
                        KEY_SIZE="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        ;;
                    config)
                        CONFIG_FILE="${!OPTIND}"; OPTIND=$((OPTIND+1))
                        load_config
                        ;;
                    *)
                        log_error "Unknown option --${OPTARG}"
                        show_help
                        exit 1
                        ;;
                esac
                ;;
            h)
                show_help
                exit 0
                ;;
            o)
                OUTPUT_DIR="$OPTARG"
                ;;
            d)
                DOMAIN="$OPTARG"
                ;;
            i)
                IP_ADDRESSES+=("$OPTARG")
                ;;
            c)
                COUNTRY="$OPTARG"
                ;;
            s)
                STATE="$OPTARG"
                ;;
            l)
                LOCALITY="$OPTARG"
                ;;
            org)
                ORGANIZATION="$OPTARG"
                ;;
            ou)
                ORG_UNIT="$OPTARG"
                ;;
            e)
                EMAIL="$OPTARG"
                ;;
            v)
                VALIDITY_DAYS="$OPTARG"
                ;;
            k)
                KEY_SIZE="$OPTARG"
                ;;
            \?)
                log_error "Invalid option: -$OPTARG"
                show_help
                exit 1
                ;;
            :)
                log_error "Option -$OPTARG requires an argument"
                show_help
                exit 1
                ;;
        esac
    done

    # Check OpenSSL installation
    check_openssl

    # Validate parameters
    validate_parameters

    # Create output directory if it doesn't exist
    if [ ! -d "$OUTPUT_DIR" ]; then
        log_message "Creating output directory: $OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR" || {
            log_error "Failed to create directory: $OUTPUT_DIR"
            exit 1
        }
    fi

    # Set file paths
    local CERT_FILE="$OUTPUT_DIR/$DOMAIN.crt"
    local KEY_FILE="$OUTPUT_DIR/$DOMAIN.key"
    local CSR_FILE="$OUTPUT_DIR/$DOMAIN.csr"
    local CONFIG_FILE="$OUTPUT_DIR/$DOMAIN.cnf"

    # Create OpenSSL configuration
    # Start OpenSSL configuration
    cat > "$CONFIG_FILE" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = ${COUNTRY:-US}
ST = ${STATE:-California}
L = ${LOCALITY:-San Francisco}
O = ${ORGANIZATION:-Example Organization}
OU = ${ORG_UNIT:-IT Department}
CN = $DOMAIN
emailAddress = ${EMAIL:-admin@example.com}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = www.$DOMAIN
EOF

    # Add IP addresses to alt_names if provided
    local ip_count=1
    for ip in "${IP_ADDRESSES[@]}"; do
        echo "IP.$ip_count = $ip" >> "$CONFIG_FILE"
        ip_count=$((ip_count + 1))
    done

    # Generate private key
    log_message "Generating private key..."
    openssl genrsa -out "$KEY_FILE" "$KEY_SIZE" || {
        log_error "Failed to generate private key"
        exit 1
    }

    # Generate CSR
    log_message "Generating certificate signing request..."
    openssl req -new -key "$KEY_FILE" -out "$CSR_FILE" -config "$CONFIG_FILE" || {
        log_error "Failed to generate CSR"
        exit 1
    }

    # Generate self-signed certificate
    log_message "Generating self-signed certificate..."
    openssl x509 -req -days "$VALIDITY_DAYS" -in "$CSR_FILE" -signkey "$KEY_FILE" \
        -out "$CERT_FILE" -extensions v3_req -extfile "$CONFIG_FILE" || {
        log_error "Failed to generate certificate"
        exit 1
    }

    # Set permissions
    chmod 600 "$KEY_FILE" || log_error "Failed to set permissions on key file"
    chmod 644 "$CERT_FILE" || log_error "Failed to set permissions on certificate file"

    log_message "Certificate generation complete!"
    log_message "Certificate: $CERT_FILE"
    log_message "Certificate: $CERT_FILE"
    log_message "Private key: $KEY_FILE"
    log_message "Validity: $VALIDITY_DAYS days"
    
    # List IP addresses if included
    if [ ${#IP_ADDRESSES[@]} -gt 0 ]; then
        log_message "IP addresses included in certificate:"
        for ip in "${IP_ADDRESSES[@]}"; do
            log_message "  - $ip"
        done
    fi
    return 0
}

# Execute main function with all arguments
# Wrap in a conditional to handle errors gracefully
if ! main "$@"; then
    log_error "Certificate generation failed"
    exit 1
fi

exit 0

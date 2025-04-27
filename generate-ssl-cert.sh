#!/bin/bash

# SSL Certificate Generator
# Author: Philip S. Wright
# Version: 1.1.0

# Exit on any error
set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration file paths
CONFIG_TEMPLATE="$SCRIPT_DIR/config.template.conf"
CONFIG_FILE="$SCRIPT_DIR/config.conf"

# Function to validate domain name, including wildcard domains
validate_domain() {
    local domain="$1"
    local domain_pattern="^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
    local wildcard_pattern="^\*\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
    
    if [[ "$domain" =~ $domain_pattern ]] || [[ "$domain" =~ $wildcard_pattern ]]; then
        return 0
    else
        echo "Error: Invalid domain name format: $domain" >&2
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
    
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [[ "$octet" -gt 255 ]]; then
            echo "Error: Invalid IP address (octet > 255): $ip" >&2
            return 1
        fi
    done
}

# Function to log messages with timestamp
log_message() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Function to log errors
log_error() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ERROR: $1" >&2
}

# Check OpenSSL installation
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL is not installed or not in PATH"
        exit 1
    fi
    local version=$(openssl version)
    log_message "Using $version"
}

# Main function
main() {
    local DOMAIN=""
    local OUTPUT_DIR="."
    local COUNTRY="US"
    local STATE="California"
    local LOCALITY="San Francisco"
    local ORGANIZATION="Example Organization"
    local ORG_UNIT="IT Department"
    local EMAIL="admin@example.com"
    local VALIDITY_DAYS=365
    local KEY_SIZE=2048
    declare -a IP_ADDRESSES

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -i|--ip)
                IP_ADDRESSES+=("$2")
                shift 2
                ;;
            -c|--country)
                COUNTRY="$2"
                shift 2
                ;;
            -s|--state)
                STATE="$2"
                shift 2
                ;;
            -l|--locality)
                LOCALITY="$2"
                shift 2
                ;;
            -org|--organization)
                ORGANIZATION="$2"
                shift 2
                ;;
            -ou|--unit)
                ORG_UNIT="$2"
                shift 2
                ;;
            -e|--email)
                EMAIL="$2"
                shift 2
                ;;
            -v|--validity)
                VALIDITY_DAYS="$2"
                shift 2
                ;;
            -k|--key-size)
                KEY_SIZE="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Validate domain
    if [ -z "$DOMAIN" ]; then
        log_error "Domain name is required (-d or --domain)"
        exit 1
    fi
    validate_domain "$DOMAIN" || exit 1

    # Check if it's a wildcard certificate
    local IS_WILDCARD=0
    [[ "$DOMAIN" == \** ]] && IS_WILDCARD=1

    # Create output directory
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR" || {
            log_error "Failed to create directory: $OUTPUT_DIR"
            exit 1
        }
    fi

    # Set file paths for wildcard certificates
    local DOMAIN_FILENAME="${DOMAIN/\*/wildcard}"
    local CERT_FILE="$OUTPUT_DIR/$DOMAIN_FILENAME.crt"
    local KEY_FILE="$OUTPUT_DIR/$DOMAIN_FILENAME.key"
    local CSR_FILE="$OUTPUT_DIR/$DOMAIN_FILENAME.csr"
    local CONFIG_FILE="$OUTPUT_DIR/$DOMAIN_FILENAME.cnf"

    # Create OpenSSL config
    cat > "$CONFIG_FILE" << SSLCONFIG
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $COUNTRY
ST = $STATE
L = $LOCALITY
O = $ORGANIZATION
OU = $ORG_UNIT
CN = $DOMAIN
emailAddress = $EMAIL

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
SSLCONFIG

    # Add DNS entries based on domain type
    if [ $IS_WILDCARD -eq 1 ]; then
        local BASE_DOMAIN="${DOMAIN#\*.}"
        echo "DNS.2 = $BASE_DOMAIN" >> "$CONFIG_FILE"
        echo "DNS.3 = www.$BASE_DOMAIN" >> "$CONFIG_FILE"
    else
        echo "DNS.2 = www.$DOMAIN" >> "$CONFIG_FILE"
    fi

    # Add IP addresses
    local ip_count=1
    for ip in "${IP_ADDRESSES[@]}"; do
        validate_ip "$ip" || exit 1
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

    # Generate certificate
    log_message "Generating self-signed certificate..."
    openssl x509 -req -days "$VALIDITY_DAYS" -in "$CSR_FILE" -signkey "$KEY_FILE" \
        -out "$CERT_FILE" -extensions v3_req -extfile "$CONFIG_FILE" || {
        log_error "Failed to generate certificate"
        exit 1
    }

    # Set permissions
    chmod 600 "$KEY_FILE" || log_error "Failed to set permissions on key file"
    chmod 644 "$CERT_FILE" || log_error "Failed to set permissions on certificate file"

    # Success message
    log_message "Certificate generation complete!"
    log_message "Certificate: $CERT_FILE"
    log_message "Private key: $KEY_FILE"
    log_message "Validity: $VALIDITY_DAYS days"
    
    if [ $IS_WILDCARD -eq 1 ]; then
        log_message "Certificate type: Wildcard"
        log_message "Protects: $DOMAIN and all subdomains of ${DOMAIN#\*.}"
    fi

    return 0
}

# Run main function with all arguments
check_openssl
main "$@" || exit 1

#!/bin/bash

# SSL Certificate Generator
# Author: Philip S. Wright
# Version: 1.0.0
# Description: A script to generate self-signed SSL certificates with customizable attributes

# Exit on any error
set -e

# Default values
OUTPUT_DIR="."
VALIDITY_DAYS=365
KEY_SIZE=2048

# Function to display usage information
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generate self-signed SSL certificates with customizable attributes.

Options:
    -h, --help              Show this help message
    -o, --output DIR       Output directory for certificate files (default: current directory)
    -d, --domain DOMAIN    Domain name for the certificate (Common Name)
    -c, --country CODE     Two-letter country code (default: US)
    -s, --state STATE      State or province name
    -l, --locality CITY    City name
    -org, --organization ORG Organization name
    -ou, --unit UNIT       Organizational unit name
    -e, --email EMAIL      Email address
    -v, --validity DAYS    Validity period in days (default: 365)
    -k, --key-size BITS    Key size in bits (default: 2048)

Example:
    $(basename "$0") -d example.com -o /etc/ssl/certs -c US -s "New York" -l "New York City" -org "My Company" -e "admin@example.com"

EOF
}

# Function to validate required OpenSSL installation
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        echo "Error: OpenSSL is not installed or not in PATH" >&2
        exit 1
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN="$2"
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
                echo "Error: Unknown option $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# Validate required parameters
validate_parameters() {
    if [ -z "$DOMAIN" ]; then
        echo "Error: Domain name is required (-d or --domain)" >&2
        show_help
        exit 1
    fi
}

# Function to create output directory if it doesnt exist
setup_output_directory() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to create output directory: $OUTPUT_DIR" >&2
            exit 1
        fi
    fi
}

# Function to generate private key
generate_private_key() {
    local key_file="$OUTPUT_DIR/$DOMAIN.key"
    openssl genrsa -out "$key_file" $KEY_SIZE 2>/dev/null
    chmod 600 "$key_file"
    echo "Generated private key: $key_file"
}

# Function to generate CSR
generate_csr() {
    local key_file="$OUTPUT_DIR/$DOMAIN.key"
    local csr_file="$OUTPUT_DIR/$DOMAIN.csr"
    local subject="/CN=$DOMAIN"
    
    # Add optional subject fields if provided
    [ ! -z "$COUNTRY" ] && subject="/C=$COUNTRY$subject"
    [ ! -z "$STATE" ] && subject="/ST=$STATE$subject"
    [ ! -z "$LOCALITY" ] && subject="/L=$LOCALITY$subject"
    [ ! -z "$ORGANIZATION" ] && subject="/O=$ORGANIZATION$subject"
    [ ! -z "$ORG_UNIT" ] && subject="/OU=$ORG_UNIT$subject"
    [ ! -z "$EMAIL" ] && subject="/emailAddress=$EMAIL$subject"

    openssl req -new -key "$key_file" -out "$csr_file" -subj "$subject"
    echo "Generated CSR: $csr_file"
}

# Function to generate self-signed certificate
generate_certificate() {
    local key_file="$OUTPUT_DIR/$DOMAIN.key"
    local csr_file="$OUTPUT_DIR/$DOMAIN.csr"
    local crt_file="$OUTPUT_DIR/$DOMAIN.crt"
    
    openssl x509 -req -days $VALIDITY_DAYS -in "$csr_file" -signkey "$key_file" -out "$crt_file"
    chmod 644 "$crt_file"
    echo "Generated certificate: $crt_file"
}

# Main execution
main() {
    check_openssl
    parse_arguments "$@"
    validate_parameters
    setup_output_directory
    
    echo "Generating SSL certificate for domain: $DOMAIN"
    echo "Output directory: $OUTPUT_DIR"
    
    generate_private_key
    generate_csr
    generate_certificate
    
    echo "Certificate generation complete!"
    echo "Files generated in: $OUTPUT_DIR"
    ls -l "$OUTPUT_DIR/$DOMAIN".*
}

# Execute main function with all arguments
main "$@"

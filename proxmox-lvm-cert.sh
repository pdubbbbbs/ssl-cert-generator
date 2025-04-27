#!/bin/bash

# Proxmox LVM Certificate Generator
# Interactive script to generate and install SSL certificates for Proxmox LVM

# Source common functions if available
if [ -f "$(dirname "$0")/tests/test-functions.sh" ]; then
    source "$(dirname "$0")/tests/test-functions.sh"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to prompt for input with validation
prompt_input() {
    local prompt="$1"
    local validate_func="$2"
    local default="$3"
    local value=""
    
    while true; do
        if [ -n "$default" ]; then
            echo -e -n "${BLUE}$prompt ${NC}[${GREEN}$default${NC}]: "
        else
            echo -e -n "${BLUE}$prompt${NC}: "
        fi
        
        read -r value
        
        # Use default if empty input
        if [ -z "$value" ] && [ -n "$default" ]; then
            value="$default"
        fi
        
        # Validate input if validation function provided
        if [ -n "$validate_func" ]; then
            if $validate_func "$value"; then
                break
            fi
        else
            if [ -n "$value" ]; then
                break
            fi
        fi
    done
    
    echo "$value"
}

# Validation functions
validate_domain() {
    local domain="$1"
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    echo -e "${RED}Invalid domain format. Please use a valid domain name.${NC}" >&2
    return 1
}

validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    echo -e "${RED}Invalid IP address format. Please use IPv4 format (e.g., 192.168.1.100)${NC}" >&2
    return 1
}

validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 0
    fi
    echo -e "${RED}Invalid email format. Please use a valid email address.${NC}" >&2
    return 1
}

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    fi
    echo -e "${RED}Invalid port number. Please use a number between 1 and 65535.${NC}" >&2
    return 1
}

# Print banner
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}    Proxmox LVM Certificate Generator       ${NC}"
echo -e "${GREEN}============================================${NC}"
echo

# Gather information
echo -e "${YELLOW}Please provide the following information:${NC}"
echo

# Basic information
DOMAIN=$(prompt_input "Proxmox domain name" validate_domain "proxmox.local")
IP_ADDRESS=$(prompt_input "Proxmox IP address" validate_ip "192.168.1.100")
EMAIL=$(prompt_input "Admin email address" validate_email "admin@example.com")
SSH_PORT=$(prompt_input "SSH port" validate_port "22")

# Organization details
echo -e "\n${YELLOW}Organization Details:${NC}"
COUNTRY=$(prompt_input "Country code (2 letters)" "" "US")
STATE=$(prompt_input "State/Province" "" "California")
LOCALITY=$(prompt_input "City" "" "San Francisco")
ORGANIZATION=$(prompt_input "Organization name" "" "Example Org")
ORG_UNIT=$(prompt_input "Organization unit" "" "IT Department")

# Certificate details
echo -e "\n${YELLOW}Certificate Configuration:${NC}"
VALIDITY_DAYS=$(prompt_input "Certificate validity in days" "" "365")
KEY_SIZE=$(prompt_input "Key size in bits" "" "2048")

# Backup configuration
echo -e "\n${YELLOW}Backup Configuration:${NC}"
BACKUP_DIR=$(prompt_input "Backup directory" "" "/root/cert_backups")

# Confirm settings
echo -e "\n${YELLOW}Please review your settings:${NC}"
echo -e "Domain name: ${GREEN}$DOMAIN${NC}"
echo -e "IP address: ${GREEN}$IP_ADDRESS${NC}"
echo -e "Email: ${GREEN}$EMAIL${NC}"
echo -e "SSH port: ${GREEN}$SSH_PORT${NC}"
echo -e "Country: ${GREEN}$COUNTRY${NC}"
echo -e "State: ${GREEN}$STATE${NC}"
echo -e "City: ${GREEN}$LOCALITY${NC}"
echo -e "Organization: ${GREEN}$ORGANIZATION${NC}"
echo -e "Unit: ${GREEN}$ORG_UNIT${NC}"
echo -e "Validity: ${GREEN}$VALIDITY_DAYS days${NC}"
echo -e "Key size: ${GREEN}$KEY_SIZE bits${NC}"
echo -e "Backup directory: ${GREEN}$BACKUP_DIR${NC}"

echo
read -p "Proceed with certificate generation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Certificate generation cancelled.${NC}"
    exit 1
fi

# Generate certificate
echo -e "\n${YELLOW}Generating certificate...${NC}"
./generate-ssl-cert.sh \
    -d "$DOMAIN" \
    -i "$IP_ADDRESS" \
    -o "./certs" \
    -c "$COUNTRY" \
    -s "$STATE" \
    -l "$LOCALITY" \
    -org "$ORGANIZATION" \
    -ou "$ORG_UNIT" \
    -e "$EMAIL" \
    -v "$VALIDITY_DAYS" \
    -k "$KEY_SIZE"

if [ $? -ne 0 ]; then
    echo -e "${RED}Certificate generation failed!${NC}"
    exit 1
fi

# Install certificate
echo -e "\n${YELLOW}Installing certificate on Proxmox...${NC}"
./install-proxmox-cert.sh \
    -d "$DOMAIN" \
    -i "$IP_ADDRESS" \
    -p "$SSH_PORT" \
    -b "$BACKUP_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}Certificate installation failed!${NC}"
    exit 1
fi

echo -e "\n${GREEN}Certificate generation and installation complete!${NC}"
echo -e "\nNext steps:"
echo -e "1. Access Proxmox web interface at: ${GREEN}https://$DOMAIN:8006${NC}"
echo -e "2. Verify certificate in your browser"
echo -e "3. Check certificate expiration: ${GREEN}$VALIDITY_DAYS${NC} days from now"
echo -e "4. Backup location: ${GREEN}$BACKUP_DIR${NC}"

# Create reminder for renewal
EXPIRY_DATE=$(date -d "+$VALIDITY_DAYS days" +%Y-%m-%d)
echo -e "\n${YELLOW}Important:${NC}"
echo -e "Certificate will expire on: ${RED}$EXPIRY_DATE${NC}"
echo -e "Set a reminder to renew before: ${GREEN}$(date -d "$EXPIRY_DATE - 30 days" +%Y-%m-%d)${NC}"

exit 0

#!/bin/bash

# Proxmox Certificate Generation Wizard
# A user-friendly interface for generating Proxmox SSL certificates

# Color codes for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to clear screen and show header
show_header() {
    clear
    echo -e "${CYAN}=================================================${NC}"
    echo -e "${CYAN}          Proxmox Certificate Wizard              ${NC}"
    echo -e "${CYAN}=================================================${NC}"
    echo
}

# Function to show progress
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percent=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%%" $percent
}

# Function to validate input with timeout
prompt_with_timeout() {
    local prompt="$1"
    local default="$2"
    local timeout=30
    local input
    
    echo -e -n "${BLUE}$prompt${NC} [${GREEN}$default${NC}] (${timeout}s timeout): "
    read -t $timeout input
    
    if [ $? -eq 142 ]; then
        echo -e "\n${YELLOW}Using default value: $default${NC}"
        echo "$default"
        return
    fi
    
    echo "${input:-$default}"
}

# Function to test connection
test_connection() {
    local host=$1
    local port=$2
    
    echo -e "\n${YELLOW}Testing connection to $host:$port...${NC}"
    nc -zv -w 5 "$host" "$port" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Connection successful!${NC}"
        return 0
    else
        echo -e "${RED}Connection failed!${NC}"
        return 1
    fi
}

# Save configuration function
save_config() {
    local config_file="$1"
    
    cat > "$config_file" << CONFIG
# Proxmox Certificate Configuration
# Generated on $(date)

DOMAIN="$DOMAIN"
IP_ADDRESS="$IP_ADDRESS"
EMAIL="$EMAIL"
SSH_PORT="$SSH_PORT"
COUNTRY="$COUNTRY"
STATE="$STATE"
LOCALITY="$LOCALITY"
ORGANIZATION="$ORGANIZATION"
ORG_UNIT="$ORG_UNIT"
VALIDITY_DAYS="$VALIDITY_DAYS"
KEY_SIZE="$KEY_SIZE"
BACKUP_DIR="$BACKUP_DIR"
CONFIG

    echo -e "${GREEN}Configuration saved to: $config_file${NC}"
}

# Load configuration function
load_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        source "$config_file"
        echo -e "${GREEN}Configuration loaded from: $config_file${NC}"
        return 0
    fi
    return 1
}

# Main wizard function
run_wizard() {
    local step=1
    local total_steps=8
    local config_file="proxmox-cert.conf"
    
    show_header
    
    # Check for existing configuration
    if [ -f "$config_file" ]; then
        echo -e "${YELLOW}Found existing configuration.${NC}"
        read -p "Load it? (Y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
            load_config "$config_file"
        fi
    fi
    
    # Basic Information
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Basic Information${NC}"
    show_progress $step $total_steps
    echo
    
    DOMAIN=$(prompt_with_timeout "Domain name" "${DOMAIN:-proxmox.local}")
    IP_ADDRESS=$(prompt_with_timeout "IP address" "${IP_ADDRESS:-192.168.1.100}")
    EMAIL=$(prompt_with_timeout "Admin email" "${EMAIL:-admin@example.com}")
    SSH_PORT=$(prompt_with_timeout "SSH port" "${SSH_PORT:-22}")
    
    # Organization Details
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Organization Details${NC}"
    show_progress $step $total_steps
    echo
    
    COUNTRY=$(prompt_with_timeout "Country code (2 letters)" "${COUNTRY:-US}")
    STATE=$(prompt_with_timeout "State/Province" "${STATE:-California}")
    LOCALITY=$(prompt_with_timeout "City" "${LOCALITY:-San Francisco}")
    ORGANIZATION=$(prompt_with_timeout "Organization name" "${ORGANIZATION:-Example Org}")
    ORG_UNIT=$(prompt_with_timeout "Organization unit" "${ORG_UNIT:-IT Department}")
    
    # Certificate Configuration
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Certificate Configuration${NC}"
    show_progress $step $total_steps
    echo
    
    VALIDITY_DAYS=$(prompt_with_timeout "Certificate validity (days)" "${VALIDITY_DAYS:-365}")
    KEY_SIZE=$(prompt_with_timeout "Key size (bits)" "${KEY_SIZE:-2048}")
    BACKUP_DIR=$(prompt_with_timeout "Backup directory" "${BACKUP_DIR:-/root/cert_backups}")
    
    # Connection Test
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Connection Test${NC}"
    show_progress $step $total_steps
    echo
    
    if ! test_connection "$IP_ADDRESS" "$SSH_PORT"; then
        echo -e "${RED}Warning: Cannot connect to Proxmox server!${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Wizard cancelled.${NC}"
            exit 1
        fi
    fi
    
    # Save Configuration
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Save Configuration${NC}"
    show_progress $step $total_steps
    echo
    
    read -p "Save configuration for future use? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [ -z "$REPLY" ]; then
        save_config "$config_file"
    fi
    
    # Generate Certificate
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Generate Certificate${NC}"
    show_progress $step $total_steps
    echo
    
    if ! ./generate-ssl-cert.sh \
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
        -k "$KEY_SIZE"; then
        echo -e "${RED}Certificate generation failed!${NC}"
        exit 1
    fi
    
    # Install Certificate
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Install Certificate${NC}"
    show_progress $step $total_steps
    echo
    
    if ! ./install-proxmox-cert.sh \
        -d "$DOMAIN" \
        -i "$IP_ADDRESS" \
        -p "$SSH_PORT" \
        -b "$BACKUP_DIR"; then
        echo -e "${RED}Certificate installation failed!${NC}"
        exit 1
    fi
    
    # Completion
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Complete${NC}"
    show_progress $step $total_steps
    echo -e "\n${GREEN}Certificate generation and installation complete!${NC}"
    
    # Summary
    echo -e "\n${CYAN}Installation Summary:${NC}"
    echo -e "Domain: ${GREEN}$DOMAIN${NC}"
    echo -e "IP Address: ${GREEN}$IP_ADDRESS${NC}"
    echo -e "Web Interface: ${GREEN}https://$DOMAIN:8006${NC}"
    echo -e "Certificate Location: ${GREEN}./certs/$DOMAIN.crt${NC}"
    echo -e "Backup Location: ${GREEN}$BACKUP_DIR${NC}"
    
    # Next Steps
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo "1. Access Proxmox web interface at https://$DOMAIN:8006"
    echo "2. Verify certificate in your browser"
    echo "3. Set up automated renewal before $(date -d "+$VALIDITY_DAYS days" +%Y-%m-%d)"
    
    echo -e "\n${GREEN}Wizard completed successfully!${NC}"
}

# Run the wizard
run_wizard

exit 0

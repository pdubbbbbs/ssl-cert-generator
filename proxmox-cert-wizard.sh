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
    echo
}

# Function to validate input
validate_input() {
    local value="$1"
    local type="$2"
    local pattern=""
    
    case "$type" in
        "domain")
            pattern="^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
            ;;
        "ip")
            pattern="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
            ;;
        "email")
            pattern="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"
            ;;
        "port")
            if [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le 65535 ]; then
                return 0
            fi
            return 1
            ;;
        *)
            return 0
            ;;
    esac
    
    [[ "$value" =~ $pattern ]]
}

# Function to get user input with validation
get_input() {
    local prompt="$1"
    local type="$2"
    local default="$3"
    local value=""
    local attempts=0
    local max_attempts=3
    
    while [ $attempts -lt $max_attempts ]; do
        echo -e -n "${BLUE}$prompt${NC} [${GREEN}$default${NC}]: "
        read -r value
        
        # Use default if empty
        if [ -z "$value" ]; then
            value="$default"
        fi
        
        # Validate input
        if validate_input "$value" "$type"; then
            echo "$value"
            return 0
        else
            attempts=$((attempts + 1))
            echo -e "${RED}Invalid input. Please try again. ($attempts/$max_attempts)${NC}"
        fi
    done
    
    echo -e "${RED}Maximum attempts reached. Using default: $default${NC}"
    echo "$default"
    return 0
}

# Function to test connection
test_connection() {
    local host=$1
    local port=$2
    local timeout=5
    
    echo -e "\n${YELLOW}Testing connection to $host:$port...${NC}"
    nc -z -w $timeout "$host" "$port" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Connection successful!${NC}"
        return 0
    else
        echo -e "${RED}Connection failed!${NC}"
        return 1
    fi
}

# Function to generate certificate
generate_certificate() {
    local domain="$1"
    local ip="$2"
    local country="$3"
    local state="$4"
    local locality="$5"
    local org="$6"
    local unit="$7"
    local email="$8"
    local days="$9"
    local keysize="${10}"
    local output_dir="./certs"
    
    mkdir -p "$output_dir"
    
    echo -e "\n${YELLOW}Generating certificate...${NC}"
    if ! ./generate-ssl-cert.sh \
        -d "$domain" \
        -i "$ip" \
        -o "$output_dir" \
        -c "$country" \
        -s "$state" \
        -l "$locality" \
        -org "$org" \
        -ou "$unit" \
        -e "$email" \
        -v "$days" \
        -k "$keysize"; then
        echo -e "${RED}Certificate generation failed!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Certificate generated successfully!${NC}"
    return 0
}

# Main wizard function
run_wizard() {
    local step=1
    local total_steps=7
    
    show_header
    echo -e "${YELLOW}Welcome to the Proxmox Certificate Wizard${NC}"
    echo -e "This wizard will guide you through generating and installing SSL certificates for your Proxmox server."
    echo
    read -p "Press Enter to continue..."
    
    # Step 1: Basic Information
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Basic Information${NC}"
    show_progress $step $total_steps
    
    DOMAIN=$(get_input "Domain name" "domain" "proxmox.local")
    IP_ADDRESS=$(get_input "IP address" "ip" "192.168.1.100")
    EMAIL=$(get_input "Admin email" "email" "admin@example.com")
    SSH_PORT=$(get_input "SSH port" "port" "22")
    
    # Step 2: Organization Details
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Organization Details${NC}"
    show_progress $step $total_steps
    
    COUNTRY=$(get_input "Country code (2 letters)" "text" "US")
    STATE=$(get_input "State/Province" "text" "California")
    LOCALITY=$(get_input "City" "text" "San Francisco")
    ORGANIZATION=$(get_input "Organization name" "text" "Example Org")
    ORG_UNIT=$(get_input "Organization unit" "text" "IT Department")
    
    # Step 3: Certificate Configuration
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Certificate Configuration${NC}"
    show_progress $step $total_steps
    
    VALIDITY_DAYS=$(get_input "Certificate validity (days)" "number" "365")
    KEY_SIZE=$(get_input "Key size (bits)" "number" "2048")
    
    # Step 4: Connection Test
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Connection Test${NC}"
    show_progress $step $total_steps
    
    if ! test_connection "$IP_ADDRESS" "$SSH_PORT"; then
        echo -e "${YELLOW}Warning: Cannot connect to Proxmox server${NC}"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Wizard cancelled.${NC}"
            exit 1
        fi
    fi
    
    # Step 5: Generate Certificate
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Generate Certificate${NC}"
    show_progress $step $total_steps
    
    if ! generate_certificate \
        "$DOMAIN" \
        "$IP_ADDRESS" \
        "$COUNTRY" \
        "$STATE" \
        "$LOCALITY" \
        "$ORGANIZATION" \
        "$ORG_UNIT" \
        "$EMAIL" \
        "$VALIDITY_DAYS" \
        "$KEY_SIZE"; then
        exit 1
    fi
    
    # Step 6: Install Certificate
    show_header
    echo -e "${PURPLE}Step $((step++))/$total_steps: Install Certificate${NC}"
    show_progress $step $total_steps
    
    echo -e "\n${YELLOW}Installing certificate...${NC}"
    if ! ./install-proxmox-cert.sh \
        -d "$DOMAIN" \
        -i "$IP_ADDRESS" \
        -p "$SSH_PORT" \
        -k ~/.ssh/id_rsa; then
        echo -e "${RED}Certificate installation failed!${NC}"
        exit 1
    fi
    
    # Step 7: Completion
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

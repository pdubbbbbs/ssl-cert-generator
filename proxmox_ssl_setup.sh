#!/bin/bash

# proxmox_ssl_setup.sh
# Script to set up an LXC container for SSL certificate generation in Proxmox
# Created: $(date)

# Set strict error handling
set -eo pipefail

# Global variables
LOG_FILE="ssl_setup_$(date +%Y%m%d%H%M%S).log"
SSL_CONTAINER_ID="9000"  # Default container ID, change if needed
SSL_CONTAINER_NAME="ssl-wizard"
SSL_CONTAINER_PASSWORD="$(openssl rand -base64 12)" # Random secure password

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Log to console with color
    case "$level" in
        "INFO")
            echo -e "${GREEN}[$timestamp] [$level] $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp] [$level] $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] [$level] $message${NC}"
            ;;
        *)
            echo -e "${BLUE}[$timestamp] [$level] $message${NC}"
            ;;
    esac
}

# Function to check if running as root or with sudo
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "This script must be run as root or with sudo"
        exit 1
    fi
}

# Function to check and install required Proxmox CLI tools
check_install_prerequisites() {
    log "INFO" "Checking for required Proxmox CLI tools..."
    
    # Check if we're running on a Proxmox server
    if ! command -v pveversion &> /dev/null; then
        log "ERROR" "This script must be run on a Proxmox server"
        exit 1
    fi
    
    # Check for required packages
    local required_packages=("pve-container" "pvesh" "wget" "curl" "jq")
    local missing_packages=()
    
    for pkg in "${required_packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null && ! dpkg -l | grep -q "$pkg"; then
            missing_packages+=("$pkg")
        fi
    done
    
    # Install missing packages if any
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log "WARNING" "Installing missing packages: ${missing_packages[*]}"
        apt-get update
        apt-get install -y "${missing_packages[@]}"
    else
        log "INFO" "All required packages are installed"
    fi
}

# Function to find a free container ID
find_free_container_id() {
    log "INFO" "Finding a free container ID..."
    
    # Get list of existing container IDs
    local existing_ids=$(pct list | awk 'NR>1 {print $1}')
    
    # Start from the default ID and increment until we find a free one
    local test_id="$SSL_CONTAINER_ID"
    while echo "$existing_ids" | grep -q "$test_id"; do
        test_id=$((test_id + 1))
    done
    
    SSL_CONTAINER_ID="$test_id"
    log "INFO" "Selected container ID: $SSL_CONTAINER_ID"
}

# Function to create an LXC container for SSL generation
create_ssl_container() {
    log "INFO" "Creating SSL generation container with ID: $SSL_CONTAINER_ID"
    
    # Find a free container ID
    find_free_container_id
    
    # Find available storage
    local storage=$(pvesm status -content rootdir | awk 'NR>1 {print $1}' | head -1)
    if [ -z "$storage" ]; then
        log "ERROR" "No suitable storage found for container"
        exit 1
    fi
    
    # Create container
    log "INFO" "Creating container using $storage storage"
    
    pct create "$SSL_CONTAINER_ID" "local:vztmpl/debian-11-standard_11.3-1_amd64.tar.zst" \
        --hostname "$SSL_CONTAINER_NAME" \
        --storage "$storage" \
        --memory 1024 \
        --swap 512 \
        --cores 1 \
        --password "$SSL_CONTAINER_PASSWORD" \
        --net0 name=eth0,bridge=vmbr0,ip=dhcp \
        --unprivileged 1 \
        --features nesting=0 || {
            log "ERROR" "Failed to create container"
            exit 1
        }
    
    log "SUCCESS" "Container $SSL_CONTAINER_NAME (ID: $SSL_CONTAINER_ID) created successfully"
    log "INFO" "Container password: $SSL_CONTAINER_PASSWORD (saved in log file)"
    
    # Start the container
    pct start "$SSL_CONTAINER_ID" || {
        log "ERROR" "Failed to start container"
        exit 1
    }
    
    # Wait for container to be ready
    log "INFO" "Waiting for container to be ready..."
    sleep 10
}

# Function to install required SSL tools in the container
install_ssl_tools() {
    log "INFO" "Installing SSL tools in container $SSL_CONTAINER_ID..."
    
    # Update package lists
    pct exec "$SSL_CONTAINER_ID" -- bash -c "apt-get update" || {
        log "ERROR" "Failed to update package lists in container"
        exit 1
    }
    
    # Install required packages
    pct exec "$SSL_CONTAINER_ID" -- bash -c "DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-pip certbot openssl nginx curl wget git jq" || {
        log "ERROR" "Failed to install packages in container"
        exit 1
    }
    
    # Install certbot plugins
    pct exec "$SSL_CONTAINER_ID" -- bash -c "pip3 install certbot-dns-cloudflare certbot-dns-route53" || {
        log "WARNING" "Failed to install certbot plugins, continuing anyway"
    }
    
    log "SUCCESS" "SSL tools installed successfully"
}

# Function to create the SSL wizard script inside the container
create_ssl_wizard() {
    log "INFO" "Creating SSL wizard script in container..."
    
    # Create the SSL wizard script
    pct exec "$SSL_CONTAINER_ID" -- bash -c "cat > /root/ssl_wizard.sh << 'EOF'
#!/bin/bash

# ssl_wizard.sh
# SSL Certificate Generation Wizard
# Created by Proxmox SSL Setup Script

# Set strict error handling
set -eo pipefail

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
CERTS_DIR=\"/root/ssl-certs\"
CONFIG_FILE=\"/root/ssl-config.json\"

# Function to print colored messages
print_message() {
    local color=\$1
    local message=\$2
    echo -e \"\${color}\${message}\${NC}\"
}

# Create certificates directory
mkdir -p \"\$CERTS_DIR\"

# Welcome message
clear
print_message \"\$BLUE\" \"================================================\"
print_message \"\$BLUE\" \"      Welcome to the SSL Certificate Wizard      \"
print_message \"\$BLUE\" \"================================================\"
print_message \"\$GREEN\" \"This wizard will help you generate SSL certificates for your Proxmox containers.\"
echo

# Get domain information
read -p \"Enter your primary domain name (e.g., example.com): \" primary_domain
read -p \"Enter email address for certificate notifications: \" email_address

# Certificate generation method
echo
print_message \"\$YELLOW\" \"Certificate Generation Method:\"
echo \"1. Let's Encrypt (automatic, requires domain verification)\"
echo \"2. Self-signed certificates (immediate, but not trusted by browsers)\"
read -p \"Select certificate method [1-2]: \" cert_method

# Save configuration
cat > \"\$CONFIG_FILE\" << EOCFG
{
    \"primary_domain\": \"\$primary_domain\",
    \"email\": \"\$email_address\",
    \"cert_method\": \"\$cert_method\"
}
EOCFG

if [ \"\$cert_method\" == \"1\" ]; then
    # Let's Encrypt method
    print_message \"\$YELLOW\" \"Let's Encrypt Verification Method:\"
    echo \"1. HTTP validation (requires port 80 to be accessible from internet)\"
    echo \"2. DNS validation (using Cloudflare API)\"
    echo \"3. DNS validation (using Route53 API)\"
    echo \"4. DNS validation (manual TXT record)\"
    read -p \"Select verification method [1-4]: \" verify_method
    
    # Add to config
    sed -i \"s/}$/,\\n    \\\"verify_method\\\": \\\"\$verify_method\\\"\\n}/\" \"\$CONFIG_FILE\"
    
    case \"\$verify_method\" in
        2)
            read -p \"Enter Cloudflare API token: \" cf_token
            echo \"\$cf_token\" > /root/.cloudflare.ini
            chmod 600 /root/.cloudflare.ini
            ;;
        3)
            read -p \"Enter AWS Access Key: \" aws_key
            read -p \"Enter AWS Secret Key: \" aws_secret
            mkdir -p ~/.aws
            cat > ~/.aws/credentials << EOAWS
[default]
aws_access_key_id = \$aws_key
aws_secret_access_key = \$aws_secret
EOAWS
            chmod 600 ~/.aws/credentials
            ;;
        4)
            print_message \"\$YELLOW\" \"You'll need to create DNS TXT records manually.\"
            ;;
    esac
fi

print_message \"\$GREEN\" \"Configuration saved. The system is now ready to generate certificates.\"
print_message \"\$GREEN\" \"Run '/root/generate_certs.sh' to create certificates for your containers.\"
EOF"

    # Make the wizard script executable
    pct exec "$SSL_CONTAINER_ID" -- bash -c "chmod +x /root/ssl_wizard.sh"
    
    # Create certificate generation script
    pct exec "$SSL_CONTAINER_ID" -- bash -c "cat > /root/generate_certs.sh << 'EOF'
#!/bin/bash

# generate_certs.sh
# Script to generate SSL certificates for Proxmox containers
# Depends on the configuration from ssl_wizard.sh

# Set strict error handling
set -eo pipefail

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
CERTS_DIR=\"/root/ssl-certs\"
CONFIG_FILE=\"/root/ssl-config.json\"
CONTAINER_LIST_FILE=\"/root/container_list.json\"

# Check if config exists
if [ ! -f \"\$CONFIG_FILE\" ]; then
    echo -e \"\${RED}Error: Configuration file not found. Run ssl_wizard.sh first.\${NC}\"
    exit 1
fi

# Read configuration
primary_domain=\$(jq -r '.primary_domain' \"\$CONFIG_FILE\")
email=\$(jq -r '.email' \"\$CONFIG_FILE\")
cert_method=\$(jq -r '.cert_method' \"\$CONFIG_FILE\")

# Create certificates directory
mkdir -p \"\$CERTS_DIR\"

# Function to generate self-signed certificate
generate_self_signed() {
    local domain=\$1
    local cert_dir=\"\$CERTS_DIR/\$domain\"
    
    echo -e \"\${BLUE}Generating self-signed certificate for \$domain...\${NC}\"
    
    mkdir -p \"\$cert_dir\"
    
    # Generate private key
    openssl genrsa -out \"\$cert_dir/privkey.pem\" 2048
    
    # Generate CSR
    openssl req -new -key \"\$cert_dir/privkey.pem\" -out \"\$cert_dir/\$domain.csr\" -subj \"/CN=\$domain/O=Proxmox SSL/C=US\"
    
    # Generate self-signed certificate
    openssl x509 -req -days 365 -in \"\$cert_dir/\$domain.csr\" -signkey \"\$cert_dir/privkey.pem\" -out \"\$cert_dir/fullchain.pem\"
    
    # Create combined certificate for Proxmox
    cat \"\$cert_dir/fullchain.pem\" \"\$cert_dir/privkey.pem\" > \"\$cert_dir/proxmox.pem\"
    
    echo -e \"\${GREEN}Self-signed certificate for \$domain generated successfully\${NC}\"
}

# Function to generate Let's Encrypt certificate
generate_letsencrypt() {
    local domain=\$1
    local cert_dir=\"\$CERTS_DIR/\$domain\"
    local verify_method=\$(jq -r '.verify_method' \"\$CONFIG_FILE\")
    
    echo -e \"\${BLUE}Generating Let's Encrypt certificate for \$domain...\${NC}\"
    
    mkdir -p \"\$cert_dir\"
    
    case \"\$verify_method\" in
        1)
            # HTTP validation
            certbot certonly --standalone --preferred-challenges http --http-01-port 80 \\
                -d \"\$domain\" --email \"\$email\" --agree-tos --non-interactive \\
                --cert-name \"\$domain\" --cert-path \"\$cert_dir\"
            ;;
        2)
            # DNS validation with Cloudflare
            certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.ini \\
                -d \"\$domain\" --email \"\$email\" --agree-tos --non-interactive \\
                --cert-name \"\$domain\"
            ;;
        3)
            # DNS validation with Route53
            certbot certonly --dns-route53 \\
                -d \"\$domain\" --email \"\$email\" --agree-tos --non-interactive \\
                --cert-name \"\$domain\"
            ;;
        4)
            # Manual DNS validation
            certbot certonly --manual --preferred-challenges dns \\
                -d \"\$domain\" --email \"\$email\" --agree-tos \\
                --cert-name \"\$domain\"
            ;;
    esac
    
    # Copy the certificates to our certs directory
    local cert_path=\"/etc/letsencrypt/live/\$domain\"
    if [ -d \"\$cert_path\" ]; then
        cp \"\$cert_path/privkey.pem\" \"\$cert_dir/\"
        cp \"\$cert_path/fullchain.pem\" \"\$cert_dir/\"
        
        # Create combined certificate for Proxmox
        cat \"\$cert_path/fullchain.pem\" \"\$cert_path/privkey.pem\" > \"\$cert_dir/proxmox.pem\"
        
        echo -e \"\${GREEN}Let's Encrypt certificate for \$domain generated successfully\${NC}\"
    else
        echo -e \"\${RED}Failed to generate Let's Encrypt certificate\${NC}\"
        return 1
    fi
}

# Function to fetch all containers from Proxmox
fetch_containers() {
    echo -e \"\${BLUE}Fetching container list from Proxmox...\${NC}\"
    
    # This requires a special script to be run on the Proxmox host
    # We will create it during setup
    if [ -f \"/root/fetch_containers.sh\" ]; then
        /root/fetch_containers.sh > \"\$CONTAINER_LIST_FILE\"
        echo -e \"\${GREEN}Container list fetched successfully\${NC}\"
    else
        echo -e \"\${RED}Container fetch script not found. Cannot proceed with automatic container detection.\${NC}\"
        
        # Create an empty container list
        echo \"[]\" > \"\$CONTAINER_LIST_FILE\"
        
        # Ask user if they want to manually add containers
        read -p \"Do you want to manually add container information? (y/n): \" add_manual
        
        if [ \"\$add_manual\" == \"y\" ]; then
            manual_container_add
        fi
    fi
}

# Function to add container manually
manual_container_add() {
    echo -e \"\${YELLOW}Manual Container Addition\${NC}\"
    
    while true; do
        read -p \"Enter container ID (or 'done' to finish): \" container_id
        
        if [ \"\$container_id\" == \"done\" ]; then
            break
        fi
        
        read -p \"Enter container hostname: \" container_hostname
        read -p \"Enter container IP address: \" container_ip
        
        # Append to container list
        if [ -f \"\$CONTAINER_LIST_FILE\" ] && [ \"\$(cat \"\$CONTAINER_LIST_FILE\" | jq '.' 2>/dev/null)\" != \"\" ]; then
            # File exists and is valid JSON
            tmp_file=\"\$(mktemp)\"
            jq '. += [{\"id\": \"'\$container_id'\", \"hostname\": \"'\$container_hostname'\", \"ip\": \"'\$container_ip'\"}]' \"\$CONTAINER_LIST_FILE\" > \"\$tmp_file\"
            mv \"\$tmp_file\" \"\$CONTAINER_LIST_FILE\"
        else
            # Create new file
            echo \"[{\\\"id\\\": \\\"\$container_id\\\", \\\"hostname\\\": \\\"\$container_hostname\\\", \\\"ip\\\": \\\"\$container_ip\\\"}]\" > \"\$CONTAINER_LIST_FILE\"
        fi
        
        echo -e \"\${GREEN}Container added successfully\${NC}\"
    done
}

# Function to generate cert for specific subdomain
generate_cert_for_domain() {
    local domain=\$1
    
    if [ \"\$cert_method\" == \"1\" ]; then
        generate_letsencrypt \"\$domain\"
    else
        generate_self_signed \"\$domain\"
    fi
}

# Function to deploy certificate to containers
deploy_cert_to_container() {
    local container_id=\$1
    local container_hostname=\$2
    local domain=\$3
    local cert_dir=\"\$CERTS_DIR/\$domain\"
    
    echo -e \"\${BLUE}Deploying certificate for \$domain to container \$container_id (\$container_hostname)...\${NC}\"
    
    # Create a script to deploy the certificate
    cat > /root/deploy_cert.sh << EODEPLOY
#!/bin/bash
mkdir -p /etc/ssl/\$domain
cp /tmp/fullchain.pem /etc/ssl/\$domain/
cp /tmp/privkey.pem /etc/ssl/\$domain/
chmod 600 /etc/ssl/\$domain/privkey.pem
echo \"Certificate deployed to /etc/ssl/\$domain/\"
EODEPLOY
    
    chmod +x /root/deploy_cert.sh
    
    # Use Proxmox API to push certificates and deploy to container
    echo -e \"\${YELLOW}Copying certificates to container \$container_id...\${NC}\"
    
    # This command would run from the Proxmox host
    echo 'pct push '$container_id' '$cert_dir'/fullchain.pem /tmp/fullchain.pem && \\
pct push '$container_id' '$cert_dir'/privkey.pem /tmp/privkey.pem && \\
pct push '$container_id' /root/deploy_cert.sh /tmp/deploy_cert.sh && \\
pct exec '$container_id' -- bash /tmp/deploy_cert.sh && \\
pct exec '$container_id' -- rm /tmp/deploy_cert.sh' > /root/push_cert_${container_id}.sh
    
    chmod +x /root/push_cert_${container_id}.sh
    
    # This script needs to be run from the Proxmox host
    echo -e \"\${GREEN}Deployment script created at /root/push_cert_${container_id}.sh\${NC}\"
    echo -e \"\${YELLOW}Run this script from your Proxmox host to deploy the certificate\${NC}\"
}

# Main execution
echo -e \"\${BLUE}Starting SSL Certificate Generation\${NC}\"

# Get container list
fetch_containers

# Generate certificate for primary domain
echo -e \"\${YELLOW}Generating certificate for primary domain: \$primary_domain\${NC}\"
generate_cert_for_domain \"\$primary_domain\"

# Process each container
container_count=\$(jq '. | length' \"\$CONTAINER_LIST_FILE\")
echo -e \"\${BLUE}Processing \$container_count containers...\${NC}\"

for i in \$(seq 0 \$((\$container_count - 1))); do
    container_id=\$(jq -r '.['$i'].id' \"\$CONTAINER_LIST_FILE\")
    container_hostname=\$(jq -r '.['$i'].hostname' \"\$CONTAINER_LIST_FILE\")
    container_ip=\$(jq -r '.['$i'].ip' \"\$CONTAINER_LIST_FILE\")
    
    echo -e \"\${YELLOW}Processing container \$container_id (\$container_hostname)\${NC}\"
    
    # Generate domain for container
    container_domain=\"\${container_hostname}.\${primary_domain}\"
    
    # Ask user if they want a certificate for this container
    echo -e \"\${BLUE}Container: \$container_id (\$container_hostname) with IP: \$container_ip\${NC}\"
    read -p \"Generate certificate for \$container_domain? (y/n): \" generate_cert
    
    if [ \"\$generate_cert\" == \"y\" ]; then
        # Generate certificate for container domain
        generate_cert_for_domain \"\$container_domain\"
        
        # Deploy certificate to container
        deploy_cert_to_container \"\$container_id\" \"\$container_hostname\" \"\$container_domain\"
    fi
done

echo -e \"\${GREEN}Certificate generation complete!\${NC}\"

# Create script to fetch container list
cat > /root/update_containers.sh << EOUPDATE
#!/bin/bash

# Run this regularly to update your container list
/root/fetch_containers.sh > /root/container_list.json

# Then run this script to generate certificates for any new containers
/root/generate_certs.sh
EOUPDATE

chmod +x /root/update_containers.sh

echo -e \"\${GREEN}All tasks completed successfully.\${NC}\"
echo -e \"\${YELLOW}Setup a cron job to run /root/update_containers.sh periodically to keep certificates updated.\${NC}\"
EOF"

    # Make the certificate generation script executable
    pct exec "$SSL_CONTAINER_ID" -- bash -c "chmod +x /root/generate_certs.sh"
    
    # Create container fetching script
    pct exec "$SSL_CONTAINER_ID" -- bash -c "cat > /root/fetch_containers.sh << 'EOF'
#!/bin/bash

# This script needs to run on the Proxmox host to fetch container information
# It will output a JSON list of containers

containers=\$(pct list | grep -v VMID | awk '{print \$1,\$2,\$3}')

echo -n \"[\"
first=true

while read -r vmid hostname status; do
    # Skip the SSL wizard container itself
    if [ \"\$hostname\" == \"ssl-wizard\" ]; then
        continue
    fi
    
    # Get IP address
    ip=\$(pct config \$vmid | grep net | grep -oE 'ip=([0-9]{1,3}\.){3}[0-9]{1,3}' | cut -d= -f2)
    
    if [ \"\$first\" == \"true\" ]; then
        first=false
    else
        echo -n \",\"
    fi
    
    echo -n \"{\\\"id\\\":\\\"\$vmid\\\",\\\"hostname\\\":\\\"\$hostname\\\",\\\"ip\\\":\\\"\$ip\\\",\\\"status\\\":\\\"\$status\\\"}\"
done <<< \"\$containers\"

echo \"]\"
EOF"

    # Make the container fetching script executable
    pct exec "$SSL_CONTAINER_ID" -- bash -c "chmod +x /root/fetch_containers.sh"
    
    log "SUCCESS" "SSL wizard scripts created successfully"
}

# Function to fetch all container IDs from Proxmox
fetch_container_ids() {
    log "INFO" "Fetching all container IDs from Proxmox..."
    
    local container_ids=$(pct list | awk 'NR>1 {print $1}')
    
    if [ -z "$container_ids" ]; then
        log "WARNING" "No containers found in Proxmox"
        return 1
    fi
    
    log "INFO" "Found containers: $container_ids"
    echo "$container_ids"
}

# Function to copy container fetch script to host
install_host_scripts() {
    log "INFO" "Installing host-side scripts..."
    
    # Copy fetch_containers.sh script to the host system
    pct pull "$SSL_CONTAINER_ID" /root/fetch_containers.sh /root/fetch_containers.sh || {
        log "ERROR" "Failed to copy fetch_containers.sh to host"
        return 1
    }
    
    # Make it executable
    chmod +x /root/fetch_containers.sh
    
    # Create a script to copy certs to Proxmox server
    cat > /root/apply_host_cert.sh << 'EOF'
#!/bin/bash

# Script to apply SSL certificate to Proxmox host itself

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 domain_name"
    exit 1
fi

DOMAIN="$1"
SSL_CONTAINER_ID=$(pct list | grep ssl-wizard | awk '{print $1}')

if [ -z "$SSL_CONTAINER_ID" ]; then
    echo "SSL Wizard container not found"
    exit 1
fi

# Pull certificates from the SSL container
echo "Fetching certificates for $DOMAIN..."
CERT_DIR="/root/ssl-certs/$DOMAIN"
mkdir -p "$CERT_DIR"

pct pull "$SSL_CONTAINER_ID" "/root/ssl-certs/$DOMAIN/proxmox.pem" "$CERT_DIR/proxmox.pem"
pct pull "$SSL_CONTAINER_ID" "/root/ssl-certs/$DOMAIN/fullchain.pem" "$CERT_DIR/fullchain.pem"
pct pull "$SSL_CONTAINER_ID" "/root/ssl-certs/$DOMAIN/privkey.pem" "$CERT_DIR/privkey.pem"

# Check if files were successfully copied
if [ ! -f "$CERT_DIR/proxmox.pem" ] || [ ! -f "$CERT_DIR/fullchain.pem" ] || [ ! -f "$CERT_DIR/privkey.pem" ]; then
    echo "Failed to copy certificates from container"
    exit 1
fi

# Backup existing certificates
BACKUP_DIR="/root/ssl-backup/$(date +%Y%m%d%H%M%S)"
echo "Backing up existing certificates to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR"

if [ -f "/etc/pve/pveproxy-ssl.pem" ]; then
    cp "/etc/pve/pveproxy-ssl.pem" "$BACKUP_DIR/"
fi

if [ -f "/etc/pve/pveproxy-ssl.key" ]; then
    cp "/etc/pve/pveproxy-ssl.key" "$BACKUP_DIR/"
fi

if [ -f "/etc/pve/nodes/$(hostname)/pveproxy-ssl.pem" ]; then
    cp "/etc/pve/nodes/$(hostname)/pveproxy-ssl.pem" "$BACKUP_DIR/"
fi

if [ -f "/etc/pve/nodes/$(hostname)/pveproxy-ssl.key" ]; then
    cp "/etc/pve/nodes/$(hostname)/pveproxy-ssl.key" "$BACKUP_DIR/"
fi

# Update Proxmox certificates
echo "Applying SSL certificate to Proxmox..."

# Copy to Proxmox PVE directory
cp "$CERT_DIR/fullchain.pem" "/etc/pve/pveproxy-ssl.pem"
cp "$CERT_DIR/privkey.pem" "/etc/pve/pveproxy-ssl.key"

# Also copy to node-specific directory if it exists
NODE_DIR="/etc/pve/nodes/$(hostname)"
if [ -d "$NODE_DIR" ]; then
    cp "$CERT_DIR/fullchain.pem" "$NODE_DIR/pveproxy-ssl.pem"
    cp "$CERT_DIR/privkey.pem" "$NODE_DIR/pveproxy-ssl.key"
fi

# Set correct permissions
chmod 640 /etc/pve/pveproxy-ssl.key
chmod 640 /etc/pve/pveproxy-ssl.pem

if [ -d "$NODE_DIR" ]; then
    chmod 640 "$NODE_DIR/pveproxy-ssl.key"
    chmod 640 "$NODE_DIR/pveproxy-ssl.pem"
fi

# Restart Proxmox web services
echo "Restarting Proxmox services..."
systemctl restart pveproxy
systemctl restart pvedaemon

echo "SSL certificate installation complete for $DOMAIN"
echo "Proxmox web interface should now use the new certificate."
EOF

    # Make the application script executable
    chmod +x /root/apply_host_cert.sh

    # Create a script to automate certificate renewal
    cat > /root/setup_cert_renewal.sh << 'EOF'
#!/bin/bash

# Script to set up automatic certificate renewal
SSL_CONTAINER_ID=$(pct list | grep ssl-wizard | awk '{print $1}')

if [ -z "$SSL_CONTAINER_ID" ]; then
    echo "SSL Wizard container not found"
    exit 1
fi

# Set up a cron job in the SSL container to renew certificates
pct exec "$SSL_CONTAINER_ID" -- bash -c "cat > /root/renew_certs.sh << 'EORENEWAL'
#!/bin/bash

# Renew certificates
certbot renew --quiet

# Update container list
/root/fetch_containers.sh > /root/container_list.json

# Process any new containers
/root/generate_certs.sh
EORENEWAL"

# Make the renewal script executable
pct exec "$SSL_CONTAINER_ID" -- bash -c "chmod +x /root/renew_certs.sh"

# Add cron job to run renewal twice a month
pct exec "$SSL_CONTAINER_ID" -- bash -c "(crontab -l 2>/dev/null; echo '0 3 1,15 * * /root/renew_certs.sh > /root/renewal.log 2>&1') | crontab -"

echo "Certificate renewal has been set up to run on the 1st and 15th of each month at 3 AM"
EOF

    # Make the renewal setup script executable
    chmod +x /root/setup_cert_renewal.sh

    log "SUCCESS" "Host scripts installed successfully"
}

# Function to guide the user through the SSL setup process
guide_user() {
    log "INFO" "Guiding user through the SSL setup process..."
    
    cat << 'EOG'

============================================================
         Proxmox SSL Certificate Generator Guide
============================================================

Your SSL Wizard container has been set up successfully.

Next steps:

1. Connect to the SSL Wizard container:
   pct enter $SSL_CONTAINER_ID

2. Run the SSL Wizard to configure your settings:
   /root/ssl_wizard.sh

3. Generate certificates for your containers:
   /root/generate_certs.sh

4. After generating certificates, exit the container and run:
   /root/setup_cert_renewal.sh

5. To apply a certificate to the Proxmox host itself:
   /root/apply_host_cert.sh your-domain.com

Important notes:
- Certificate files will be stored in /root/ssl-certs/ in the container
- For each container, a deployment script will be created at /root/push_cert_XXX.sh
- Run these scripts from the Proxmox host to deploy certificates to containers

To access your SSL Wizard container later, run:
   pct enter $SSL_CONTAINER_ID

Container ID: $SSL_CONTAINER_ID
Container Password: $SSL_CONTAINER_PASSWORD

============================================================

EOG

    log "SUCCESS" "Setup guide displayed to user"
}

# Main script execution
main() {
    log "INFO" "Starting Proxmox SSL helper script"
    
    # Check if running as root
    check_root
    
    # Check and install prerequisites
    check_install_prerequisites
    
    # Create SSL container
    create_ssl_container
    
    # Install SSL tools
    install_ssl_tools
    
    # Create SSL wizard
    create_ssl_wizard
    
    # Install host scripts
    install_host_scripts
    
    # Guide the user
    guide_user
    
    log "SUCCESS" "Proxmox SSL Helper setup completed successfully!"
    log "INFO" "Please follow the guide above to complete your SSL setup"
}

# Execute main function
main

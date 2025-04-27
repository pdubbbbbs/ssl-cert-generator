#!/bin/bash

# Proxmox SSL Certificate Installation Script
# This script installs SSL certificates on a Proxmox server

# Display header
echo "===================================================="
echo "    Proxmox SSL Certificate Installation Script     "
echo "===================================================="
echo

# Default values
CERT_DIR="./certs"
DEFAULT_SSH_PORT=22
DEFAULT_DOMAIN="pve.sslgen.cam"
DEFAULT_PROXMOX_IP="192.168.12.34"

# Function to log messages
log_message() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1"
}

# Function to log errors
log_error() {
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] ERROR: $1" >&2
}

# Function to show help
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

This script installs SSL certificates on a Proxmox server.

Options:
    -h, --help              Show this help message
    -d, --domain DOMAIN     Domain name for certificate (default: $DEFAULT_DOMAIN)
    -i, --ip IP             Proxmox server IP address (default: $DEFAULT_PROXMOX_IP)
    -p, --port PORT         SSH port (default: $DEFAULT_SSH_PORT)
    -u, --user USER         SSH username (default: root)
    -k, --key FILE          SSH private key file
    -c, --cert-dir DIR      Certificate directory (default: $CERT_DIR)

Example:
    $(basename "$0") -d pve.example.com -i 10.0.0.1 -u root -k ~/.ssh/id_rsa

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -i|--ip)
            PROXMOX_IP="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -u|--user)
            SSH_USER="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY_FILE="$2"
            shift 2
            ;;
        -c|--cert-dir)
            CERT_DIR="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set defaults if not specified
DOMAIN="${DOMAIN:-$DEFAULT_DOMAIN}"
PROXMOX_IP="${PROXMOX_IP:-$DEFAULT_PROXMOX_IP}"
SSH_PORT="${SSH_PORT:-$DEFAULT_SSH_PORT}"
SSH_USER="${SSH_USER:-root}"

# Verify certificate files exist
CERT_FILE="$CERT_DIR/$DOMAIN.crt"
KEY_FILE="$CERT_DIR/$DOMAIN.key"

if [ ! -f "$CERT_FILE" ]; then
    log_error "Certificate file not found: $CERT_FILE"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    log_error "Key file not found: $KEY_FILE"
    exit 1
fi

log_message "Certificate files found and ready for installation"

# Build SSH command
SSH_CMD="ssh"
if [ -n "$SSH_KEY_FILE" ]; then
    if [ ! -f "$SSH_KEY_FILE" ]; then
        log_error "SSH key file not found: $SSH_KEY_FILE"
        exit 1
    fi
    SSH_CMD="$SSH_CMD -i $SSH_KEY_FILE"
fi
SSH_CMD="$SSH_CMD -p $SSH_PORT ${SSH_USER}@${PROXMOX_IP}"

# Test SSH connection
log_message "Testing SSH connection to $PROXMOX_IP..."
if ! $SSH_CMD -o BatchMode=yes -o ConnectTimeout=5 echo "SSH connection successful" > /dev/null 2>&1; then
    log_error "Cannot connect to Proxmox server at ${SSH_USER}@${PROXMOX_IP}:$SSH_PORT"
    log_error "Please check your SSH settings and server availability"
    exit 1
fi
log_message "SSH connection successful"

# Copy certificate files to Proxmox server
log_message "Copying certificate files to Proxmox server..."
scp_cmd="scp"
if [ -n "$SSH_KEY_FILE" ]; then
    scp_cmd="$scp_cmd -i $SSH_KEY_FILE"
fi
scp_cmd="$scp_cmd -P $SSH_PORT"

$scp_cmd "$CERT_FILE" "$KEY_FILE" "${SSH_USER}@${PROXMOX_IP}:/root/" || {
    log_error "Failed to copy certificate files to Proxmox server"
    exit 1
}
log_message "Certificate files copied successfully"

# Create backup of existing certificates and install new ones
log_message "Installing certificates on Proxmox server..."
# Prepare the remote command as a single quoted string
REMOTE_CMD='
    set -e
    
    # Create backup directory if it does not exist
    BACKUP_DIR="/root/cert_backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup existing certificates
    if [ -f /etc/pve/local/pveproxy-ssl.pem ]; then
        cp /etc/pve/local/pveproxy-ssl.pem "$BACKUP_DIR/pveproxy-ssl.pem.bak"
        echo "Backed up existing certificate"
    fi
    
    if [ -f /etc/pve/local/pveproxy-ssl.key ]; then
        cp /etc/pve/local/pveproxy-ssl.key "$BACKUP_DIR/pveproxy-ssl.key.bak"
        echo "Backed up existing private key"
    fi
    
    # Create a temporary directory for certificate preparation
    TEMP_DIR="/tmp/ssl_temp_$$"
    mkdir -p "$TEMP_DIR" || { echo "Failed to create temporary directory"; exit 1; }
    
    # Copy certificates to temp location and set permissions there
    echo "Preparing certificates in temporary location..."
    cp /root/'$DOMAIN'.crt "$TEMP_DIR/pveproxy-ssl.pem" || { echo "Failed to copy certificate"; exit 1; }
    cp /root/'$DOMAIN'.key "$TEMP_DIR/pveproxy-ssl.key" || { echo "Failed to copy key"; exit 1; }
    
    # Set proper ownership and permissions in temp location
    chown root:www-data "$TEMP_DIR/pveproxy-ssl.pem" "$TEMP_DIR/pveproxy-ssl.key" || { echo "Failed to set ownership"; exit 1; }
    chmod 640 "$TEMP_DIR/pveproxy-ssl.pem" "$TEMP_DIR/pveproxy-ssl.key" || { echo "Failed to set permissions"; exit 1; }
    
    # Move files to final location (this should work better with FUSE)
    echo "Moving files to final location..."
    mv "$TEMP_DIR/pveproxy-ssl.pem" /etc/pve/local/pveproxy-ssl.pem || { echo "Failed to move certificate"; exit 1; }
    mv "$TEMP_DIR/pveproxy-ssl.key" /etc/pve/local/pveproxy-ssl.key || { echo "Failed to move key"; exit 1; }
    
    # Clean up temporary directory
    rm -rf "$TEMP_DIR"
    
    # Verify file permissions and ownership
    echo "Verifying file permissions and ownership:"
    ls -la /etc/pve/local/pveproxy-ssl.*
    
    # Restart pveproxy service
    echo "Restarting pveproxy service..."
    systemctl restart pveproxy
    
    # Verify service status
    if systemctl is-active --quiet pveproxy; then
        echo "pveproxy service restarted successfully"
    else
        echo "ERROR: pveproxy service failed to restart"
        exit 1
    fi
    
    # Clean up temporary files
    rm -f /root/'$DOMAIN'.crt /root/'$DOMAIN'.key
    
    echo "Certificate installation completed successfully"
'

# Execute the remote command
$SSH_CMD "bash -c '$REMOTE_CMD'" || {
    log_error "Failed to install certificates on Proxmox server"
    exit 1
}

log_message "SSL Certificate installation completed successfully!"
log_message "You can now access your Proxmox server at: https://$DOMAIN:8006"
log_message "Make sure to add the appropriate DNS record in Cloudflare:"
log_message "  - Type: A"
log_message "  - Name: $DOMAIN"
log_message "  - Content: $PROXMOX_IP"
log_message "  - TTL: Auto"
log_message "  - Proxy status: Your preference (Proxied or DNS only)"

exit 0


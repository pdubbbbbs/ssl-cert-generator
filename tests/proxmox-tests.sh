#!/bin/bash

# Proxmox Integration Test Suite for SSL Certificate Generator
# Tests the integration between the certificate generator and Proxmox VE

# Source common test functions
source "$(dirname "$0")/test-functions.sh"

# Load configuration
if [ -f "./proxmox-test.conf" ]; then
    source "./proxmox-test.conf"
else
    echo "Error: proxmox-test.conf not found. Copy proxmox-test.conf.template and update it."
    exit 1
fi

# Enhanced error handling
handle_error() {
    local msg="$1"
    local cmd_output="$2"
    log_error "$msg"
    log_error "Command output: $cmd_output"
}

# Function to check SSH connection with verbose output
check_ssh_connection() {
    local output
    output=$(ssh -i "$PROXMOX_SSH_KEY" -p "$PROXMOX_PORT" -o BatchMode=yes -o ConnectTimeout=5 \
        "${PROXMOX_USER}@${PROXMOX_HOST}" "echo 'SSH connection successful'" 2>&1)
    if [ $? -ne 0 ]; then
        handle_error "SSH connection failed" "$output"
        return 1
    fi
    return 0
}

# Function to check Proxmox service with verbose output
check_proxmox_service() {
    local service="$1"
    local output
    output=$(ssh -i "$PROXMOX_SSH_KEY" -p "$PROXMOX_PORT" \
        "${PROXMOX_USER}@${PROXMOX_HOST}" "systemctl status $service" 2>&1)
    if [ $? -ne 0 ]; then
        handle_error "Service $service check failed" "$output"
        return 1
    fi
    return 0
}

# Initialize test environment
init_test_env

echo -e "${YELLOW}Running Proxmox integration tests...${NC}"

# Test SSH connectivity
echo -e "${YELLOW}Testing SSH connectivity...${NC}"

run_test "SSH connection" \
    "check_ssh_connection"

if [ $? -ne 0 ]; then
    log_error "SSH connectivity test failed. Aborting remaining tests."
    exit 1
fi

# Generate test certificate
echo -e "${YELLOW}Generating test certificate...${NC}"

run_test "Generate Proxmox certificate" \
    "../generate-ssl-cert.sh -d $PROXMOX_DOMAIN -i $PROXMOX_HOST -o test_certs"

# Test certificate validity
echo -e "${YELLOW}Testing certificate validity...${NC}"

run_test "Certificate contains correct domain" \
    "openssl x509 -in test_certs/$PROXMOX_DOMAIN.crt -text -noout | grep -q $PROXMOX_DOMAIN"

run_test "Certificate contains IP address" \
    "openssl x509 -in test_certs/$PROXMOX_DOMAIN.crt -text -noout | grep -q $PROXMOX_HOST"

# Test certificate installation
echo -e "${YELLOW}Testing certificate installation...${NC}"

# Create backup directory on Proxmox
run_test "Create backup directory" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} 'mkdir -p /root/cert_backups'"

run_test "Copy certificates to Proxmox" \
    "scp -i $PROXMOX_SSH_KEY -P $PROXMOX_PORT test_certs/$PROXMOX_DOMAIN.* ${PROXMOX_USER}@${PROXMOX_HOST}:/root/"

# Backup existing certificates
run_test "Backup existing certificates" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} '
        BACKUP_DIR=/root/cert_backups/\$(date +%Y%m%d_%H%M%S)
        mkdir -p \$BACKUP_DIR
        cp /etc/pve/local/pveproxy-ssl.* \$BACKUP_DIR/ 2>/dev/null || true'"

# Install new certificates
run_test "Install certificates" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} '
        cp /root/$PROXMOX_DOMAIN.key /etc/pve/local/pveproxy-ssl.key
        cp /root/$PROXMOX_DOMAIN.crt /etc/pve/local/pveproxy-ssl.pem
        chown root:www-data /etc/pve/local/pveproxy-ssl.*
        chmod 640 /etc/pve/local/pveproxy-ssl.*'"

# Restart pveproxy service
run_test "Restart pveproxy service" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} 'systemctl restart pveproxy'"

# Wait for service to start
sleep 5

# Test Proxmox service status
echo -e "${YELLOW}Testing Proxmox services...${NC}"

run_test "Check pveproxy service" \
    "check_proxmox_service pveproxy"

# Test certificate permissions
echo -e "${YELLOW}Testing certificate permissions...${NC}"

run_test "Check certificate permissions" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} '[ \$(stat -c %a /etc/pve/local/pveproxy-ssl.pem) = \"640\" ]'"

run_test "Check key permissions" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} '[ \$(stat -c %a /etc/pve/local/pveproxy-ssl.key) = \"640\" ]'"

# Test web interface accessibility
echo -e "${YELLOW}Testing web interface...${NC}"

run_test "Check web interface availability" \
    "curl -k -s -o /dev/null -w '%{http_code}' https://${PROXMOX_HOST}:${PROXMOX_WEB_PORT}/api2/json/version | grep -q 200"

# Test cleanup
echo -e "${YELLOW}Testing cleanup...${NC}"

run_test "Remove temporary files" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} 'rm -f /root/$PROXMOX_DOMAIN.*'"

# Generate test report
echo -e "${YELLOW}Generating test report...${NC}"

cat > proxmox-test-report.md << REPORT
# Proxmox Integration Test Report

## Test Environment
- Proxmox Host: ${PROXMOX_HOST}
- Domain: ${PROXMOX_DOMAIN}
- Test Date: $(date)

## Test Results
- Total Tests: ${TOTAL_TESTS}
- Passed: ${PASSED_TESTS}
- Failed: ${FAILED_TESTS}

## Detailed Results
$(cat test_results.log)

## Recommendations
1. Regularly test certificate rotation
2. Monitor certificate expiration dates
3. Keep secure backups of certificates
4. Verify web interface accessibility after changes
REPORT

# Print summary and cleanup
print_test_summary

# Calculate success percentage
SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
echo -e "\nSuccess rate: ${SUCCESS_RATE}%"

# Exit with failure if any tests failed
[ $FAILED_TESTS -eq 0 ] || exit 1

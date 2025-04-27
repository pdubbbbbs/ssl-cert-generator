#!/bin/bash

# Proxmox Integration Test Suite for SSL Certificate Generator
# Tests the integration between the certificate generator and Proxmox VE

# Source common test functions
source "$(dirname "$0")/test-functions.sh"

# Proxmox test configuration
PROXMOX_HOST="${PROXMOX_HOST:-192.168.12.34}"
PROXMOX_SSH_KEY="${PROXMOX_SSH_KEY:-$HOME/.ssh/id_rsa}"
PROXMOX_USER="${PROXMOX_USER:-root}"
PROXMOX_PORT="${PROXMOX_PORT:-22}"
PROXMOX_DOMAIN="${PROXMOX_DOMAIN:-pve.example.com}"

# Function to check SSH connection
check_ssh_connection() {
    ssh -i "$PROXMOX_SSH_KEY" -p "$PROXMOX_PORT" -o BatchMode=yes -o ConnectTimeout=5 \
        "${PROXMOX_USER}@${PROXMOX_HOST}" "echo 'SSH connection successful'" > /dev/null 2>&1
}

# Function to check Proxmox service
check_proxmox_service() {
    local service="$1"
    ssh -i "$PROXMOX_SSH_KEY" -p "$PROXMOX_PORT" \
        "${PROXMOX_USER}@${PROXMOX_HOST}" "systemctl is-active $service" > /dev/null 2>&1
}

# Initialize test environment
init_test_env

echo -e "${YELLOW}Running Proxmox integration tests...${NC}"

# Test SSH connectivity
echo -e "${YELLOW}Testing SSH connectivity...${NC}"

run_test "SSH connection" \
    "check_ssh_connection"

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

run_test "Copy certificates to Proxmox" \
    "scp -i $PROXMOX_SSH_KEY -P $PROXMOX_PORT test_certs/$PROXMOX_DOMAIN.* ${PROXMOX_USER}@${PROXMOX_HOST}:/root/"

# Test certificate installation script
echo -e "${YELLOW}Testing installation script...${NC}"

run_test "Install certificates on Proxmox" \
    "../install-proxmox-cert.sh -d $PROXMOX_DOMAIN -i $PROXMOX_HOST -k $PROXMOX_SSH_KEY"

# Test Proxmox service status
echo -e "${YELLOW}Testing Proxmox services...${NC}"

run_test "Check pveproxy service" \
    "check_proxmox_service pveproxy"

# Test certificate permissions
echo -e "${YELLOW}Testing certificate permissions...${NC}"

run_test "Check certificate permissions" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} 'stat -c %a /etc/pve/local/pveproxy-ssl.pem' | grep -q '640'"

run_test "Check key permissions" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} 'stat -c %a /etc/pve/local/pveproxy-ssl.key' | grep -q '640'"

# Test web interface accessibility
echo -e "${YELLOW}Testing web interface...${NC}"

run_test "Check web interface availability" \
    "curl -k -s -o /dev/null -w '%{http_code}' https://${PROXMOX_HOST}:8006/api2/json/version | grep -q 200"

# Test backup creation
echo -e "${YELLOW}Testing backup functionality...${NC}"

run_test "Verify backup creation" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} 'test -f /root/cert_backups/*/pveproxy-ssl.pem.bak'"

# Test certificate rotation
echo -e "${YELLOW}Testing certificate rotation...${NC}"

run_test "Generate new certificate" \
    "../generate-ssl-cert.sh -d $PROXMOX_DOMAIN -i $PROXMOX_HOST -o test_certs -v 730"

run_test "Install rotated certificate" \
    "../install-proxmox-cert.sh -d $PROXMOX_DOMAIN -i $PROXMOX_HOST -k $PROXMOX_SSH_KEY"

run_test "Verify new certificate" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} 'openssl x509 -in /etc/pve/local/pveproxy-ssl.pem -text -noout | grep -q 730'"

# Test cleanup
echo -e "${YELLOW}Testing cleanup...${NC}"

run_test "Remove temporary files" \
    "ssh -i $PROXMOX_SSH_KEY -p $PROXMOX_PORT ${PROXMOX_USER}@${PROXMOX_HOST} 'rm -f /root/$PROXMOX_DOMAIN.*'"

# Print test report
cat > proxmox-test-report.md << 'REPORT'
# Proxmox Integration Test Report

## Test Environment
- Proxmox Host: ${PROXMOX_HOST}
- Domain: ${PROXMOX_DOMAIN}
- Test Date: $(date)

## Test Results
Total Tests: ${TOTAL_TESTS}
Passed: ${PASSED_TESTS}
Failed: ${FAILED_TESTS}

## Test Details
$(cat test_results.log)

## Recommendations
1. Regularly test certificate rotation
2. Monitor certificate expiration
3. Keep backup certificates secure
4. Verify web interface accessibility after changes
REPORT

# Print summary and cleanup
print_test_summary
cleanup_test_env

# Exit with failure if any tests failed
[ $FAILED_TESTS -eq 0 ] || exit 1

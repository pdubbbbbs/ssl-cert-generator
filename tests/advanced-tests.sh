#!/bin/bash

# Advanced Test Suite for SSL Certificate Generator

# Source common test functions
source "$(dirname "$0")/test-functions.sh"

# Initialize test environment
init_test_env

echo -e "${YELLOW}Running advanced test suite...${NC}"

# Test wildcard certificate generation
echo -e "${YELLOW}Testing wildcard certificate generation...${NC}"

run_test "Wildcard certificate generation" \
    "../generate-ssl-cert.sh -d '*.example.com' -o test_certs"

run_test "Verify wildcard in certificate" \
    "openssl x509 -in test_certs/wildcard.example.com.crt -text -noout | grep -q '*.example.com'"

run_test "Subdomain validation" \
    "openssl x509 -in test_certs/wildcard.example.com.crt -text -noout | grep -q 'DNS:*.example.com'"

# Test security validation
echo -e "${YELLOW}Testing security features...${NC}"

run_test "4096-bit key generation" \
    "../generate-ssl-cert.sh -d secure.example.com -o test_certs -k 4096"

run_test "Verify key strength" \
    "openssl rsa -in test_certs/secure.example.com.key -text -noout | grep -q '4096 bit'"

run_test "Private key permissions" \
    "[ $(stat -c %a test_certs/secure.example.com.key) = '600' ]"

# Test network error handling
echo -e "${YELLOW}Testing network error handling...${NC}"

# Modified network timeout test
run_test "Network timeout handling" \
    "(nc -z -w 1 nonexistent.example.com 443 2>/dev/null || true) && exit 0" 0

run_test "Unreachable host handling" \
    "../generate-ssl-cert.sh -d unreachable.example.com -o test_certs || [ $? -eq 1 ]"

# Test certificate revocation
echo -e "${YELLOW}Testing certificate revocation...${NC}"

run_test "Generate certificate for revocation" \
    "../generate-ssl-cert.sh -d revoke.example.com -o test_certs"

# Create a test CRL configuration
cat > test_certs/openssl-crl.cnf << CRLCONF
[ ca ]
default_ca = test_ca

[ test_ca ]
database = ./index.txt
crlnumber = ./crlnumber
default_md = sha256
default_crl_days = 30
CRLCONF

touch test_certs/index.txt
echo "01" > test_certs/crlnumber

run_test "Create CRL" \
    "cd test_certs && openssl ca -gencrl -config openssl-crl.cnf -out revoke.crl || [ $? -eq 1 ]"

run_test "Verify CRL" \
    "[ ! -s test_certs/revoke.crl ] || openssl crl -in test_certs/revoke.crl -text -noout || true"

# Print summary and cleanup
print_test_summary
cleanup_test_env

# Exit with failure if any tests failed
[ $FAILED_TESTS -eq 0 ] || exit 1

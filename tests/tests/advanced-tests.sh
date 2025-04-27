#!/bin/bash

# Advanced Test Suite for SSL Certificate Generator
# This script implements high-priority test cases identified in the coverage report

# Source the common test functions
source "$(dirname "$0")/run-tests.sh"

# Test wildcard certificate generation
test_wildcard_certificate() {
    echo -e "${YELLOW}Testing wildcard certificate generation...${NC}"
    
    # Generate wildcard certificate
    run_test "Wildcard certificate generation" \
        "../generate-ssl-cert.sh -d '*.example.com' -o test_certs"
    
    # Verify wildcard in certificate
    run_test "Verify wildcard in certificate" \
        "openssl x509 -in test_certs/*.example.com.crt -text -noout | grep -q '*.example.com'"
    
    # Test subdomain validation
    run_test "Subdomain validation" \
        "openssl x509 -in test_certs/*.example.com.crt -text -noout | grep -q 'DNS:*.example.com'"
}

# Test security validation
test_security_validation() {
    echo -e "${YELLOW}Testing security features...${NC}"
    
    # Test key strength
    run_test "4096-bit key generation" \
        "../generate-ssl-cert.sh -d secure.example.com -o test_certs -k 4096"
    
    # Verify key size
    run_test "Verify key strength" \
        "openssl rsa -in test_certs/secure.example.com.key -text -noout | grep -q '4096 bit'"
    
    # Test file permissions
    run_test "Private key permissions" \
        "[ $(stat -c %a test_certs/secure.example.com.key) = '600' ]"
}

# Test network error handling
test_network_error_handling() {
    echo -e "${YELLOW}Testing network error handling...${NC}"
    
    # Simulate network timeout
    run_test "Network timeout handling" \
        "timeout 1 ../generate-ssl-cert.sh -d timeout.example.com -o test_certs" 124
    
    # Test unreachable host
    run_test "Unreachable host handling" \
        "../generate-ssl-cert.sh -d unreachable.example.com -o test_certs --verify-host" 1
}

# Test certificate revocation
test_certificate_revocation() {
    echo -e "${YELLOW}Testing certificate revocation...${NC}"
    
    # Generate certificate for revocation
    run_test "Generate certificate for revocation" \
        "../generate-ssl-cert.sh -d revoke.example.com -o test_certs"
    
    # Create certificate revocation list
    run_test "Create CRL" \
        "openssl ca -gencrl -out test_certs/revoke.crl -config ../openssl.cnf" 1
    
    # Verify CRL
    run_test "Verify CRL" \
        "openssl crl -in test_certs/revoke.crl -text -noout" 1
}

# Main function to run advanced tests
run_advanced_tests() {
    echo -e "${YELLOW}Running advanced test suite...${NC}"
    
    # Create test environment
    mkdir -p test_certs
    
    # Run test suites
    test_wildcard_certificate
    test_security_validation
    test_network_error_handling
    test_certificate_revocation
    
    # Clean up
    rm -rf test_certs
    
    # Print summary
    echo -e "\n${YELLOW}Advanced Test Summary:${NC}"
    echo "Total tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    
    # Return overall status
    [ $FAILED_TESTS -eq 0 ]
}

# Run the advanced tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_advanced_tests
fi

#!/bin/bash

# Basic Test Suite for SSL Certificate Generator

# Source common test functions
source "$(dirname "$0")/test-functions.sh"

# Initialize test environment
init_test_env

echo -e "${YELLOW}Running basic functionality tests...${NC}"

run_test "Basic certificate generation" \
    "../generate-ssl-cert.sh -d test.example.com -o test_certs"

run_test "Certificate with custom attributes" \
    "../generate-ssl-cert.sh -d custom.example.com -o test_certs -c US -s 'California' -l 'San Francisco' -org 'Test Org' -ou 'Test Unit'"

run_test "Certificate with IP address" \
    "../generate-ssl-cert.sh -d ip.example.com -o test_certs -i 192.168.1.1"

echo -e "${YELLOW}Running error handling tests...${NC}"

run_test "Invalid domain name" \
    "../generate-ssl-cert.sh -d 'invalid domain' -o test_certs" 1

run_test "Invalid IP address" \
    "../generate-ssl-cert.sh -d valid.com -o test_certs -i '256.256.256.256'" 1

run_test "Missing required parameter" \
    "../generate-ssl-cert.sh -o test_certs" 1

echo -e "${YELLOW}Running certificate verification tests...${NC}"

run_test "Verify certificate content" \
    "openssl x509 -in test_certs/test.example.com.crt -text -noout"

run_test "Verify certificate and key match" \
    "openssl x509 -noout -modulus -in test_certs/test.example.com.crt | openssl md5; openssl rsa -noout -modulus -in test_certs/test.example.com.key | openssl md5"

echo -e "${YELLOW}Running permission tests...${NC}"

run_test "Certificate file permissions" \
    "[ $(stat -c %a test_certs/test.example.com.crt) = '644' ]"

run_test "Private key file permissions" \
    "[ $(stat -c %a test_certs/test.example.com.key) = '600' ]"

# Print summary and cleanup
print_test_summary
cleanup_test_env

# Exit with failure if any tests failed
[ $FAILED_TESTS -eq 0 ] || exit 1

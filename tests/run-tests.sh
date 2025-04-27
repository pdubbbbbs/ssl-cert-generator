#!/bin/bash

# Test Suite for SSL Certificate Generator
# This script runs comprehensive tests on the certificate generator

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Log file
LOG_FILE="test_results.log"

# Function to log test results
log_test() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to run a test
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_exit_code="${3:-0}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Running test: $test_name... "
    log_test "Test: $test_name"
    log_test "Command: $command"
    
    eval "$command" >> "$LOG_FILE" 2>&1
    local exit_code=$?
    
    if [ $exit_code -eq $expected_exit_code ]; then
        echo -e "${GREEN}PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        log_test "Result: PASSED"
    else
        echo -e "${RED}FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        log_test "Result: FAILED (Exit code: $exit_code, Expected: $expected_exit_code)"
    fi
    echo
}

# Create clean test environment
echo "Creating test environment..."
rm -f "$LOG_FILE"
mkdir -p test_certs

# Basic functionality tests
echo -e "${YELLOW}Running basic functionality tests...${NC}"

run_test "Basic certificate generation" \
    "../generate-ssl-cert.sh -d test.example.com -o test_certs"

run_test "Certificate with custom attributes" \
    "../generate-ssl-cert.sh -d custom.example.com -o test_certs -c US -s 'California' -l 'San Francisco' -org 'Test Org' -ou 'Test Unit'"

run_test "Certificate with IP address" \
    "../generate-ssl-cert.sh -d ip.example.com -o test_certs -i 192.168.1.1"

# Error handling tests
echo -e "${YELLOW}Running error handling tests...${NC}"

run_test "Invalid domain name" \
    "../generate-ssl-cert.sh -d 'invalid domain' -o test_certs" 1

run_test "Invalid IP address" \
    "../generate-ssl-cert.sh -d valid.com -o test_certs -i '256.256.256.256'" 1

run_test "Missing required parameter" \
    "../generate-ssl-cert.sh -o test_certs" 1

# Certificate verification tests
echo -e "${YELLOW}Running certificate verification tests...${NC}"

run_test "Verify certificate content" \
    "openssl x509 -in test_certs/test.example.com.crt -text -noout"

run_test "Verify certificate and key match" \
    "openssl x509 -noout -modulus -in test_certs/test.example.com.crt | openssl md5; openssl rsa -noout -modulus -in test_certs/test.example.com.key | openssl md5"

# Permission tests
echo -e "${YELLOW}Running permission tests...${NC}"

run_test "Certificate file permissions" \
    "[ $(stat -c %a test_certs/test.example.com.crt) = '644' ]"

run_test "Private key file permissions" \
    "[ $(stat -c %a test_certs/test.example.com.key) = '600' ]"

# Clean up
echo -e "${YELLOW}Cleaning up test environment...${NC}"
rm -rf test_certs

# Print summary
echo -e "\n${YELLOW}Test Summary:${NC}"
echo "Total tests: $TOTAL_TESTS"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"

# Exit with failure if any tests failed
[ $FAILED_TESTS -eq 0 ] || exit 1

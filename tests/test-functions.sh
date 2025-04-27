#!/bin/bash

# Common test functions for SSL Certificate Generator test suites

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
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] $1" >> "$LOG_FILE"
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

# Function to initialize test environment
init_test_env() {
    rm -f "$LOG_FILE"
    mkdir -p test_certs
    echo "Test execution started at $(date)" > "$LOG_FILE"
}

# Function to cleanup test environment
cleanup_test_env() {
    echo "Test execution completed at $(date)" >> "$LOG_FILE"
    rm -rf test_certs
}

# Function to print test summary
print_test_summary() {
    echo -e "\n${YELLOW}Test Summary:${NC}"
    echo "Total tests: $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
    
    echo -e "\nTest Summary:" >> "$LOG_FILE"
    echo "Total tests: $TOTAL_TESTS" >> "$LOG_FILE"
    echo "Passed: $PASSED_TESTS" >> "$LOG_FILE"
    echo "Failed: $FAILED_TESTS" >> "$LOG_FILE"
}

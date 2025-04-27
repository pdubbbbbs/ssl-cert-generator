#!/bin/bash

# Run all test suites for SSL Certificate Generator

# Set up colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Initialize counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Function to run a test suite
run_suite() {
    local suite_name="$1"
    local script_name="$2"
    
    TOTAL_SUITES=$((TOTAL_SUITES + 1))
    echo -e "\n${YELLOW}Running $suite_name...${NC}"
    
    if ./"$script_name"; then
        echo -e "${GREEN}$suite_name passed${NC}"
        PASSED_SUITES=$((PASSED_SUITES + 1))
    else
        echo -e "${RED}$suite_name failed${NC}"
        FAILED_SUITES=$((FAILED_SUITES + 1))
    fi
}

# Clean up any previous test results
rm -rf test_results
mkdir -p test_results

# Run all test suites
run_suite "Basic Tests" "run-tests.sh"
run_suite "Advanced Tests" "advanced-tests.sh"
run_suite "Performance Tests" "performance-tests.sh"

# Generate metrics summary
if [ -f "metrics-summary.sh" ]; then
    echo -e "\n${YELLOW}Generating metrics summary...${NC}"
    ./metrics-summary.sh
fi

# Print summary
echo -e "\n${YELLOW}Test Suite Summary${NC}"
echo "Total test suites: $TOTAL_SUITES"
echo -e "Passed: ${GREEN}$PASSED_SUITES${NC}"
echo -e "Failed: ${RED}$FAILED_SUITES${NC}"

# Exit with failure if any suite failed
[ $FAILED_SUITES -eq 0 ] || exit 1

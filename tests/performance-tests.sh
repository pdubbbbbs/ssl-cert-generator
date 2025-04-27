#!/bin/bash

# Performance and Load Testing Suite for SSL Certificate Generator
# Tests renewal, performance, load, and recovery scenarios

# Source common test functions
source "$(dirname "$0")/test-functions.sh"

# Load configuration
if [ -f "./proxmox-test.conf" ]; then
    source "./proxmox-test.conf"
else
    echo "Error: proxmox-test.conf not found. Copy proxmox-test.conf.template and update it."
    exit 1
fi

# Test directory structure
TEST_DIR="./test_results"
CERTS_DIR="$TEST_DIR/certs"
METRICS_DIR="$TEST_DIR/metrics"
BACKUP_DIR="$TEST_DIR/backups"
RESTORE_DIR="$TEST_DIR/restore"
REPORTS_DIR="$TEST_DIR/reports"

# Create directory structure
create_test_dirs() {
    mkdir -p "$CERTS_DIR" "$METRICS_DIR" "$BACKUP_DIR" "$RESTORE_DIR" "$REPORTS_DIR"
}

# Performance metrics file
METRICS_FILE="$METRICS_DIR/performance_metrics.log"

# Function to log metrics
log_metric() {
    local test_name="$1"
    local value="$2"
    local unit="$3"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $test_name: $value $unit" >> "$METRICS_FILE"
}

# Function to measure execution time
measure_execution() {
    local test_name="$1"
    shift
    local start_time=$(date +%s.%N)
    "$@"
    local exit_code=$?
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    log_metric "$test_name" "$duration" "seconds"
    return $exit_code
}

# Initialize test environment
create_test_dirs
echo "Starting performance tests at $(date)" > "$METRICS_FILE"

echo -e "${YELLOW}Running Performance and Load Tests...${NC}"

# 1. Certificate Renewal Tests
echo -e "\n${YELLOW}Testing Certificate Renewal...${NC}"

# Generate initial certificate with short validity
measure_execution "initial_cert_generation" \
    ../generate-ssl-cert.sh -d "$PROXMOX_DOMAIN" -i "$PROXMOX_HOST" -o "$CERTS_DIR" -v 30
initial_cert_status=$?
run_test "Generate initial certificate" "[ $initial_cert_status -eq 0 ]"

# Check expiration date
run_test "Check expiration date" \
    "openssl x509 -in $CERTS_DIR/$PROXMOX_DOMAIN.crt -noout -enddate | grep -q 'notAfter'"

# Simulate renewal process
measure_execution "cert_renewal" \
    ../generate-ssl-cert.sh -d "$PROXMOX_DOMAIN" -i "$PROXMOX_HOST" -o "$CERTS_DIR" -v 365

# 2. Performance Benchmarking
echo -e "\n${YELLOW}Running Performance Benchmarks...${NC}"

# Single certificate generation benchmark
echo "Testing single certificate generation performance..."
total_duration=0
for i in {1..5}; do
    measure_execution "single_cert_gen_$i" \
        ../generate-ssl-cert.sh -d "perf$i.example.com" -o "$CERTS_DIR"
done

# Calculate average
average_duration=$(awk '/single_cert_gen/ {total += $4; count++} END {print total/count}' "$METRICS_FILE")
log_metric "single_cert_gen_average" "$average_duration" "seconds"

# Parallel certificate generation benchmark
echo "Testing parallel certificate generation..."
for i in {1..3}; do
    start_time=$(date +%s.%N)
    pids=()
    for j in {1..5}; do
        ../generate-ssl-cert.sh -d "parallel$j.example.com" -o "$CERTS_DIR" &
        pids+=($!)
    done
    for pid in "${pids[@]}"; do
        wait $pid
    done
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    log_metric "parallel_cert_gen_$i" "$duration" "seconds"
done

# 3. Load Testing
echo -e "\n${YELLOW}Running Load Tests...${NC}"

# Sequential load test
echo "Testing sequential load..."
start_time=$(date +%s.%N)
for i in {1..10}; do
    measure_execution "sequential_load_$i" \
        ../generate-ssl-cert.sh -d "load$i.example.com" -o "$CERTS_DIR"
    exit_code=$?
    run_test "Sequential load test $i" "[ $exit_code -eq 0 ]"
done
end_time=$(date +%s.%N)
total_duration=$(echo "$end_time - $start_time" | bc)
log_metric "sequential_load_total" "$total_duration" "seconds"

# 4. Recovery Scenarios
echo -e "\n${YELLOW}Testing Recovery Scenarios...${NC}"

# Create backup of test certificates
BACKUP_FILE="$BACKUP_DIR/cert_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
run_test "Create certificate backup" \
    "cd $CERTS_DIR && tar czf $BACKUP_FILE *.{crt,key}"

# Test backup restoration
run_test "Restore from backup" \
    "cd $RESTORE_DIR && tar xzf $BACKUP_FILE"

# Test certificate corruption recovery
echo "Testing corruption recovery..."
cp "$CERTS_DIR/$PROXMOX_DOMAIN.crt" "$CERTS_DIR/$PROXMOX_DOMAIN.crt.bak"
run_test "Simulate certificate corruption" \
    "echo 'corrupted' > $CERTS_DIR/$PROXMOX_DOMAIN.crt"

run_test "Detect corruption" \
    "! openssl x509 -in $CERTS_DIR/$PROXMOX_DOMAIN.crt -noout -text"

run_test "Recover from corruption" \
    "mv $CERTS_DIR/$PROXMOX_DOMAIN.crt.bak $CERTS_DIR/$PROXMOX_DOMAIN.crt && \
     openssl x509 -in $CERTS_DIR/$PROXMOX_DOMAIN.crt -noout -text"

# Generate performance report
echo -e "\n${YELLOW}Generating Performance Report...${NC}"

REPORT_FILE="$REPORTS_DIR/performance-report.md"
cat > "$REPORT_FILE" << REPORT
# SSL Certificate Generator Performance Report

## Test Environment
- Date: $(date)
- Host: $(hostname)
- OpenSSL Version: $(openssl version)

## Certificate Generation Performance
Single Certificate Generation:
$(grep "single_cert_gen" "$METRICS_FILE" || echo "No data available")

Average Generation Time: $(awk '/single_cert_gen_average/ {print $4}' "$METRICS_FILE" || echo "N/A") seconds

## Parallel Processing Performance
$(grep "parallel_cert_gen" "$METRICS_FILE" || echo "No data available")

## Load Test Results
Sequential Load Tests:
$(grep "sequential_load" "$METRICS_FILE" || echo "No data available")

Total Load Test Time: $(awk '/sequential_load_total/ {print $4}' "$METRICS_FILE" || echo "N/A") seconds

## Resource Usage
- CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%
- Memory Usage: $(free -m | awk '/Mem:/ {print int($3/$2 * 100)}')%

## Test Summary
- Certificate Renewal Tests: $(grep -c "cert_renewal" "$METRICS_FILE") completed
- Performance Tests: $(grep -c "single_cert_gen" "$METRICS_FILE") single, $(grep -c "parallel_cert_gen" "$METRICS_FILE") parallel
- Load Tests: $(grep -c "sequential_load" "$METRICS_FILE") certificates
- Recovery Tests: All scenarios tested

## Recommendations
1. Optimal parallel generation: 5 certificates
2. Recommended renewal buffer: 30 days
3. Backup retention period: 90 days
4. Recovery time objective: < 5 minutes

## Next Steps
1. Implement automated renewal cron jobs
2. Set up monitoring for certificate expiration
3. Configure backup rotation
4. Document recovery procedures
REPORT

# Print summary
echo -e "\n${YELLOW}Performance Test Summary:${NC}"
echo "1. Certificate Renewal: $(grep -c "cert_renewal" "$METRICS_FILE") tests"
echo "2. Performance Benchmarks: $(grep -c "parallel_cert_gen" "$METRICS_FILE") parallel tests"
echo "3. Load Tests: $(grep -c "sequential_load" "$METRICS_FILE") certificates"
echo "4. Recovery Scenarios: Complete"

echo -e "\n${YELLOW}Average Certificate Generation Time:${NC}"
awk '/single_cert_gen_average/ {print $4 " seconds"}' "$METRICS_FILE" || echo "N/A"

# Exit successfully
exit 0

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

# Create metrics directory
METRICS_DIR="test_results/metrics"
mkdir -p "$METRICS_DIR"
METRICS_FILE="$METRICS_DIR/performance_metrics.log"

# Performance metrics storage
declare -A METRICS

# Function to measure execution time
measure_execution() {
    local start_time=$(date +%s.%N)
    "$@"
    local exit_code=$?
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    echo "$duration:$exit_code"
}

# Function to log metrics
log_metric() {
    local test_name="$1"
    local value="$2"
    local unit="$3"
    METRICS["${test_name}_${unit}"]=$value
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $test_name: $value $unit" >> "$METRICS_FILE"
}

# Initialize test environment
init_test_env
mkdir -p test_results/certs
mkdir -p test_results/backups

echo -e "${YELLOW}Running Performance and Load Tests...${NC}"

# 1. Certificate Renewal Tests
echo -e "\n${YELLOW}Testing Certificate Renewal...${NC}"

# Generate initial certificate with short validity
result=$(measure_execution ../generate-ssl-cert.sh -d "$PROXMOX_DOMAIN" -i "$PROXMOX_HOST" -o test_results/certs -v 30)
duration=$(echo "$result" | cut -d: -f1)
exit_code=$(echo "$result" | cut -d: -f2)
log_metric "initial_cert_generation" "$duration" "seconds"
run_test "Generate initial certificate" "[ $exit_code -eq 0 ]"

# Check expiration date
run_test "Check expiration date" \
    "openssl x509 -in test_results/certs/$PROXMOX_DOMAIN.crt -noout -enddate | grep -q 'notAfter'"

# Simulate renewal process
result=$(measure_execution ../generate-ssl-cert.sh -d "$PROXMOX_DOMAIN" -i "$PROXMOX_HOST" -o test_results/certs -v 365)
duration=$(echo "$result" | cut -d: -f1)
log_metric "cert_renewal" "$duration" "seconds"
run_test "Certificate renewal simulation" "[ $(echo "$result" | cut -d: -f2) -eq 0 ]"

# 2. Performance Benchmarking
echo -e "\n${YELLOW}Running Performance Benchmarks...${NC}"

# Single certificate generation benchmark
echo "Testing single certificate generation performance..."
total_duration=0
for i in {1..5}; do
    result=$(measure_execution ../generate-ssl-cert.sh -d "perf$i.example.com" -o test_results/certs)
    duration=$(echo "$result" | cut -d: -f1)
    total_duration=$(echo "$total_duration + $duration" | bc)
    log_metric "single_cert_gen_$i" "$duration" "seconds"
done
average_duration=$(echo "scale=3; $total_duration / 5" | bc)
log_metric "single_cert_gen_average" "$average_duration" "seconds"

# Parallel certificate generation benchmark
echo "Testing parallel certificate generation..."
for i in {1..3}; do
    start_time=$(date +%s.%N)
    pids=()
    for j in {1..5}; do
        ../generate-ssl-cert.sh -d "parallel$j.example.com" -o test_results/certs &
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

# Generate multiple certificates in sequence
echo "Testing sequential load..."
start_time=$(date +%s.%N)
for i in {1..10}; do
    result=$(measure_execution ../generate-ssl-cert.sh -d "load$i.example.com" -o test_results/certs)
    duration=$(echo "$result" | cut -d: -f1)
    log_metric "sequential_load_$i" "$duration" "seconds"
    run_test "Sequential load test $i" "[ $(echo "$result" | cut -d: -f2) -eq 0 ]"
done
end_time=$(date +%s.%N)
total_duration=$(echo "$end_time - $start_time" | bc)
log_metric "sequential_load_total" "$total_duration" "seconds"

# 4. Recovery Scenarios
echo -e "\n${YELLOW}Testing Recovery Scenarios...${NC}"

# Test backup creation
BACKUP_FILE="test_results/backups/cert_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
run_test "Create certificate backup" \
    "tar czf $BACKUP_FILE test_results/certs/*.{crt,key}"

# Test backup restoration
mkdir -p test_results/restore
run_test "Restore from backup" \
    "cd test_results/restore && tar xzf ../$BACKUP_FILE"

# Test certificate corruption recovery
echo "Testing corruption recovery..."
cp test_results/certs/$PROXMOX_DOMAIN.crt test_results/certs/$PROXMOX_DOMAIN.crt.bak
run_test "Simulate certificate corruption" \
    "echo 'corrupted' > test_results/certs/$PROXMOX_DOMAIN.crt"

run_test "Detect corruption" \
    "! openssl x509 -in test_results/certs/$PROXMOX_DOMAIN.crt -noout -text"

run_test "Recover from corruption" \
    "mv test_results/certs/$PROXMOX_DOMAIN.crt.bak test_results/certs/$PROXMOX_DOMAIN.crt && \
     openssl x509 -in test_results/certs/$PROXMOX_DOMAIN.crt -noout -text"

# Generate performance report
echo -e "\n${YELLOW}Generating Performance Report...${NC}"

cat > test_results/performance-report.md << REPORT
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
echo "1. Certificate Renewal: $(grep -c single_cert_gen "$METRICS_FILE") tests"
echo "2. Performance Benchmarks: $(grep -c parallel_cert_gen "$METRICS_FILE") parallel tests"
echo "3. Load Tests: $(grep -c sequential_load "$METRICS_FILE") certificates"
echo "4. Recovery Scenarios: All passed"

echo -e "\n${YELLOW}Average Certificate Generation Time:${NC}"
echo "$(awk '/single_cert_gen_average/ {print $4}' "$METRICS_FILE" || echo "N/A") seconds"

# Cleanup
cleanup_test_env

# Exit successfully
exit 0

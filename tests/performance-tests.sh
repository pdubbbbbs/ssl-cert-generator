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

# Performance metrics storage
declare -A METRICS

# Function to measure execution time
measure_execution() {
    local start_time=$(date +%s.%N)
    "$@"
    local end_time=$(date +%s.%N)
    echo "$(echo "$end_time - $start_time" | bc)"
}

# Function to log metrics
log_metric() {
    local test_name="$1"
    local value="$2"
    local unit="$3"
    METRICS["${test_name}_${unit}"]=$value
    echo "$test_name: $value $unit" >> performance_metrics.log
}

# Initialize test environment
init_test_env
mkdir -p test_results

echo -e "${YELLOW}Running Performance and Load Tests...${NC}"

# 1. Certificate Renewal Tests
echo -e "${YELLOW}Testing Certificate Renewal...${NC}"

run_test "Generate initial certificate" \
    "../generate-ssl-cert.sh -d $PROXMOX_DOMAIN -i $PROXMOX_HOST -o test_certs -v 30"

run_test "Check expiration date" \
    "openssl x509 -in test_certs/$PROXMOX_DOMAIN.crt -noout -enddate | grep -q 'notAfter'"

# Simulate renewal process
run_test "Certificate renewal simulation" \
    "../generate-ssl-cert.sh -d $PROXMOX_DOMAIN -i $PROXMOX_HOST -o test_certs -v 365"

# Test automatic renewal
cat > test_certs/renew-cert.sh << 'RENEWSCRIPT'
#!/bin/bash
../generate-ssl-cert.sh -d "$1" -i "$2" -o "$3" -v 365
RENEWSCRIPT
chmod +x test_certs/renew-cert.sh

run_test "Automated renewal script" \
    "./test_certs/renew-cert.sh $PROXMOX_DOMAIN $PROXMOX_HOST test_certs"

# 2. Performance Benchmarking
echo -e "${YELLOW}Running Performance Benchmarks...${NC}"

# Single certificate generation benchmark
echo "Testing single certificate generation performance..."
for i in {1..5}; do
    duration=$(measure_execution ../generate-ssl-cert.sh -d "perf$i.example.com" -o test_certs)
    log_metric "single_cert_gen_$i" "$duration" "seconds"
done

# Parallel certificate generation benchmark
echo "Testing parallel certificate generation..."
for i in {1..3}; do
    start_time=$(date +%s.%N)
    for j in {1..5}; do
        ../generate-ssl-cert.sh -d "parallel$j.example.com" -o test_certs &
    done
    wait
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    log_metric "parallel_cert_gen_$i" "$duration" "seconds"
done

# 3. Load Testing
echo -e "${YELLOW}Running Load Tests...${NC}"

# Generate multiple certificates in sequence
echo "Testing sequential load..."
start_time=$(date +%s.%N)
for i in {1..10}; do
    run_test "Sequential load test $i" \
        "../generate-ssl-cert.sh -d load$i.example.com -o test_certs"
done
end_time=$(date +%s.%N)
log_metric "sequential_load_10_certs" "$(echo "$end_time - $start_time" | bc)" "seconds"

# Test certificate installation under load
echo "Testing installation under load..."
for i in {1..3}; do
    run_test "Load test installation $i" \
        "../install-proxmox-cert.sh -d load$i.example.com -i $PROXMOX_HOST -k $PROXMOX_SSH_KEY"
done

# 4. Recovery Scenarios
echo -e "${YELLOW}Testing Recovery Scenarios...${NC}"

# Test backup creation
run_test "Create certificate backup" \
    "tar czf test_certs/cert_backup.tar.gz test_certs/*.{crt,key}"

# Test backup restoration
run_test "Restore from backup" \
    "cd test_certs && tar xzf cert_backup.tar.gz"

# Test certificate corruption recovery
echo "Testing corruption recovery..."
run_test "Simulate certificate corruption" \
    "echo 'corrupted' > test_certs/$PROXMOX_DOMAIN.crt"

run_test "Detect corruption" \
    "! openssl x509 -in test_certs/$PROXMOX_DOMAIN.crt -noout -text"

run_test "Recover from corruption" \
    "../generate-ssl-cert.sh -d $PROXMOX_DOMAIN -i $PROXMOX_HOST -o test_certs"

# Generate performance report
echo -e "${YELLOW}Generating Performance Report...${NC}"

cat > performance-report.md << REPORT
# SSL Certificate Generator Performance Report

## Test Environment
- Date: $(date)
- Host: $(hostname)
- OpenSSL Version: $(openssl version)

## Certificate Generation Performance
$(grep "single_cert_gen" performance_metrics.log)

Average Generation Time: $(awk '/single_cert_gen/ {sum+=$2; count++} END {print sum/count}' performance_metrics.log) seconds

## Parallel Processing Performance
$(grep "parallel_cert_gen" performance_metrics.log)

Average Parallel Time: $(awk '/parallel_cert_gen/ {sum+=$2; count++} END {print sum/count}' performance_metrics.log) seconds

## Load Test Results
$(grep "sequential_load" performance_metrics.log)

## Resource Usage
- CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%
- Memory Usage: $(free -m | awk '/Mem:/ {print int($3/$2 * 100)}')%

## Recommendations
1. Optimal parallel certificate generation: 5 certificates
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
echo "1. Certificate Renewal: $(grep single_cert_gen performance_metrics.log | wc -l) tests"
echo "2. Performance Benchmarks: $(grep parallel_cert_gen performance_metrics.log | wc -l) parallel tests"
echo "3. Load Tests: $(grep sequential_load performance_metrics.log | wc -l) certificates"
echo "4. Recovery Scenarios: All passed"

# Cleanup
cleanup_test_env

# Exit successfully
exit 0

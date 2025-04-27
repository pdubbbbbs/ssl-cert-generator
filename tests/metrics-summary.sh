#!/bin/bash

# Script to analyze and summarize test metrics
TEST_DIR="/home/sitboo/ssl-cert-generator/tests/test_results"
METRICS_FILE="$TEST_DIR/metrics/performance_metrics.log"
SUMMARY_FILE="$TEST_DIR/reports/metrics-summary.md"

mkdir -p "$TEST_DIR/reports"

# Function to format floating point number
format_number() {
    printf "%.3f" "$1"
}

echo "# SSL Certificate Generator Performance Summary" > "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "## Test Environment" >> "$SUMMARY_FILE"
echo "- Date: $(date)" >> "$SUMMARY_FILE"
echo "- OpenSSL Version: $(openssl version)" >> "$SUMMARY_FILE"
echo "- System: $(uname -a)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

echo "## Certificate Generation Performance" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Single Certificate Generation
echo "### Single Certificate Generation" >> "$SUMMARY_FILE"
echo "| Test | Duration (seconds) |" >> "$SUMMARY_FILE"
echo "|------|-------------------|" >> "$SUMMARY_FILE"
grep "single_cert_gen_[0-9]" "$METRICS_FILE" | while read -r line; do
    test_name=$(echo "$line" | awk '{print $4}')
    duration=$(echo "$line" | awk '{print $5}')
    formatted_duration=$(format_number "$duration")
    echo "| $test_name | $formatted_duration |" >> "$SUMMARY_FILE"
done

# Calculate average time
avg_time=$(awk '/single_cert_gen_[0-9]/ {total += $5; count++} END {print total/count}' "$METRICS_FILE")
formatted_avg_time=$(format_number "$avg_time")
echo "" >> "$SUMMARY_FILE"
echo "**Average Time:** $formatted_avg_time seconds" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Parallel Generation
echo "### Parallel Generation Performance" >> "$SUMMARY_FILE"
echo "| Test | Duration (seconds) | Certificates |" >> "$SUMMARY_FILE"
echo "|------|-------------------|--------------|" >> "$SUMMARY_FILE"
grep "parallel_cert_gen" "$METRICS_FILE" | while read -r line; do
    test_name=$(echo "$line" | awk '{print $4}')
    duration=$(echo "$line" | awk '{print $5}')
    formatted_duration=$(format_number "$duration")
    echo "| $test_name | $formatted_duration | 5 |" >> "$SUMMARY_FILE"
done

# Calculate average parallel time
avg_parallel=$(awk '/parallel_cert_gen/ {total += $5; count++} END {print total/count}' "$METRICS_FILE")
formatted_avg_parallel=$(format_number "$avg_parallel")
echo "" >> "$SUMMARY_FILE"
echo "**Average Time (5 certificates):** $formatted_avg_parallel seconds" >> "$SUMMARY_FILE"
echo "**Average Time per Certificate:** $(format_number "$(echo "$avg_parallel / 5" | bc -l)") seconds" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Load Testing
echo "### Load Testing Performance" >> "$SUMMARY_FILE"
echo "| Test | Duration (seconds) |" >> "$SUMMARY_FILE"
echo "|------|-------------------|" >> "$SUMMARY_FILE"
grep "sequential_load_[0-9]" "$METRICS_FILE" | while read -r line; do
    test_name=$(echo "$line" | awk '{print $4}')
    duration=$(echo "$line" | awk '{print $5}')
    formatted_duration=$(format_number "$duration")
    echo "| $test_name | $formatted_duration |" >> "$SUMMARY_FILE"
done

# Calculate total load test time
total_load=$(grep "sequential_load_total" "$METRICS_FILE" | awk '{print $5}')
formatted_total_load=$(format_number "$total_load")
cert_rate=$(echo "10/$total_load" | bc -l)
formatted_cert_rate=$(format_number "$cert_rate")
echo "" >> "$SUMMARY_FILE"
echo "**Total Load Test Time:** $formatted_total_load seconds" >> "$SUMMARY_FILE"
echo "**Certificate Generation Rate:** $formatted_cert_rate certificates/second" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"

# Performance Statistics
echo "## Performance Statistics" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "| Metric | Value |" >> "$SUMMARY_FILE"
echo "|--------|-------|" >> "$SUMMARY_FILE"
echo "| Single Certificate Average | $formatted_avg_time s |" >> "$SUMMARY_FILE"
echo "| Parallel Generation Average (5 certs) | $formatted_avg_parallel s |" >> "$SUMMARY_FILE"
echo "| Load Test Total (10 certs) | $formatted_total_load s |" >> "$SUMMARY_FILE"
echo "| Certificate Generation Rate | $formatted_cert_rate certs/second |" >> "$SUMMARY_FILE"

# Resource Usage
echo "" >> "$SUMMARY_FILE"
echo "## Resource Usage" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "| Resource | Usage |" >> "$SUMMARY_FILE"
echo "|----------|-------|" >> "$SUMMARY_FILE"
echo "| CPU Usage | $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')% |" >> "$SUMMARY_FILE"
echo "| Memory Usage | $(free -m | awk '/Mem:/ {print int($3/$2 * 100)}')% |" >> "$SUMMARY_FILE"
echo "| Disk Space | $(df -h . | awk 'NR==2 {print $5}') |" >> "$SUMMARY_FILE"

# Conclusions and Recommendations
echo "" >> "$SUMMARY_FILE"
echo "## Conclusions" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "1. Certificate Generation Speed:" >> "$SUMMARY_FILE"
echo "   - Single certificate: $formatted_avg_time seconds" >> "$SUMMARY_FILE"
echo "   - Parallel (5 certs): $formatted_avg_parallel seconds ($formatted_cert_rate certs/second)" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "2. Recommendations:" >> "$SUMMARY_FILE"
echo "   - Optimal batch size: 5 certificates" >> "$SUMMARY_FILE"
echo "   - Recommended parallel processes: $(nproc)" >> "$SUMMARY_FILE"
echo "   - Buffer time for certificate operations: $(format_number "$(echo "$avg_time * 2" | bc -l)") seconds" >> "$SUMMARY_FILE"

# Display summary
echo "Performance metrics summary written to: $SUMMARY_FILE"
cat "$SUMMARY_FILE"

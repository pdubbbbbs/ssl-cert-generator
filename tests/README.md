# SSL Certificate Generator Test Suite

This directory contains comprehensive test suites for the SSL Certificate Generator, including basic functionality tests, advanced feature tests, performance tests, and metrics reporting.

## Quick Start

```bash
# Run all tests
./run-all-tests.sh

# Run individual test suites
./run-tests.sh        # Basic functionality tests
./advanced-tests.sh   # Advanced feature tests
./performance-tests.sh # Performance and load tests
```

## Test Suites

### 1. Basic Tests (`run-tests.sh`)
Tests basic certificate generation functionality:
- Certificate generation
- Parameter validation
- File permissions
- Error handling

### 2. Advanced Tests (`advanced-tests.sh`)
Tests advanced features:
- Wildcard certificates
- Certificate revocation
- Security features
- Network error handling

### 3. Performance Tests (`performance-tests.sh`)
Tests performance and load handling:
- Single certificate generation
- Parallel certificate generation
- Load testing
- Resource usage monitoring

## Test Results

Test results are stored in the `test_results` directory:
```
test_results/
├── certs/          # Generated certificates
├── metrics/        # Performance metrics
├── reports/        # Test reports
├── backups/        # Test backups
└── restore/        # Restore test files
```

### Performance Metrics

To view performance metrics:
```bash
./metrics-summary.sh
```

The metrics report includes:
- Certificate generation times
- Parallel processing performance
- Load test results
- Resource usage statistics
- Recommendations

## Interpreting Results

### Performance Metrics
- **Single Certificate Time**: Average time to generate one certificate
- **Parallel Generation**: Time to generate multiple certificates simultaneously
- **Load Test Results**: System performance under load
- **Resource Usage**: CPU, memory, and disk usage during tests

### Success Criteria
- All basic tests pass
- All advanced tests pass
- Performance metrics within expected ranges:
  * Single cert generation: < 1 second
  * Parallel generation (5 certs): < 2 seconds
  * Load test (10 certs): < 10 seconds

## Automated Testing

GitHub Actions automatically runs all tests on:
- Every push to master
- Pull requests
- Tagged releases

### CI/CD Pipeline
1. Basic test suite
2. Advanced test suite
3. Performance tests
4. Security scan
5. Metrics generation
6. Results notification

### Test Reports
- Email notifications with test results
- GitHub Actions artifacts
- Performance metrics summary
- Test coverage report

## Troubleshooting

### Common Issues
1. **Test failures**: Check test_results.log
2. **Performance issues**: Review metrics-summary.md
3. **Resource constraints**: Check resource usage section

### Debug Mode
Run tests with debug output:
```bash
DEBUG=1 ./run-tests.sh
DEBUG=1 ./advanced-tests.sh
DEBUG=1 ./performance-tests.sh
```

## Contributing

When adding new tests:
1. Follow existing test patterns
2. Include both positive and negative test cases
3. Add performance metrics where applicable
4. Update documentation
5. Verify CI/CD pipeline passes

## License

Same as main project (MIT License)

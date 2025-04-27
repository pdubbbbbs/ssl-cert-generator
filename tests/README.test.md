# SSL Certificate Generator Test Suite

This directory contains comprehensive test suites for the SSL Certificate Generator, including basic functionality tests, advanced feature tests, and Proxmox integration tests.

## Test Suites

1. **Basic Tests** (`run-tests.sh`)
   - Certificate generation
   - Parameter validation
   - File permissions
   - Basic error handling

2. **Advanced Tests** (`advanced-tests.sh`)
   - Wildcard certificates
   - Security features
   - Network error handling
   - Certificate revocation

3. **Proxmox Integration Tests** (`proxmox-tests.sh`)
   - Certificate installation
   - Service management
   - Web interface accessibility
   - Certificate rotation

## Running Tests

### Basic Test Suite
```bash
./run-tests.sh
```

### Advanced Test Suite
```bash
./advanced-tests.sh
```

### Proxmox Integration Tests
1. Copy the configuration template:
   ```bash
   cp proxmox-test.conf.template proxmox-test.conf
   ```

2. Edit the configuration:
   ```bash
   nano proxmox-test.conf
   ```

3. Run the tests:
   ```bash
   ./proxmox-tests.sh
   ```

## Test Reports

Test reports are generated in the following locations:
- Basic test results: `test_results.log`
- Advanced test results: `test_results.log`
- Proxmox test report: `proxmox-test-report.md`

## Configuration

### Proxmox Test Configuration
The `proxmox-test.conf` file contains all necessary settings for Proxmox integration testing:

- Server connection details
- Certificate parameters
- Test timeouts and behaviors
- Backup settings

### Test Function Library
Common test functions are available in `test-functions.sh`:

- Test environment setup
- Result logging
- Cleanup procedures

## Adding New Tests

1. Create a new test script
2. Source the common functions:
   ```bash
   source "$(dirname "$0")/test-functions.sh"
   ```

3. Use the provided test functions:
   ```bash
   run_test "Test name" "command"
   ```

4. Add cleanup in case of failure:
   ```bash
   trap cleanup_test_env EXIT
   ```

## Best Practices

1. Always run basic tests before advanced tests
2. Use meaningful test names
3. Clean up after tests
4. Log all important information
5. Handle errors gracefully
6. Document expected results

## Troubleshooting

### Common Issues

1. **SSH Connection Failures**
   - Check SSH key permissions
   - Verify Proxmox host accessibility
   - Confirm correct port number

2. **Certificate Generation Errors**
   - Verify OpenSSL installation
   - Check file permissions
   - Ensure valid parameters

3. **Service Restart Issues**
   - Check Proxmox service status
   - Verify user permissions
   - Check system logs

### Debug Mode

Run tests with debug output:
```bash
VERBOSE=1 ./proxmox-tests.sh
```

## Contributing

When adding new tests:
1. Follow the existing format
2. Update documentation
3. Add error handling
4. Include cleanup code
5. Test thoroughly

## License

Same as the main project

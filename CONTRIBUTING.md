# Contributing to SSL Certificate Generator

We love your input! We want to make contributing to SSL Certificate Generator as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## Development Process

All changes happen through pull requests. Pull requests are the best way to propose changes to the codebase.

1. Fork the repo and create your branch from `master`
2. If you've added code that should be tested, add tests
3. If you've changed APIs, update the documentation
4. Ensure the test suite passes
5. Make sure your code lints
6. Issue that pull request!

## Testing

We use GitHub Actions for continuous integration. To test locally:

```bash
# Install shellcheck for syntax checking
sudo apt-get install shellcheck

# Run syntax check
shellcheck generate-ssl-cert.sh
shellcheck install-proxmox-cert.sh

# Test certificate generation
./generate-ssl-cert.sh -d test.example.com -o ./certs
openssl x509 -in ./certs/test.example.com.crt -text -noout

# Test Proxmox installation script (requires test environment)
./install-proxmox-cert.sh --help
```

## Development Environment Setup

1. Install required tools:
   ```bash
   sudo apt-get update
   sudo apt-get install -y openssl shellcheck
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/pdubbbbbs/ssl-cert-generator.git
   cd ssl-cert-generator
   ```

3. Create a development branch:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Code Style Guide

- Use 4 spaces for indentation
- Add comments for complex logic
- Include error handling for all operations
- Validate all user inputs
- Log important operations
- Use descriptive variable names

## Documentation

- Update README.md for any user-facing changes
- Document new features in the docs/ directory
- Include examples for new functionality
- Update version numbers when making releases

## Issue Reporting

When reporting issues, please include:

- Your operating system name and version
- OpenSSL version (`openssl version`)
- Detailed steps to reproduce the issue
- What you expected would happen
- What actually happened

## Security

- Never commit sensitive information
- Validate all inputs to prevent injection
- Use secure default values
- Follow security best practices

## License

By contributing, you agree that your contributions will be licensed under its MIT License.

# SSL Certificate Generator

A robust tool for generating self-signed SSL certificates with advanced features for integration with Proxmox and Cloudflare.

![CI/CD](https://github.com/pdubbbbbs/ssl-cert-generator/actions/workflows/test.yml/badge.svg)
![Version](https://img.shields.io/badge/Version-1.1.0-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

## Features

- Generate self-signed SSL certificates with customizable attributes
- Support for Subject Alternative Names (SANs) including IP addresses
- Proxmox integration for secure web interface access
- Cloudflare integration options including reverse proxy and tunnels
- Comprehensive error handling and validation
- Command-line interface with extensive options
- Configuration file support for defaults and templates

## Requirements

- Linux-based operating system (Tested on Debian/Ubuntu)
- OpenSSL 1.1.0+ (for certificate generation)
- Bash 4.0+ (for script execution)
- SSH client (for Proxmox integration)
- Optional:
  - Nginx (for reverse proxy setup)
  - Cloudflared (for Cloudflare Tunnel)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/pdubbbbbs/ssl-cert-generator.git
cd ssl-cert-generator

# Make scripts executable
chmod +x generate-ssl-cert.sh install-proxmox-cert.sh

# Generate a certificate
./generate-ssl-cert.sh -d example.com -o ./certs

# For Proxmox integration
./install-proxmox-cert.sh -d pve.example.com -i 192.168.1.10 -k ~/.ssh/id_rsa
```

## Documentation

For detailed instructions, please see:

- [Installation Guide](docs/installation.md)
- [Usage Examples](docs/usage.md)
- [Proxmox Integration](docs/proxmox-integration.md)
- [Cloudflare Setup](docs/cloudflare-setup.md)
- [API Documentation](docs/api.md)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Philip S. Wright

## Support

If you encounter any issues or need help, please:

1. Check the [Documentation](docs/)
2. Look through [existing issues](https://github.com/pdubbbbbs/ssl-cert-generator/issues)
3. Create a new issue if needed

## Author

Philip S. Wright

## Acknowledgments

- OpenSSL for providing the cryptographic libraries
- Proxmox VE team for their excellent virtualization platform
- Cloudflare for their security and CDN solutions

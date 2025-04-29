# Proxmox SSL Certificate Generator

![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)
[![GitHub issues](https://img.shields.io/github/issues/pdubbbbbs/ssl-cert-generator)](https://github.com/pdubbbbbs/ssl-cert-generator/issues)

A comprehensive tool to simplify SSL certificate management for Proxmox environments. This script creates a dedicated LXC container that handles SSL certificate generation, distribution, and renewal for all your Proxmox containers.

## Features

- **Automated Container Setup**: Creates a dedicated LXC container for SSL certificate management
- **Multiple Certificate Types**: Support for both Let's Encrypt and self-signed certificates
- **Flexible Validation**: Multiple validation methods (HTTP, DNS-Cloudflare, DNS-Route53, Manual DNS)
- **Comprehensive Coverage**: Generates certificates for all containers (existing and future)
- **Automatic Renewal**: Built-in renewal process for certificates
- **Interactive Wizard**: User-friendly prompts to gather necessary information
- **Secure Deployment**: Distributes certificates securely to individual containers
- **Host Certificate Support**: Can update the Proxmox host's own certificates
- **Detailed Logging**: Comprehensive logging for troubleshooting
- **Cloudflare Integration**: Support for Cloudflare DNS API and optional tunnel setup
- **Subject Alternative Names**: Support for SANs including IP addresses
- **Configuration Templates**: Support for defaults and templates via configuration files

## Prerequisites

- **Required:**
  - Proxmox VE 6.x or newer
  - Root access to the Proxmox host
  - Internet connectivity (for Let's Encrypt certificates)
  - Domain name(s) that you control (for Let's Encrypt certificates)
  - OpenSSL 1.1.0+ (for certificate generation)
  - Bash 4.0+ (for script execution)

- **Optional:**
  - DNS access (for DNS validation methods)
  - Nginx (for reverse proxy setup)
  - Cloudflared (for Cloudflare Tunnel)
  - SSH client (for remote Proxmox integration)

## Installation

1. Clone this repository to your Proxmox server:
   ```bash
   git clone https://github.com/pdubbbbbs/ssl-cert-generator.git
   cd ssl-cert-generator
   ```

2. Make the script executable:
   ```bash
   chmod +x proxmox_ssl_setup.sh
   ```

3. Run the script as root or with sudo:
   ```bash
   sudo ./proxmox_ssl_setup.sh
   ```

## Quick Start

For the main SSL container setup and wizard:
```bash
# Set up SSL container and wizard
sudo ./proxmox_ssl_setup.sh

# Then follow the guided setup
```

For standalone certificate generation:
```bash
# Generate a certificate
./generate-ssl-cert.sh -d example.com -o ./certs

# For Proxmox integration
./install-proxmox-cert.sh -d pve.example.com -i 192.168.1.10
```

## Usage Guide

The installation script will guide you through the setup process with clear instructions. Once the setup is complete, follow these steps:

### SSL Wizard Setup

1. **Connect to the SSL Wizard container**:
   ```bash
   pct enter <CONTAINER_ID>  # The ID will be shown during setup
   ```

2. **Run the SSL Wizard**:
   ```bash
   /root/ssl_wizard.sh
   ```
   Follow the prompts to enter your domain information and select certificate settings.

3. **Generate certificates**:
   ```bash
   /root/generate_certs.sh
   ```
   This will scan for containers and generate certificates as needed.

4. **Set up automatic renewal** (from host, after exiting the container):
   ```bash
   /root/setup_cert_renewal.sh
   ```

### Certificate Deployment

To apply certificates to your containers:

1. For each container, a deployment script is created in the SSL container at `/root/push_cert_XXX.sh`
2. These scripts should be copied to and run from the Proxmox host

To apply a certificate to the Proxmox host itself:

```bash
/root/apply_host_cert.sh your-domain.com
```

## How It Works

The system operates through these key components:

1. **SSL Wizard Container**: A dedicated LXC container that handles all certificate operations
2. **Configuration Wizard**: Gathers domain information and certificate preferences
3. **Certificate Generation**: Creates SSL certificates using Let's Encrypt or self-signed methods
4. **Container Scanner**: Identifies all containers in your Proxmox environment
5. **Deployment Scripts**: Creates custom scripts to deploy certificates to each container
6. **Renewal System**: Automatic renewal process to keep certificates valid

## Examples

### Basic Setup with Let's Encrypt (HTTP validation)

```
# Run the SSL wizard
/root/ssl_wizard.sh

# Enter domain: example.com
# Enter email: admin@example.com
# Choose certificate: 1 (Let's Encrypt)
# Choose validation: 1 (HTTP)

# Generate certificates
/root/generate_certs.sh
```

### Setup with Cloudflare DNS validation

```
# Run the SSL wizard
/root/ssl_wizard.sh

# Enter domain: example.com
# Enter email: admin@example.com
# Choose certificate: 1 (Let's Encrypt)
# Choose validation: 2 (Cloudflare DNS)
# Enter Cloudflare API token: your-cloudflare-api-token

# Generate certificates
/root/generate_certs.sh
```

### Setting up Certificates for Multiple Containers

```bash
# After running the SSL wizard and configuring your domain
/root/generate_certs.sh

# For each container, you'll be prompted:
# "Generate certificate for container1.example.com? (y/n): y"
# "Generate certificate for container2.example.com? (y/n): y"

# The script will generate certificates and deployment scripts
# You'll need to run these deployment scripts from the host:
/root/push_cert_101.sh  # For container ID 101
/root/push_cert_102.sh  # For container ID 102
```

## Troubleshooting

### Common Issues

#### Container Creation Failures

* **Issue**: Container fails to create
  * **Solution**: Verify storage availability in Proxmox with `pvesm status`
  * **Solution**: Check network connectivity with `ping -c 4 8.8.8.8`

* **Issue**: Container starts but can't access internet
  * **Solution**: Verify container networking with `pct exec <ID> -- ping -c 4 8.8.8.8`
  * **Solution**: Check Proxmox firewall settings with `pvefw status`

#### Certificate Generation Failures

* **Issue**: HTTP validation fails
  * **Solution**: Ensure port 80 is accessible from the internet
  * **Solution**: Check DNS settings for your domain
  * **Solution**: Verify your router is forwarding port 80 to your Proxmox host

* **Issue**: DNS validation fails
  * **Solution**: Check API credentials for your DNS provider
  * **Solution**: Verify domain ownership and API permissions
  * **Solution**: Wait longer for DNS propagation (up to 24 hours)

* **Issue**: Certificate renewal failures
  * **Solution**: Check the renewal log at `/root/renewal.log` in the SSL container
  * **Solution**: Verify validation method still works (HTTP ports open, API keys valid)
  * **Solution**: Check rate limits at Let's Encrypt (max 5 certificates per domain per week)

#### Deployment Issues

* **Issue**: Cannot push certificates to containers
  * **Solution**: Verify the target container is running with `pct list`
  * **Solution**: Check network connectivity between host and container
  * **Solution**: Verify permissions on the certificate files

* **Issue**: Proxmox web interface still shows old certificate
  * **Solution**: Restart pveproxy service with `systemctl restart pveproxy`
  * **Solution**: Clear your browser cache or try in private/incognito mode

### Log Files

For detailed troubleshooting, check these log files:

* **Setup logs**: `/home/user/ssl-cert-generator/ssl_setup_*.log`
* **Certificate renewal logs**: Inside SSL container at `/root/renewal.log`
* **Container logs**: Available in Proxmox UI or via `pct console <ID>`
* **Let's Encrypt logs**: Inside SSL container at `/var/log/letsencrypt/`

### Diagnostic Commands

Run these commands for diagnostic information:

```bash
# Container status
pct list

# Network connectivity
pct exec <ID> -- ping -c 4 8.8.8.8

# Certbot certificate status
pct exec <ID> -- certbot certificates

# Check certificate validity
pct exec <ID> -- openssl x509 -in /root/ssl-certs/example.com/fullchain.pem -text -noout
```

## Security Best Practices

### Certificate Security

* **Private Key Protection**: All private keys are protected with 0600 permissions
* **Container Isolation**: The SSL container runs as an unprivileged LXC container
* **API Credentials**: Store API credentials securely with proper permissions
* **Certificate Backups**: Automated backups of existing certificates are created before replacement
* **Password Security**: Container passwords are randomly generated and logged only during setup

### Additional Security Recommendations

1. **Update Regularly**: Keep your Proxmox host and SSL container updated with security patches
2. **Network Isolation**: Consider placing the SSL container in a separate VLAN
3. **Firewall Rules**: Implement proper firewall rules on your Proxmox host
4. **Audit Logs**: Review log files periodically for suspicious activity
5. **Access Control**: Limit SSH access to the Proxmox host to authorized users only

## Documentation

Additional documentation is available in the docs directory:

* [Installation Guide](docs/installation.md)
* [Advanced Usage](docs/advanced-usage.md)
* [Proxmox Integration](docs/proxmox-integration.md)
* [Cloudflare Setup](docs/cloudflare-setup.md)
* [Troubleshooting Guide](docs/troubleshooting.md)

> **Note:** Some documentation files may be created during initial setup or need to be created manually.

## Support and Updates

### Getting Help

If you encounter issues with the script:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review the log files mentioned in the Logs section
3. Check for [open issues](https://github.com/pdubbbbbs/ssl-cert-generator/issues) on GitHub
4. Open a new issue if your problem isn't already addressed

### Staying Updated

To update the script to the latest version:

```bash
cd /path/to/ssl-cert-generator
git pull
chmod +x proxmox_ssl_setup.sh
```

### Release Schedule

* **Minor Updates**: Released as needed for bug fixes and small improvements
* **Major Releases**: Announced on the GitHub repository with release notes
* **Security Patches**: Applied promptly when vulnerabilities are discovered

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions to improve the SSL Certificate Generator are welcome! Here's how to contribute:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your code follows the project's coding standards and includes appropriate documentation and tests.

## Acknowledgements

* [Let's Encrypt](https://letsencrypt.org/) for providing free SSL certificates
* [Proxmox](https://www.proxmox.com/) for their excellent virtualization platform
* [Certbot](https://certbot.eff.org/) for their Let's Encrypt client
* [OpenSSL](https://www.openssl.org/) for providing cryptographic libraries
* [Cloudflare](https://www.cloudflare.com/) for their DNS and security services
* All contributors who have helped improve this project

---

*Last updated: April 2025*

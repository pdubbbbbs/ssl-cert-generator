# Proxmox Certificate Generation Wizard

This guide explains how to use the Proxmox certificate generation wizards to easily create and install SSL certificates for your Proxmox environment.

## Quick Start

Choose one of the following options:

### Basic Interactive Script
```bash
./proxmox-lvm-cert.sh
```
For a simple, straightforward interactive process.

### Enhanced Wizard Interface
```bash
./proxmox-cert-wizard.sh
```
For a more user-friendly experience with additional features.

## Features

### Basic Interactive Script (`proxmox-lvm-cert.sh`)
- Simple question-and-answer format
- Basic input validation
- Direct certificate generation and installation
- Automatic backup creation

### Enhanced Wizard (`proxmox-cert-wizard.sh`)
- User-friendly interface with progress indicators
- Configuration save and load
- Connection testing
- Comprehensive error handling
- Detailed completion summary
- Color-coded output
- Input timeouts with defaults

## Step-by-Step Guide

1. **Basic Information**
   - Domain name (e.g., proxmox.example.com)
   - IP address (e.g., 192.168.1.100)
   - Admin email
   - SSH port (default: 22)

2. **Organization Details**
   - Country code (2 letters)
   - State/Province
   - City
   - Organization name
   - Organization unit

3. **Certificate Configuration**
   - Validity period (days)
   - Key size (bits)
   - Backup directory

4. **Connection Testing**
   - SSH connectivity check
   - Port accessibility verification
   - Backup location verification

5. **Certificate Generation**
   - Creates SSL certificate
   - Generates private key
   - Sets proper permissions

6. **Certificate Installation**
   - Backs up existing certificates
   - Installs new certificates
   - Restarts Proxmox services

7. **Verification**
   - Checks installation success
   - Verifies certificate validity
   - Tests web interface accessibility

## Configuration Files

The wizard can save and load configurations:
```bash
# Save current settings
./proxmox-cert-wizard.sh --save myconfig.conf

# Load saved settings
./proxmox-cert-wizard.sh --load myconfig.conf
```

## Troubleshooting

### Common Issues

1. **Connection Failures**
   ```
   Error: Cannot connect to host
   ```
   - Check IP address
   - Verify SSH port
   - Ensure SSH key is available

2. **Permission Issues**
   ```
   Error: Permission denied
   ```
   - Run with appropriate privileges
   - Check file permissions
   - Verify SSH key permissions

3. **Certificate Generation Failures**
   ```
   Error: Certificate generation failed
   ```
   - Check OpenSSL installation
   - Verify input parameters
   - Check disk space

4. **Installation Failures**
   ```
   Error: Installation failed
   ```
   - Check Proxmox permissions
   - Verify service status
   - Check backup directory permissions

## Best Practices

1. **Before Running**
   - Backup existing certificates
   - Note current configuration
   - Test SSH connectivity
   - Check disk space

2. **Certificate Management**
   - Use descriptive domain names
   - Set appropriate validity periods
   - Keep backups secure
   - Document installation details

3. **Security**
   - Use strong key sizes (2048+ bits)
   - Protect private keys
   - Use secure backup locations
   - Implement proper access controls

4. **Maintenance**
   - Monitor certificate expiration
   - Plan renewal schedule
   - Keep backups current
   - Document changes

## Examples

### Basic Usage
```bash
./proxmox-cert-wizard.sh
```

### With Saved Configuration
```bash
./proxmox-cert-wizard.sh --load previous.conf
```

### Non-Interactive Mode
```bash
./proxmox-cert-wizard.sh --non-interactive --config config.conf
```

### Quick Setup
```bash
./proxmox-lvm-cert.sh
```

## Next Steps

After successful certificate installation:

1. **Verify Installation**
   - Access Proxmox web interface
   - Check certificate details in browser
   - Verify service status

2. **Document Setup**
   - Save configuration
   - Note expiration date
   - Document backup location

3. **Plan Maintenance**
   - Set renewal reminders
   - Schedule regular backups
   - Plan update strategy

## Support

For issues or questions:
1. Check the troubleshooting guide
2. Review logs in `./logs` directory
3. Create an issue on GitHub
4. Contact support team

## License

MIT License - See LICENSE file for details

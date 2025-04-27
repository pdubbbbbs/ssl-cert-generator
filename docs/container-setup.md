# Setting Up SSL Certificate Generator Container in Proxmox

## Container Creation Steps

1. **Log into Proxmox Web Interface**
   - Open: https://192.168.12.34:8006
   - Login as root

2. **Create Container**
   - Click "Create CT" button
   - General:
     * Node: your-node
     * CT ID: 100 (or next available)
     * Hostname: ssl-generator
     * Password: set secure password
     * SSH Public Key: Optional

3. **Template**
   - Select: Debian 12 (or Ubuntu 22.04)
   - Storage: local
   - Disk Size: 8GB minimum

4. **CPU**
   - Cores: 2
   - Memory: 1024 MB
   - Swap: 512 MB

5. **Network**
   - IPv4: DHCP or static IP
   - IPv6: Optional
   - Bridge: vmbr0

6. **Start Container**
   - Wait for creation to complete
   - Start the container
   - Note the IP address assigned

7. **Initial Setup**
   ```bash
   # Connect to container
   ssh root@CONTAINER_IP

   # Update system
   apt update && apt upgrade -y

   # Install dependencies
   apt install -y git openssl curl wget nano

   # Clone repository
   cd /root
   git clone https://github.com/pdubbbbbs/ssl-cert-generator.git
   cd ssl-cert-generator
   chmod +x *.sh
   ```

8. **Run Wizard**
   ```bash
   ./proxmox-cert-wizard.sh
   ```

## Container Configuration

### Minimum Requirements
- Debian 12 or Ubuntu 22.04
- 2 CPU cores
- 1GB RAM
- 8GB storage
- Network access

### Required Packages
- git
- openssl
- curl
- wget (optional)
- nano (or your preferred editor)

### Network Configuration
- Ensure container has access to:
  * Proxmox host (192.168.12.34)
  * Port 8006 (Proxmox web interface)
  * Port 22 (SSH)
  * Internet (for git clone)

### Security Considerations
1. Use strong password
2. Configure SSH key authentication
3. Update system regularly
4. Restrict network access if needed

## Usage

### First Time Setup
1. Access container via SSH
   ```bash
   ssh root@CONTAINER_IP
   ```

2. Clone and prepare repository
   ```bash
   cd /root
   git clone https://github.com/pdubbbbbs/ssl-cert-generator.git
   cd ssl-cert-generator
   chmod +x *.sh
   ```

3. Run wizard
   ```bash
   ./proxmox-cert-wizard.sh
   ```

### Regular Usage
1. Connect to container
2. Navigate to directory:
   ```bash
   cd /root/ssl-cert-generator
   ```

3. Run wizard:
   ```bash
   ./proxmox-cert-wizard.sh
   ```

## Maintenance

### Update Repository
```bash
cd /root/ssl-cert-generator
git pull origin master
chmod +x *.sh
```

### System Updates
```bash
apt update && apt upgrade -y
```

### Backup Certificates
```bash
cp -r /root/ssl-cert-generator/certs /root/cert-backup-$(date +%Y%m%d)
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   chmod +x *.sh
   ```

2. **Network Issues**
   ```bash
   # Check network
   ping 192.168.12.34
   # Check DNS
   ping google.com
   ```

3. **Git Clone Failed**
   ```bash
   # Check git
   git --version
   # Check connectivity
   curl -v https://github.com
   ```

### Getting Help
- Check logs in container
- Access wizard documentation
- Create GitHub issue

## Best Practices

1. Regular Updates
   - Keep container updated
   - Update repository regularly
   - Backup certificates

2. Security
   - Use strong passwords
   - Configure firewall
   - Regular security updates

3. Maintenance
   - Monitor disk space
   - Check logs regularly
   - Keep backups current


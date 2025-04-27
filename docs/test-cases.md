# Test Cases for SSL Certificate Generator

## Basic Certificate Generation Tests

1. Standard Domain Certificate
```bash
./generate-ssl-cert.sh -d example.com -o ./certs
```
Expected outcome:
- Certificate file created at ./certs/example.com.crt
- Private key file created at ./certs/example.com.key
- Subject CN matches example.com
- Default validity period (365 days)

2. Certificate with IP SAN
```bash
./generate-ssl-cert.sh -d server.local -i 192.168.1.100 -o ./certs
```
Expected outcome:
- Certificate includes IP in SAN field
- Both domain and IP are accessible

3. Custom Organization Details
```bash
./generate-ssl-cert.sh \
  -d custom.org \
  -o ./certs \
  -c US \
  -s "New York" \
  -l "Brooklyn" \
  -org "Custom Org" \
  -ou "IT" \
  -e "admin@custom.org"
```
Expected outcome:
- All organization details correctly set in certificate

## Proxmox Integration Tests

1. Certificate Installation
```bash
./install-proxmox-cert.sh -d pve.domain.com -i 192.168.1.10 -k ~/.ssh/id_rsa
```
Expected outcome:
- Successful SSH connection
- Certificate files copied
- Proper permissions set
- pveproxy service restarted

2. Nginx Configuration (if using reverse proxy)
```bash
# Test Nginx configuration
nginx -t
```
Expected outcome:
- No syntax errors
- Valid configuration

## Error Handling Tests

1. Invalid Domain Name
```bash
./generate-ssl-cert.sh -d "invalid domain" -o ./certs
```
Expected outcome:
- Error message about invalid domain
- Non-zero exit code

2. Missing Required Parameters
```bash
./generate-ssl-cert.sh -o ./certs
```
Expected outcome:
- Error message about missing domain
- Usage instructions displayed

3. Invalid IP Address
```bash
./generate-ssl-cert.sh -d domain.com -i "256.256.256.256" -o ./certs
```
Expected outcome:
- Error message about invalid IP
- Non-zero exit code

## Security Tests

1. File Permissions
```bash
# Generate certificate
./generate-ssl-cert.sh -d secure.com -o ./certs
# Check permissions
ls -l ./certs/secure.com.key
```
Expected outcome:
- Private key permissions: 600 (-rw-------)
- Certificate permissions: 644 (-rw-r--r--)

2. Input Validation
```bash
./generate-ssl-cert.sh -d "$(echo '../etc/passwd')" -o ./certs
```
Expected outcome:
- Error message about invalid domain
- No file system manipulation possible

## Performance Tests

1. Large Key Size
```bash
time ./generate-ssl-cert.sh -d large.com -k 8192 -o ./certs
```
Expected outcome:
- Successfully generates certificate
- Acceptable time performance

2. Multiple Certificates
```bash
for i in {1..5}; do
  ./generate-ssl-cert.sh -d "test$i.com" -o ./certs
done
```
Expected outcome:
- All certificates generated successfully
- No resource exhaustion

## Integration Tests

1. Cloudflare Tunnel Setup
```bash
# Follow tunnel setup steps
# Verify connection status
cloudflared tunnel list
```
Expected outcome:
- Tunnel created successfully
- Connection established

2. DNS Record Verification
```bash
# After setting up Cloudflare integration
curl -I https://your.domain.com
```
Expected outcome:
- Successful HTTPS response
- Cloudflare proxy headers present

## Manual Test Checklist

- [ ] Certificate generation with all optional parameters
- [ ] Proxmox web interface accessibility
- [ ] Cloudflare proxy status
- [ ] WebSocket functionality for Proxmox console
- [ ] Error messages clarity and helpfulness
- [ ] Script help documentation accuracy
- [ ] Configuration file loading
- [ ] Backup functionality

#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows Cloudflare Tunnel Setup Script
.DESCRIPTION
    This script automates the installation and configuration of Cloudflare Tunnel on Windows systems.
    It will install cloudflared, configure it, and help set up a tunnel for secure remote access.
.NOTES
    File Name      : windows-cloudflare-setup.ps1
    Author         : Philip Wright
    Prerequisite   : PowerShell 5.1 or later, Administrator privileges
    Version        : 1.0
.EXAMPLE
    .\windows-cloudflare-setup.ps1
#>

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$VerbosePreference = "Continue"

# Configuration
$LogFile = "$PSScriptRoot\cloudflare-setup-log.txt"
$configDir = "$env:USERPROFILE\.cloudflared"
$installDir = "C:\Program Files\Cloudflare"
$serviceName = "cloudflared"
$chocolateyInstalled = $false

# Status colors
$InfoColor = "Cyan"
$SuccessColor = "Green"
$WarningColor = "Yellow"
$ErrorColor = "Red"

# Function to write to log file and console with timestamp
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "INFO"    { Write-Host $logMessage -ForegroundColor $InfoColor }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor $SuccessColor }
        "WARNING" { Write-Host $logMessage -ForegroundColor $WarningColor }
        "ERROR"   { Write-Host $logMessage -ForegroundColor $ErrorColor }
    }
    
    Add-Content -Path $LogFile -Value $logMessage
}

# Function to check if a command exists
function Test-Command {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    
    return (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Function to check if Chocolatey is installed
function Test-Chocolatey {
    return (Test-Command -Command "choco")
}

# Function to install Chocolatey
function Install-Chocolatey {
    Write-Log "Installing Chocolatey..." -Level "INFO"
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        if (Test-Chocolatey) {
            Write-Log "Chocolatey installed successfully" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Failed to install Chocolatey" -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log "Error installing Chocolatey: $_" -Level "ERROR"
        return $false
    }
}

# Function to check if cloudflared is installed
function Test-Cloudflared {
    return (Test-Command -Command "cloudflared")
}

# Function to install cloudflared via Chocolatey
function Install-CloudflaredChoco {
    Write-Log "Installing cloudflared via Chocolatey..." -Level "INFO"
    try {
        choco install cloudflared -y
        if (Test-Cloudflared) {
            Write-Log "cloudflared installed successfully via Chocolatey" -Level "SUCCESS"
            $script:chocolateyInstalled = $true
            return $true
        } else {
            Write-Log "Failed to install cloudflared via Chocolatey" -Level "WARNING"
            return $false
        }
    } catch {
        Write-Log "Error installing cloudflared via Chocolatey: $_" -Level "WARNING"
        return $false
    }
}

# Function to install cloudflared via direct download
function Install-CloudflaredDirect {
    Write-Log "Installing cloudflared via direct download..." -Level "INFO"
    try {
        # Create install directory if it doesn't exist
        if (-not (Test-Path $installDir)) {
            New-Item -Path $installDir -ItemType Directory -Force | Out-Null
            Write-Log "Created installation directory: $installDir" -Level "INFO"
        }
        
        # Download the latest cloudflared release
        $downloadUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
        $executablePath = "$installDir\cloudflared.exe"
        
        Write-Log "Downloading cloudflared from $downloadUrl" -Level "INFO"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $executablePath
        
        # Add to PATH if not already there
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$installDir*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installDir", "Machine")
            Write-Log "Added $installDir to PATH" -Level "INFO"
            # Update current session path
            $env:Path = "$env:Path;$installDir"
        }
        
        if (Test-Path $executablePath) {
            Write-Log "cloudflared installed successfully via direct download" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Failed to install cloudflared via direct download" -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log "Error installing cloudflared via direct download: $_" -Level "ERROR"
        return $false
    }
}

# Function to authenticate cloudflared with Cloudflare
function Connect-CloudflaredAuth {
    Write-Log "Authenticating cloudflared with Cloudflare..." -Level "INFO"
    try {
        Write-Log "Opening browser for Cloudflare authentication" -Level "INFO"
        Write-Log "Please log in to your Cloudflare account and authorize the tunnel..." -Level "INFO"
        
        # Run the auth command
        $process = Start-Process -FilePath "cloudflared" -ArgumentList "tunnel login" -PassThru -Wait
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Authentication successful" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Authentication process exited with code: $($process.ExitCode)" -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log "Error during authentication: $_" -Level "ERROR"
        return $false
    }
}

# Function to create a new Cloudflare Tunnel
function New-CloudflareTunnel {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TunnelName
    )
    
    Write-Log "Creating new Cloudflare Tunnel: $TunnelName" -Level "INFO"
    try {
        $output = cloudflared tunnel create $TunnelName
        $tunnelId = ($output | Select-String -Pattern 'Created tunnel ([\w-]+)' | ForEach-Object { $_.Matches.Groups[1].Value })
        
        if ($tunnelId) {
            Write-Log "Tunnel created successfully with ID: $tunnelId" -Level "SUCCESS"
            return $tunnelId
        } else {
            Write-Log "Failed to extract tunnel ID from output: $output" -Level "ERROR"
            return $null
        }
    } catch {
        Write-Log "Error creating tunnel: $_" -Level "ERROR"
        return $null
    }
}

# Function to configure tunnel DNS
function Set-TunnelDNS {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TunnelId,
        
        [Parameter(Mandatory=$true)]
        [string]$Domain,
        
        [Parameter(Mandatory=$false)]
        [string]$Subdomain = "@"
    )
    
    $fqdn = if ($Subdomain -eq "@") { $Domain } else { "$Subdomain.$Domain" }
    Write-Log "Configuring DNS for tunnel $TunnelId to point to $fqdn" -Level "INFO"
    
    try {
        cloudflared tunnel route dns $TunnelId $fqdn
        Write-Log "DNS configured successfully for $fqdn" -Level "SUCCESS"
        return $true
    } catch {
        Write-Log "Error configuring DNS: $_" -Level "ERROR"
        return $false
    }
}

# Function to create tunnel config file
function New-TunnelConfig {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TunnelId,
        
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Ingress
    )
    
    Write-Log "Creating tunnel configuration file at $ConfigPath" -Level "INFO"
    
    try {
        # Create base config
        $config = @{
            tunnel = $TunnelId
            credentials-file = "$configDir\$TunnelId.json"
            ingress = @()
        }
        
        # Add service-specific ingress rules
        foreach ($service in $Ingress.Keys) {
            $config.ingress += @{
                hostname = $service
                service = $Ingress[$service]
            }
        }
        
        # Add catch-all rule
        $config.ingress += @{
            service = "http_status:404"
        }
        
        # Convert to YAML and save
        $yamlContent = $config | ConvertTo-Yaml
        Set-Content -Path $ConfigPath -Value $yamlContent
        
        Write-Log "Configuration file created successfully" -Level "SUCCESS"
        return $true
    } catch {
        Write-Log "Error creating configuration file: $_" -Level "ERROR"
        return $false
    }
}

# Function to install tunnel as a service
function Install-TunnelService {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TunnelId,
        
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath
    )
    
    Write-Log "Installing cloudflared tunnel as a Windows service..." -Level "INFO"
    
    try {
        cloudflared service install --config $ConfigPath
        
        # Verify service was installed
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            Write-Log "Cloudflare Tunnel service installed successfully" -Level "SUCCESS"
            
            # Start the service
            Start-Service -Name $serviceName
            Write-Log "Cloudflare Tunnel service started" -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Failed to verify service installation" -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log "Error installing tunnel service: $_" -Level "ERROR"
        return $false
    }
}

# Function to check tunnel status
function Test-TunnelStatus {
    param (
        [Parameter(Mandatory=$true)]
        [string]$TunnelId
    )
    
    Write-Log "Checking status of tunnel $TunnelId" -Level "INFO"
    
    try {
        $output = cloudflared tunnel info $TunnelId
        Write-Log "Tunnel info: $output" -Level "INFO"
        return $true
    } catch {
        Write-Log "Error checking tunnel status: $_" -Level "ERROR"
        return $false
    }
}

# Function to provide step-by-step guide for accessing PVE/ZFS
function Show-AccessGuide {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Domain
    )
    
    Write-Host ""
    Write-Host "=========================================================" -ForegroundColor $InfoColor
    Write-Host "                SETUP COMPLETED SUCCESSFULLY              " -ForegroundColor $SuccessColor
    Write-Host "=========================================================" -ForegroundColor $InfoColor
    Write-Host ""
    Write-Host "Your Cloudflare Tunnel is now configured and running!" -ForegroundColor $SuccessColor
    Write-Host ""
    Write-Host "To access your services:" -ForegroundColor $InfoColor
    Write-Host "1. Make sure your Cloudflare DNS is properly configured to point to your tunnel" -ForegroundColor $InfoColor
    Write-Host "2. Access your services via https://$Domain" -ForegroundColor $InfoColor
    Write-Host ""
    Write-Host "Tunnel Management:" -ForegroundColor $InfoColor
    Write-Host "- View tunnel status: cloudflared tunnel info <tunnel-id>" -ForegroundColor $InfoColor
    Write-Host "- List all tunnels: cloudflared tunnel list" -ForegroundColor $InfoColor
    Write-Host "- Delete a tunnel: cloudflared tunnel delete <tunnel-id>" -ForegroundColor $InfoColor
    Write-Host ""
    Write-Host "Service Management:" -ForegroundColor $InfoColor
    Write-Host "- Start service: Start-Service -Name cloudflared" -ForegroundColor $InfoColor
    Write-Host "- Stop service: Stop-Service -Name cloudflared" -ForegroundColor $InfoColor
    Write-Host "- Restart service: Restart-Service -Name cloudflared" -ForegroundColor $InfoColor
    Write-Host ""
    Write-Host "For more information, visit: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/" -ForegroundColor $InfoColor
    Write-Host "=========================================================" -ForegroundColor $InfoColor
}

# Main script execution
Clear-Host
Write-Host "=========================================================" -ForegroundColor $InfoColor
Write-Host "           WINDOWS CLOUDFLARE TUNNEL SETUP               " -ForegroundColor $InfoColor
Write-Host "=========================================================" -ForegroundColor $InfoColor
Write-Host ""

# Initialize log file
$null = New-Item -Path $LogFile -ItemType File -Force
Write-Log "Starting Cloudflare Tunnel setup script" -Level "INFO"

# Check and install prerequisites
Write-Log "Checking prerequisites..." -Level "INFO"

# Check if cloudflared is already installed
if (Test-Cloudflared) {
    Write-Log "cloudflared is already installed" -Level "SUCCESS"
} else {
    Write-Log "cloudflared is not installed" -Level "INFO"
    
    # Check if Chocolatey is installed
    if (Test-Chocolatey) {
        Write-Log "Chocolatey is installed" -Level "INFO"
        
        # Try installing with Chocolatey
        if (-not (Install-CloudflaredChoco)) {
            # If Chocolatey install fails, try direct download
            if (-not (Install-CloudflaredDirect)) {
                Write-Log "Failed to install cloudflared. Please install it manually." -Level "ERROR"
                exit 1
            }
        }
    } else {
        Write-Log "Chocolatey is not installed" -Level "INFO"
        Write-Log "Attempting to install Chocolatey..." -Level "INFO"
        
        # Try to install Chocolatey
        if (Install-Chocolatey) {
            # Now try installing cloudflared with Chocolatey
            if (-not (Install-CloudflaredChoco)) {
                # If Chocolatey install fails, try direct download
                if (-not (Install-CloudflaredDirect)) {
                    Write-Log "Failed to install cloudflared. Please install it manually." -Level "ERROR"
                    exit 1
                }
            }
        } else {
            # If Chocolatey install fails, try direct download
            if (-not (Install-CloudflaredDirect)) {
                Write-Log "Failed to install cloudflared. Please install it manually." -Level "ERROR"
                exit 1
            }
        }
    }
}

# Verify cloudflared version
try {
    $version = (cloudflared --version) | Select-Object -First 1
    Write-Log "cloudflared version: $version" -Level "INFO"
} catch {
    Write-Log "Error checking cloudflared version: $_" -Level "ERROR"
}

# Check if Yaml module is installed for configuration file generation
$yamlModule = Get-Module -ListAvailable -Name powershell-yaml
if (-not $yamlModule) {
    Write-Log "PowerShell-Yaml module is not installed. Installing..." -Level "INFO"
    try {
        Install-Module -Name powershell-yaml -Scope CurrentUser -Force
        Write-Log "PowerShell-Yaml module installed successfully" -Level "SUCCESS"
    } catch {
        Write-Log "Error installing PowerShell-Yaml module: $_" -Level "ERROR"
        Write-Log "Configuration file generation will be done in JSON format instead" -Level "WARNING"
    }
}

# Import the YAML module if available
if (Get-Module -ListAvailable -Name powershell-yaml) {
    Import-Module -Name powershell-yaml
    $yamlAvailable = $true
} else {
    $yamlAvailable = $false
}

# Function to Convert to YAML
function ConvertTo-Yaml {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Object]$InputObject
    )
    
    if ($yamlAvailable) {
        return $InputObject | ConvertTo-Yaml
    } else {
        # Fallback to JSON if YAML module is not available
        return $InputObject | ConvertTo-Json -Depth 10
    }
}

# Interactive Configuration
$setupTunnel = $false
$setupService = $false

Write-Host ""
Write-Host "Cloudflared is now installed. Would you like to configure a new tunnel? (y/n)" -ForegroundColor $InfoColor
$setupTunnel = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character -eq "y"

if ($setupTunnel) {
    # Authenticate with Cloudflare
    Write-Host ""
    Write-Host "First, we need to authenticate with Cloudflare." -ForegroundColor $InfoColor
    Write-Host "This will open a browser where you'll need to log in to your Cloudflare account." -ForegroundColor $InfoColor
    Write-Host "Press any key to continue..."
    $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    if (-not (Connect-CloudflaredAuth)) {
        Write-Log "Authentication failed. Exiting setup." -Level "ERROR"
        exit 1
    }
    
    # Get tunnel name
    Write-Host ""
    Write-Host "Please enter a name for your new tunnel:" -ForegroundColor $InfoColor
    $tunnelName = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($tunnelName)) {
        $tunnelName = "toluca-tunnel-$(Get-Random -Minimum 1000 -Maximum 9999)"
        Write-Log "Using generated tunnel name: $tunnelName" -Level "INFO"
    }
    
    # Create the tunnel
    $tunnelId = New-CloudflareTunnel -TunnelName $tunnelName
    if (-not $tunnelId) {
        Write-Log "Failed to create tunnel. Exiting setup." -Level "ERROR"
        exit 1
    }
    
    # Get domain information
    Write-Host ""
    Write-Host "Please enter your domain name (e.g., example.com):" -ForegroundColor $InfoColor
    $domain = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($domain)) {
        Write-Log "Domain name is required. Exiting setup." -Level "ERROR"
        exit 1
    }
    
    # Ask about subdomains
    Write-Host ""
    Write-Host "Would you like to configure a subdomain? (y/n)" -ForegroundColor $InfoColor
    $setupSubdomain = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character -eq "y"
    
    $subdomain = "@"
    if ($setupSubdomain) {
        Write-Host ""
        Write-Host "Please enter the subdomain (e.g., pve for pve.example.com):" -ForegroundColor $InfoColor
        $subdomain = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($subdomain)) {
            $subdomain = "@"
            Write-Log "Using root domain" -Level "INFO"
        }
    }
    
    # Configure DNS
    if (-not (Set-TunnelDNS -TunnelId $tunnelId -Domain $domain -Subdomain $subdomain)) {
        Write-Log "Failed to configure DNS. You may need to set this up manually." -Level "WARNING"
    }
    
    # Get service information for ingress
    Write-Host ""
    Write-Host "Now we need to configure the service this tunnel will connect to." -ForegroundColor $InfoColor
    Write-Host "Please enter the local service URL (e.g., http://localhost:8006 for Proxmox):" -ForegroundColor $InfoColor
    $serviceUrl = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($serviceUrl)) {
        # Default to Proxmox
        $serviceUrl = "http://localhost:8006"
        Write-Log "Using default service URL: $serviceUrl" -Level "INFO"
    }
    
    # Create full hostname
    $hostname = if ($subdomain -eq "@") { $domain } else { "$subdomain.$domain" }
    
    # Create ingress configuration
    $ingress = @{
        "$hostname" = $serviceUrl
    }
    
    # Ask for additional services
    Write-Host ""
    Write-Host "Would you like to add another service? (y/n)" -ForegroundColor $InfoColor
    $addService = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character -eq "y"
    
    while ($addService) {
        Write-Host ""
        Write-Host "Please enter the subdomain for this service:" -ForegroundColor $InfoColor
        $additionalSubdomain = Read-Host
        
        if ([string]::IsNullOrWhiteSpace($additionalSubdomain)) {
            Write-Log "Subdomain is required for additional services. Skipping." -Level "WARNING"
        } else {
            Write-Host ""
            Write-Host "Please enter the local service URL for $additionalSubdomain.$domain:" -ForegroundColor $InfoColor
            $additionalServiceUrl = Read-Host
            
            if ([string]::IsNullOrWhiteSpace($additionalServiceUrl)) {
                Write-Log "Service URL is required. Skipping." -Level "WARNING"
            } else {
                # Add to ingress configuration
                $ingress["$additionalSubdomain.$domain"] = $additionalServiceUrl
                
                # Configure DNS for additional subdomain
                if (-not (Set-TunnelDNS -TunnelId $tunnelId -Domain $domain -Subdomain $additionalSubdomain)) {
                    Write-Log "Failed to configure DNS for $additionalSubdomain.$domain. You may need to set this up manually." -Level "WARNING"
                }
            }
        }
        
        Write-Host ""
        Write-Host "Would you like to add another service? (y/n)" -ForegroundColor $InfoColor
        $addService = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character -eq "y"
    }
    
    # Create configuration file
    $configPath = "$configDir\$tunnelName.yml"
    if (-not (New-TunnelConfig -TunnelId $tunnelId -ConfigPath $configPath -Ingress $ingress)) {
        Write-Log "Failed to create configuration file. Exiting setup." -Level "ERROR"
        exit 1
    }
    
    # Ask about service installation
    Write-Host ""
    Write-Host "Would you like to install cloudflared as a Windows service? (y/n)" -ForegroundColor $InfoColor
    $setupService = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character -eq "y"
    
    if ($setupService) {
        if (-not (Install-TunnelService -TunnelId $tunnelId -ConfigPath $configPath)) {
            Write-Log "Failed to install service. You can run cloudflared manually." -Level "ERROR"
        }
    } else {
        # Provide command to run tunnel manually
        Write-Host ""
        Write-Host "To run the tunnel manually, use this command:" -ForegroundColor $InfoColor
        Write-Host "cloudflared tunnel --config $configPath run" -ForegroundColor $SuccessColor
    }
    
    # Test tunnel status
    if (-not (Test-TunnelStatus -TunnelId $tunnelId)) {
        Write-Log "Failed to check tunnel status. The tunnel may not be active." -Level "WARNING"
    }
    
    # Show completion guide
    Show-AccessGuide -Domain $hostname
} else {
    Write-Host ""
    Write-Host "Skipping tunnel configuration. You can configure a tunnel later using:" -ForegroundColor $InfoColor
    Write-Host "cloudflared tunnel create <tunnel-name>" -ForegroundColor $SuccessColor
}

# Setup for toluca specifically if requested
$setupToluca = $false
Write-Host ""
Write-Host "Would you like to configure a tunnel specifically for toluca? (y/n)" -ForegroundColor $InfoColor
$setupToluca = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character -eq "y"

if ($setupToluca) {
    # Authenticate with Cloudflare if not done already
    if (-not $setupTunnel) {
        # Authenticate with Cloudflare
        Write-Host ""
        Write-Host "First, we need to authenticate with Cloudflare." -ForegroundColor $InfoColor
        Write-Host "This will open a browser where you'll need to log in to your Cloudflare account." -ForegroundColor $InfoColor
        Write-Host "Press any key to continue..."
        $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        if (-not (Connect-CloudflaredAuth)) {
            Write-Log "Authentication failed. Exiting toluca setup." -Level "ERROR"
            exit 1
        }
    }
    
    # Create the toluca tunnel
    $tolucaTunnelName = "toluca-tunnel-$(Get-Date -Format 'yyyyMMdd')"
    $tolucaTunnelId = New-CloudflareTunnel -TunnelName $tolucaTunnelName
    if (-not $tolucaTunnelId) {
        Write-Log "Failed to create toluca tunnel. Exiting setup." -Level "ERROR"
        exit 1
    }
    
    # Configure DNS for various toluca services
    $tolucaDomain = "42toluca.com"
    $tolucaServices = @{
        "pve" = "https://192.168.1.10:8006"
        "storage" = "http://192.168.1.10:80"
        "zfs" = "http://192.168.1.10:8000"
    }
    
    # Configure DNS entries
    foreach ($service in $tolucaServices.Keys) {
        if (-not (Set-TunnelDNS -TunnelId $tolucaTunnelId -Domain $tolucaDomain -Subdomain $service)) {
            Write-Log "Failed to configure DNS for $service.$tolucaDomain. You may need to set this up manually." -Level "WARNING"
        }
    }
    
    # Create ingress configuration for toluca
    $tolucaIngress = @{}
    foreach ($service in $tolucaServices.Keys) {
        $tolucaIngress["$service.$tolucaDomain"] = $tolucaServices[$service]
    }
    
    # Create configuration file for toluca
    $tolucaConfigPath = "$configDir\$tolucaTunnelName.yml"
    if (-not (New-TunnelConfig -TunnelId $tolucaTunnelId -ConfigPath $tolucaConfigPath -Ingress $tolucaIngress)) {
        Write-Log "Failed to create toluca configuration file. Exiting setup." -Level "ERROR"
        exit 1
    }
    
    # Ask about service installation for toluca
    Write-Host ""
    Write-Host "Would you like to install toluca tunnel as a Windows service? (y/n)" -ForegroundColor $InfoColor
    $setupTolucaService = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown").Character -eq "y"
    
    if ($setupTolucaService) {
        if (-not (Install-TunnelService -TunnelId $tolucaTunnelId -ConfigPath $tolucaConfigPath)) {
            Write-Log "Failed to install toluca service. You can run cloudflared manually." -Level "ERROR"
        }
    } else {
        # Provide command to run tunnel manually
        Write-Host ""
        Write-Host "To run the toluca tunnel manually, use this command:" -ForegroundColor $InfoColor
        Write-Host "cloudflared tunnel --config $tolucaConfigPath run" -ForegroundColor $SuccessColor
    }
    
    # Show completion guide for toluca
    Show-AccessGuide -Domain "pve.$tolucaDomain"
}

Write-Log "Setup script completed." -Level "SUCCESS"


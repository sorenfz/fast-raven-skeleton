#!/bin/bash

# Apache2 Deployment Script
# This script automates the deployment of a FastRaven site to Apache2 with
# SSL certificate generation using mkcert.

# Usage: ./deploy.sh <domain> <site-folder>
# Example: ./deploy.sh mysite.local main

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "$1"
}

print_success() {
    echo -e "${GREEN}OK${NC} $1"
}

print_error() {
    echo -e "${RED}X${NC} $1"
}

if [ -z "$1" ]; then
    print_error "Domain argument is required"
    echo "Usage: $0 <domain> <site-folder>"
    exit 1
fi

if [ -z "$2" ]; then
    print_error "Site folder argument is required"
    echo "Usage: $0 <domain> <site-folder>"
    exit 1
fi

DOMAIN="$1"
SITE_FOLDER="sites/$2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"

SITE_PATH="$PROJECT_ROOT/$SITE_FOLDER"

if ! command -v mkcert &> /dev/null; then
    print_error "mkcert is not installed, please install it first."
    exit 1
fi

if [ ! -d "$SITE_PATH" ]; then
    print_error "Site folder does not exist: $SITE_PATH"
    exit 1
fi

print_step "Everything is looking good. Configuring site..."

# ----------------------------------------------------------------------------

WWW_LINK="/var/www/$PROJECT_NAME"
if [ -L "$WWW_LINK" ]; then
    sudo rm "$WWW_LINK"
fi
sudo ln -s "$PROJECT_ROOT" "$WWW_LINK"

CERT_DIR="$PROJECT_ROOT/_cert"
if [ ! -d "$CERT_DIR" ]; then
    mkdir -p "$CERT_DIR"
fi
mkcert -install
cd "$CERT_DIR"
mkcert "$DOMAIN"

mv "${DOMAIN}.pem" "${DOMAIN}.crt"
mv "${DOMAIN}-key.pem" "${DOMAIN}.key"

SITE_CONFIG="/etc/apache2/sites-available/${DOMAIN}.conf"
sudo tee "$SITE_CONFIG" > /dev/null <<EOF
<VirtualHost *:443>
    ServerName ${DOMAIN}
    
    DocumentRoot ${WWW_LINK}/${SITE_FOLDER}
    
    <Directory ${WWW_LINK}/${SITE_FOLDER}>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Never serve site internals directly, even if the rewrite rules are off.
    <DirectoryMatch "^${WWW_LINK}/${SITE_FOLDER}/(config|src|storage)/">
        Require all denied
    </DirectoryMatch>
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile ${CERT_DIR}/${DOMAIN}.crt
    SSLCertificateKeyFile ${CERT_DIR}/${DOMAIN}.key
    
    # Security Headers
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-XSS-Protection "1; mode=block"
    
    # Logging
    ErrorLog \${APACHE_LOG_DIR}/${DOMAIN}-error.log
    CustomLog \${APACHE_LOG_DIR}/${DOMAIN}-access.log combined
</VirtualHost>

# Redirect HTTP to HTTPS
<VirtualHost *:80>
    ServerName ${DOMAIN}
    
    Redirect permanent / https://${DOMAIN}/
</VirtualHost>
EOF

print_success "Site configured successfully."

print_step "Enabling modules and site..."

sudo a2enmod ssl
sudo a2enmod rewrite
sudo a2enmod headers

sudo a2ensite "${DOMAIN}.conf"
sudo systemctl restart apache2

print_success "Deployment complete!"
echo -e "Your site is now available at:"
echo -e "  ${BLUE}https://${DOMAIN}${NC}"
echo -e "${YELLOW}Note:${NC} Make sure to add '${DOMAIN}' to your /etc/hosts file:"

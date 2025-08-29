#!/bin/bash

set -e

echo "Setting up development environment..."

# Update package lists
sudo apt-get update

# Install ecspresso
echo "Installing ecspresso..."
ECSPRESSO_VERSION=$(curl -s https://api.github.com/repos/kayac/ecspresso/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
curl -L "https://github.com/kayac/ecspresso/releases/download/${ECSPRESSO_VERSION}/ecspresso_${ECSPRESSO_VERSION}_linux_amd64.tar.gz" | sudo tar -xz -C /usr/local/bin ecspresso
sudo chmod +x /usr/local/bin/ecspresso

# Verify installations
echo "Verifying installations..."
terraform version
aws --version
ecspresso version

echo "Setup completed successfully!" 

#!/bin/bash
# -----------------------------------------------------------------------------
# This script installs Docker CE on Debian 13 (Trixie) for use with the runmhdock make target
#
# Update package lists
# Install prerequisites for apt
# Add Docker's official GPG key
# Add Docker stable apt repo for Debian 'trixie'
# Install Docker Engine, CLI, containerd, and plugins
# Add the current user to the 'docker' group
# Activate the new group without logging out (via newgrp)
#
sudo apt update
sudo apt install apt-transport-https ca-certificates curl gpg -y
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian trixie stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo usermod -aG docker $(whoami)

# Add ship emoji after whale emoji
sed -i 's/docker\-h 🐳/docker\-h 🐳🚢 /' /etc/bash.bashrc

newgrp docker


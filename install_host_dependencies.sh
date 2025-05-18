#!/bin/bash
set -e

# Ensure script is run as root.
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo or as root."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "Updating package lists..."
apt-get update

echo "Installing essential packages: git, zsh, curl, apt-transport-https, ca-certificates, gnupg, lsb-release..."
apt-get install -y git zsh curl apt-transport-https ca-certificates gnupg lsb-release

#########################
# Docker Installation
#########################
echo "Installing Docker..."
apt-get remove -y docker docker-engine docker.io containerd runc &>/dev/null || true
apt-get install -y ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER"
    echo "User '$SUDO_USER' added to the docker group. Please log out and log back in for changes to take effect."
fi

#########################
# Visual Studio Code Installation
#########################
echo "Installing Visual Studio Code..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
rm packages.microsoft.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list
apt-get update
apt-get install -y code

#########################
# Oh My Zsh and Powerlevel10k Installation
#########################
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

echo "Setting up Oh My Zsh for user $TARGET_USER (home directory: $TARGET_HOME)..."
if [ ! -d "$TARGET_HOME/.oh-my-zsh" ]; then
    sudo -u "$TARGET_USER" git clone https://github.com/ohmyzsh/ohmyzsh.git "$TARGET_HOME/.oh-my-zsh"
fi
if [ ! -d "$TARGET_HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    sudo -u "$TARGET_USER" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$TARGET_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
fi
if [ ! -f "$TARGET_HOME/.zshrc" ]; then
    sudo -u "$TARGET_USER" cp "$TARGET_HOME/.oh-my-zsh/templates/zshrc.zsh-template" "$TARGET_HOME/.zshrc"
fi

echo "Installation complete! Please log out and log back in for changes to take effect."

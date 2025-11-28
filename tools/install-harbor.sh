#!/bin/bash
# install-harbor.sh: Installs Harbor (private registry) inside the container
set -e

# Load environment
if [ -f "/project/.env" ]; then
    set -a
    . "/project/.env"
    set +a
fi

# Check if installation is enabled
if [ "${__INSTALL_HARBOR:-1}" != "1" ]; then
    echo "[INFO] Harbor installation is disabled in .env (__INSTALL_HARBOR != 1)"
    exit 0
fi

# Check for Docker dependency (required for Harbor)
echo "[STEP] Checking Docker dependency..."
if ! command -v docker &> /dev/null; then
    echo "[ERROR] Docker is not installed. Harbor requires Docker to run."
    echo "[INFO] Install Docker first: ./tools/install-docker.sh"
    exit 1
fi

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo "[ERROR] Docker daemon is not running. Start Docker first."
    echo "[INFO] Start Docker: sudo systemctl start docker (Linux) or open Docker Desktop (macOS)"
    exit 1
fi
echo "[INFO] ✅ Docker found and running"

Installation_FilesS="${Installation_FilesS:-/project/Installation_Filess}"
FILENAME="harbor-online-installer.tgz"

# Check if offline installation is available
if [ -f "$Installation_FilesS/harbor/$FILENAME" ]; then
    echo "[INFO] Using offline installation from Installation_Filess"
    tar xzf "$Installation_FilesS/harbor/$FILENAME"
else
    echo "[INFO] Downloading from internet"
    curl -LO https://github.com/goharbor/harbor/releases/latest/download/harbor-online-installer.tgz
    tar xzvf harbor-online-installer.tgz
fi

cd harbor

# Example: create a basic config (edit as needed)
cp harbor.yml.tmpl harbor.yml

# Run installer (edit config for production)
./install.sh

echo "Harbor installation complete."

#!/bin/bash
# install-rke2.sh: Installs RKE2 (Kubernetes) inside the container
set -e

# Load environment
if [ -f "/project/.env" ]; then
    set -a
    . "/project/.env"
    set +a
fi

# Check if installation is enabled
if [ "${__INSTALL_RKE2:-1}" != "1" ]; then
    echo "[INFO] RKE2 installation is disabled in .env (__INSTALL_RKE2 != 1)"
    exit 0
fi

Installation_FilesS="${Installation_FilesS:-/project/Installation_Filess}"

# Check if offline installation is available
if [ -f "$Installation_FilesS/rke2/install.sh" ]; then
    echo "[INFO] Using offline installation from Installation_Filess"
    cd "$Installation_FilesS/rke2"
    # Set environment variables for offline install
    export INSTALL_RKE2_ARTIFACT_PATH="$Installation_FilesS/rke2"
    sh install.sh
else
    echo "[INFO] Downloading and installing RKE2 from internet"
    curl -sfL https://get.rke2.io | sh -
fi

# Enable and start RKE2 server (systemd not available in containers, so run manually)
export PATH=$PATH:/usr/local/bin
rke2 server &

# Wait for RKE2 to start and create kubeconfig
sleep 30
mkdir -p /root/.kube
cp /etc/rancher/rke2/rke2.yaml /root/.kube/config

# Print status
rke2 --version
echo "RKE2 installation complete."

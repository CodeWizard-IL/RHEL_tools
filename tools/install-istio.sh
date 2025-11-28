#!/bin/bash
# install-istio.sh: Installs Istio inside the container
set -e

# Load environment
if [ -f "/project/.env" ]; then
    set -a
    . "/project/.env"
    set +a
fi

# Check if installation is enabled
if [ "${__INSTALL_ISTIO:-1}" != "1" ]; then
    echo "[INFO] Istio installation is disabled in .env (__INSTALL_ISTIO != 1)"
    exit 0
fi

# Check for kubectl dependency
echo "[STEP] Checking kubectl dependency..."
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl is not installed. Istio requires kubectl to deploy to Kubernetes."
    echo "[INFO] Install kubectl first: ./tools/install-kubectl.sh"
    exit 1
fi

# Check for Kubernetes cluster connectivity
echo "[STEP] Checking Kubernetes cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    echo "[ERROR] Cannot connect to Kubernetes cluster."
    echo "[INFO] Configure cluster access: export KUBECONFIG=~/.kube/config"
    exit 1
fi
echo "[INFO] ✅ kubectl found and cluster accessible"

ISTIO_VERSION="${VERSION_ISTIO:-1.20.2}"
Installation_FilesS="${Installation_FilesS:-/project/Installation_Filess}"
FILENAME="istio-${ISTIO_VERSION}-linux-amd64.tar.gz"

# Check if offline installation is available
if [ -f "$Installation_FilesS/istio/$FILENAME" ]; then
    echo "[INFO] Using offline installation from Installation_Filess"
    tar -xzf "$Installation_FilesS/istio/$FILENAME"
    cd istio-${ISTIO_VERSION}
    export PATH=$PWD/bin:$PATH
else
    echo "[INFO] Downloading from internet"
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
    cd istio-${ISTIO_VERSION}
    export PATH=$PWD/bin:$PATH
fi

# Install Istio base and demo profile
istioctl install --set profile=demo -y

# Verify installation
istioctl version

echo "Istio installation complete."

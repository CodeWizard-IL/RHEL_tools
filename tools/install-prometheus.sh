#!/bin/bash
# install-prometheus.sh: Installs Prometheus inside the container
set -e

# Load environment
if [ -f "/project/.env" ]; then
    set -a
    . "/project/.env"
    set +a
fi

# Check if installation is enabled
if [ "${__INSTALL_PROMETHEUS:-1}" != "1" ]; then
    echo "[INFO] Prometheus installation is disabled in .env (__INSTALL_PROMETHEUS != 1)"
    exit 0
fi

# Check for kubectl dependency
echo "[STEP] Checking kubectl dependency..."
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl is not installed. Prometheus requires kubectl to deploy to Kubernetes."
    echo "[INFO] Install kubectl first: ./tools/install-kubectl.sh"
    exit 1
fi

# Check for Helm dependency
echo "[STEP] Checking Helm dependency..."
if ! command -v helm &> /dev/null; then
    echo "[ERROR] Helm is not installed. Prometheus requires Helm to deploy charts."
    echo "[INFO] Install Helm first: ./tools/install-helm.sh"
    exit 1
fi

# Check for Kubernetes cluster connectivity
echo "[STEP] Checking Kubernetes cluster connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    echo "[ERROR] Cannot connect to Kubernetes cluster."
    echo "[INFO] Configure cluster access: export KUBECONFIG=~/.kube/config"
    exit 1
fi
echo "[INFO] ✅ kubectl, Helm found and cluster accessible"

PROMETHEUS_VERSION="${VERSION_PROMETHEUS:-2.48.1}"
Installation_FilesS="${Installation_FilesS:-/project/Installation_Filess}"
FILENAME="prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

# Check if offline installation is available
if [ -f "$Installation_FilesS/prometheus/$FILENAME" ]; then
    echo "[INFO] Using offline installation from Installation_Filess"
    tar -zxf "$Installation_FilesS/prometheus/$FILENAME"
    mv prometheus-${PROMETHEUS_VERSION}.linux-amd64 /opt/prometheus
else
    echo "[INFO] Downloading from internet"
    curl -LO https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${FILENAME}
    tar -zxvf ${FILENAME}
    mv prometheus-${PROMETHEUS_VERSION}.linux-amd64 /opt/prometheus
    rm -f ${FILENAME}
fi

# Start Prometheus (customize as needed)
/opt/prometheus/prometheus &

echo "Prometheus installation complete."

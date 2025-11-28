#!/bin/bash
# install-grafana.sh: Installs Grafana inside the container
set -e

# Load environment
if [ -f "/project/.env" ]; then
    set -a
    . "/project/.env"
    set +a
fi

# Check if installation is enabled
if [ "${__INSTALL_GRAFANA:-1}" != "1" ]; then
    echo "[INFO] Grafana installation is disabled in .env (__INSTALL_GRAFANA != 1)"
    exit 0
fi

# Check for kubectl dependency
echo "[STEP] Checking kubectl dependency..."
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl is not installed. Grafana requires kubectl to deploy to Kubernetes."
    echo "[INFO] Install Grafana first: ./tools/install-kubectl.sh"
    exit 1
fi

# Check for Helm dependency
echo "[STEP] Checking Helm dependency..."
if ! command -v helm &> /dev/null; then
    echo "[ERROR] Helm is not installed. Grafana requires Helm to deploy charts."
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

GRAFANA_VERSION="${VERSION_GRAFANA:-10.2.2}"
Installation_FilesS="${Installation_FilesS:-/project/Installation_Filess}"
FILENAME="grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz"

# Check if offline installation is available
if [ -f "$Installation_FilesS/grafana/$FILENAME" ]; then
    echo "[INFO] Using offline installation from Installation_Filess"
    tar -zxf "$Installation_FilesS/grafana/$FILENAME"
    mv grafana-${GRAFANA_VERSION} /opt/grafana
else
    echo "[INFO] Downloading from internet"
    curl -LO https://dl.grafana.com/oss/release/${FILENAME}
    tar -zxvf ${FILENAME}
    mv grafana-${GRAFANA_VERSION} /opt/grafana
    rm -f ${FILENAME}
fi

# Start Grafana (customize as needed)
/opt/grafana/bin/grafana-server &

echo "Grafana installation complete."

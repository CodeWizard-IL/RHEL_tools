#!/bin/bash
# install-cert-manager.sh: Installs cert-manager inside the container
set -e

# Load environment
if [ -f "/project/.env" ]; then
    set -a
    . "/project/.env"
    set +a
fi

# Check if installation is enabled
if [ "${__INSTALL_CERTMANAGER:-1}" != "1" ]; then
    echo "[INFO] cert-manager installation is disabled in .env (__INSTALL_CERTMANAGER != 1)"
    exit 0
fi

# Check for kubectl dependency
echo "[STEP] Checking kubectl dependency..."
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] kubectl is not installed. cert-manager requires kubectl to deploy to Kubernetes."
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

# Install cert-manager using kubectl and Helm
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml

# Or using Helm (if preferred)
# helm repo add jetstack https://charts.jetstack.io
# helm repo update
# helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace

echo "cert-manager installation complete."

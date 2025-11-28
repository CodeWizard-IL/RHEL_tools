# Load .env from the project root if present (container-safe)
ENV_PATH="/project/.env"
if [ -f "$ENV_PATH" ]; then
    set -a
    . "$ENV_PATH"
    set +a
    echo "[INFO] Loaded environment from: $ENV_PATH"
else
    echo "[WARN] No .env file found at $ENV_PATH. Using default values."
fi
#!/usr/bin/env bash

###############################################################################
# Install kubectl - Kubernetes command-line tool for RHEL
# Supports: RHEL 9.3 x86-64
# Source: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
###############################################################################

set -euo pipefail

# Load common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common-lib.sh"

# Check if installation is enabled
if [ "${__INSTALL_KUBECTL:-1}" != "1" ]; then
    log_info "kubectl installation is disabled in .env (__INSTALL_KUBECTL != 1)"
    exit 0
fi

# Check if kubectl is already installed
if command_exists kubectl; then
    CURRENT_VERSION=$(kubectl version --client --short 2>/dev/null | awk '{print $3}' || echo "unknown")
    log_info "kubectl is already installed (version: ${CURRENT_VERSION})"
    exit 0
fi

log_info "Detected OS: $DETECTED_OS, Architecture: $DETECTED_ARCH"

# Get latest stable version or use from .env
if [ -n "${VERSION_KUBECTL:-}" ]; then
    KUBECTL_VERSION="$VERSION_KUBECTL"
    log_info "Using version from .env: $KUBECTL_VERSION"
else
    log_info "Fetching latest stable kubectl version..."
    KUBECTL_VERSION=$(curl -L -s "${URL_KUBECTL_VERSION}")
    log_info "Latest stable version: $KUBECTL_VERSION"
fi

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Check if offline installation is available
INSTALLATION_BASE="${INSTALLATION_FILES_BASE:-/project/Installation_Files}"
KUBECTL_BINARY="$INSTALLATION_BASE/kubectl/kubectl"

if [ -f "$KUBECTL_BINARY" ]; then
    log_info "Using kubectl from: $KUBECTL_BINARY"
    log_step "Installing kubectl to /usr/local/bin..."
    
    if [[ -w "/usr/local/bin" ]]; then
        cp "$KUBECTL_BINARY" "/usr/local/bin/kubectl"
        chmod +x "/usr/local/bin/kubectl"
    else
        log_warn "Requires sudo to install kubectl"
        sudo cp "$KUBECTL_BINARY" "/usr/local/bin/kubectl"
        sudo chmod 0755 "/usr/local/bin/kubectl"
    fi
else
    log_error "kubectl binary not found at: $KUBECTL_BINARY"
    log_info "Please place kubectl binary in: $INSTALLATION_BASE/kubectl/"
    exit 1
fi

# Verify installation
if command_exists kubectl; then
    INSTALLED_VERSION=$(kubectl version --client --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || kubectl version --client -o json | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    log_info "✅ kubectl successfully installed!"
    log_info "Version: $INSTALLED_VERSION"
    log_info "Location: $(which kubectl)"
    
    # Setup kubectl completion
    setup_completion "kubectl"
else
    log_error "Installation failed. kubectl not found in PATH"
    exit 1
fi

log_info ""
log_info "🎉 Installation complete!"
log_info "Source: ${URL_KUBECTL_DOWNLOAD}"

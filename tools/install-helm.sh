#!/usr/bin/env bash

###############################################################################
# Install Helm - Kubernetes package manager for RHEL
# Supports: RHEL 9.3 x86-64
# Source: https://helm.sh/docs/intro/install/
###############################################################################

set -euo pipefail

# Load common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common-lib.sh"

# Check if installation is enabled
if [ "${__INSTALL_HELM:-1}" != "1" ]; then
    log_info "Helm installation is disabled in .env (__INSTALL_HELM != 1)"
    exit 0
fi

# Check if Helm is already installed
if command_exists helm; then
    CURRENT_VERSION=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    log_info "Helm is already installed (version: ${CURRENT_VERSION})"
    exit 0
fi

log_info "Installing Helm for RHEL..."

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Check if offline installation is available
Installation_FilesS="${Installation_FilesS:-/project/Installation_Filess}"
VERSION="${VERSION_HELM:-v3.13.3}"

if [ -f "$Installation_FilesS/helm/helm-${VERSION}-linux-amd64.tar.gz" ]; then
    log_info "Using offline installation from Installation_Filess"
    cd "$TMP_DIR"
    tar -xzf "$Installation_FilesS/helm/helm-${VERSION}-linux-amd64.tar.gz"
    install_binary "linux-amd64/helm" "${INSTALL_DIR}"
else
    # Check if air-gapped
    if ! curl -s --connect-timeout 5 https://www.google.com > /dev/null 2>&1; then
        log_warn "Air-gapped mode: Helm offline installation file not found, skipping"
        exit 0
    fi
    # Use official installation script from .env
    cd "$TMP_DIR"
    # Use local installation files
    INSTALLATION_BASE="${INSTALLATION_FILES_BASE:-/project/Installation_Files}"
    HELM_TARBALL=$(find "$INSTALLATION_BASE/helm" -type f \( -name "*.tar.gz" -o -name "*.tgz" \) 2>/dev/null | head -1)
    
    if [ -n "$HELM_TARBALL" ] && [ -f "$HELM_TARBALL" ]; then
        log_info "Using Helm from: $HELM_TARBALL"
        tar -xzf "$HELM_TARBALL"
        # Find helm binary in extracted files
        HELM_BIN=$(find . -name helm -type f | head -1)
        if [ -n "$HELM_BIN" ]; then
            chmod +x "$HELM_BIN"
            install_binary "$HELM_BIN" "${INSTALL_DIR}"
            log_info "✅ Helm installed successfully!"
            command_exists helm && helm version
            exit 0
        fi
    fi
    
    log_error "Helm tarball not found in $INSTALLATION_BASE/helm/"
    log_info "Please place a Helm tarball in: $INSTALLATION_BASE/helm/"
    exit 1
    chmod 700 get_helm.sh
    
    # Run installation script
    ./get_helm.sh
fi

# Verify installation
if command_exists helm; then
    INSTALLED_VERSION=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
    log_info "✅ Helm successfully installed!"
    log_info "Version: $INSTALLED_VERSION"
    log_info "Location: $(which helm)"
    
    # Setup helm completion
    setup_completion "helm"
    
    # Add common repositories from .env
    log_info ""
    log_info "Adding common Helm repositories..."
    helm repo add stable "${URL_HELM_REPO_STABLE}" 2>/dev/null || true
    helm repo add bitnami "${URL_HELM_REPO_BITNAMI}" 2>/dev/null || true
    helm repo update
    log_info "✅ Repositories added and updated!"
else
    log_error "Installation failed. Helm not found in PATH"
    exit 1
fi

log_info ""
log_info "🎉 Installation complete!"
log_info "Source: ${URL_HELM_INSTALLER}"

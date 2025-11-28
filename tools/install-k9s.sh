#!/usr/bin/env bash

###############################################################################
# Install k9s - Kubernetes CLI UI for RHEL
# Supports: RHEL 9.3 x86-64
# Source: https://k9scli.io/
###############################################################################

set -euo pipefail

# Load common library
INSTALL_DIR="/usr/local/bin"
sudo mkdir -p "$(dirname "$INSTALL_DIR")"   
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common-lib.sh"

# Check if installation is enabled
if [ "${__INSTALL_K9S:-1}" != "1" ]; then
    log_info "k9s installation is disabled in .env (__INSTALL_K9S != 1)"
    exit 0
fi

# Check if k9s is already installed
if command_exists k9s; then
    CURRENT_VERSION=$(k9s version --short 2>/dev/null | grep Version | awk '{print $2}' || echo "unknown")
    log_info "k9s is already installed (version: ${CURRENT_VERSION})"
    log_info "Skipping k9s installation"
    exit 0
fi

log_info "Detected OS: $DETECTED_OS, Architecture: $DETECTED_ARCH"

# Determine OS naming for k9s
case $DETECTED_OS in
    linux)
        K9S_OS="Linux"
        ;;
    darwin)
        K9S_OS="Darwin"
        ;;
esac

# Get version from .env
if [ -n "${VERSION_K9S:-}" ]; then
    LATEST_VERSION="${VERSION_K9S#v}"
    log_info "Using version from .env: v$LATEST_VERSION"
else
    LATEST_VERSION="0.50.16"
    log_info "Using default version: v$LATEST_VERSION"
fi

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT
cd "$TMP_DIR"

# Check for local installation files
INSTALLATION_BASE="${INSTALLATION_FILES_BASE}"
log_info "Checking for k9s in: $INSTALLATION_BASE/k9s"

# Look for any k9s tarball
K9S_TARBALL=$(find "$INSTALLATION_BASE/k9s" -type f \( -name "*.tar.gz" -o -name "*.tgz" \) 2>/dev/null | head -1)

if [ -n "$K9S_TARBALL" ] && [ -f "$K9S_TARBALL" ]; then
    log_info "Using offline installation from: $K9S_TARBALL"
    tar -xzf "$K9S_TARBALL"
else
    log_error "k9s tarball not found in $INSTALLATION_BASE/k9s/"
    log_info "Please place a k9s tarball in: $INSTALLATION_BASE/k9s/"
    log_info "Example: k9s_Linux_amd64.tar.gz or k9s_Darwin_amd64.tar.gz"
    exit 1
fi

# Install k9s
install_binary "k9s" "${INSTALL_DIR}"

# Verify installation
if command_exists k9s; then
    INSTALLED_VERSION=$(k9s version --short 2>/dev/null | grep Version | awk '{print $2}')
    log_info "✅ k9s successfully installed!"
    log_info "Version: $INSTALLED_VERSION"
    log_info "Location: $(which k9s)"
    
    log_info ""
    log_info "Usage: Run 'k9s' to start the Kubernetes CLI"
else
    log_error "Installation failed. k9s not found in PATH"
    exit 1
fi

log_info ""
log_info "🎉 Installation complete!"
log_info "Source: ${URL_K9S_DOWNLOAD}"

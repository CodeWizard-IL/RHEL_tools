#!/usr/bin/env bash

###############################################################################
# Install Redis Stack - Redis server with modules for RHEL
# Supports: RHEL 9.3 x86-64
# Source: https://redis.io/docs/latest/operate/oss_and_stack/install/install-stack/
###############################################################################

set -euo pipefail

# Load common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common-lib.sh"

# Check if installation is enabled
if [ "${__INSTALL_REDIS:-1}" != "1" ]; then
    log_info "Redis installation is disabled in .env (__INSTALL_REDIS != 1)"
    exit 0
fi

# Check if Redis is already installed
if command_exists redis-server; then
    CURRENT_VERSION=$(redis-server --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    log_info "Redis is already installed (version: ${CURRENT_VERSION})"
    exit 0
fi

log_info "Installing Redis Stack for RHEL..."

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# Check if offline installation is available
Installation_FilesS="${Installation_FilesS:-/project/Installation_Filess}"
VERSION="${VERSION_REDIS:-7.4.0-v0}"

FILENAME="redis-stack-server-${VERSION}.linux-x86_64.tar.gz"

if [ -f "$Installation_FilesS/redis/$FILENAME" ]; then
    log_info "Using offline installation from Installation_Filess"
    cd "$TMP_DIR"
    tar -xzf "$Installation_FilesS/redis/$FILENAME"
    sudo mkdir -p /opt/redis-stack
    sudo mv redis-stack-server-${VERSION}.linux-x86_64/* /opt/redis-stack/
else
    # Check if air-gapped
    if ! curl -s --connect-timeout 5 https://www.google.com > /dev/null 2>&1; then
        log_warn "Air-gapped mode: Redis offline installation file not found, skipping"
        exit 0
    fi
    # Download from internet
    cd "$TMP_DIR"
    # Use local installation files
    INSTALLATION_BASE="${INSTALLATION_FILES_BASE:-/project/Installation_Files}"
    REDIS_TARBALL=$(find "$INSTALLATION_BASE/redis" -type f \( -name "*.tar.gz" -o -name "*.tgz" \) 2>/dev/null | head -1)
    
    if [ -n "$REDIS_TARBALL" ] && [ -f "$REDIS_TARBALL" ]; then
        log_info "Using Redis from: $REDIS_TARBALL"
        cp "$REDIS_TARBALL" "$FILENAME"
    else
        log_error "Redis tarball not found in $INSTALLATION_BASE/redis/"
        log_info "Please place a Redis tarball in: $INSTALLATION_BASE/redis/"
        exit 1
    fi
    
    # Extract
    tar -xzf "$FILENAME"
    sudo mkdir -p /opt/redis-stack
    sudo mv redis-stack-server-${VERSION}.linux-x86_64/* /opt/redis-stack/
fi

# Add to PATH if not already
if ! echo "$PATH" | grep -q "/opt/redis-stack/bin"; then
    echo 'export PATH="/opt/redis-stack/bin:$PATH"' >> ~/.bashrc
    export PATH="/opt/redis-stack/bin:$PATH"
fi

# Verify installation
if command_exists redis-server; then
    INSTALLED_VERSION=$(redis-server --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+(-v[0-9]+)?' || echo "unknown")
    log_info "✅ Redis Stack successfully installed!"
    log_info "Version: $INSTALLED_VERSION"
    log_info "Location: /opt/redis-stack"
    
    # Setup completion if available
    if [ -f "/opt/redis-stack/bin/redis-cli" ]; then
        setup_completion "redis-cli"
    fi
    
    log_info "✅ Installation complete!"
else
    log_error "Installation failed. Redis not found in PATH"
    exit 1
fi

log_info ""
log_info "🎉 Installation complete!"
log_info "Source: ${URL_REDIS_DOWNLOAD}"
log_info "To start Redis: redis-server"
log_info "To use CLI: redis-cli"
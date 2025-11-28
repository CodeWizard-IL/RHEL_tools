#!/usr/bin/env bash

###############################################################################
# Install Docker for RHEL
# Supports: RHEL 9.3 x86-64
# Source: https://docs.docker.com/engine/install/rhel/
###############################################################################

set -euo pipefail

# Load common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common-lib.sh"

# Check if installation is enabled
if [ "${__INSTALL_DOCKER:-1}" != "1" ]; then
    log_info "Docker installation is disabled in .env (__INSTALL_DOCKER != 1)"
    exit 0
fi

# Check if Docker is already installed
if command_exists docker; then
    CURRENT_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    log_info "Docker is already installed (version: ${CURRENT_VERSION})"
    read -p "Do you want to reinstall/upgrade? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Skipping Docker installation"
        exit 0
    fi
fi

log_step "Installing Docker on RHEL..."

# Check if running in air-gapped mode
if [ "${AIRGAPPED_MODE:-1}" = "1" ] || [ "${AIR_GAPPED:-true}" = "true" ]; then
    log_info "Running in AIR-GAPPED mode"
    log_warn "Docker installation in air-gapped mode requires:"
    echo "  1. Docker RPM packages in ${INSTALLATION_FILES_BASE}/docker/"
    echo "  2. Or Docker already installed on the system"
    echo ""
    
    # Check if Docker packages exist locally
    if [ -d "${INSTALLATION_FILES_BASE}/docker" ] && [ -n "$(ls -A ${INSTALLATION_FILES_BASE}/docker/*.rpm 2>/dev/null)" ]; then
        log_step "Installing Docker from local RPM files..."
        sudo dnf install -y "${INSTALLATION_FILES_BASE}/docker"/*.rpm || {
            log_error "Failed to install Docker from local RPM files"
            log_info "Please ensure Docker RPM packages are in ${INSTALLATION_FILES_BASE}/docker/"
            exit 1
        }
    else
        log_error "No Docker RPM packages found in ${INSTALLATION_FILES_BASE}/docker/"
        log_info "Please place Docker RPM packages there or install Docker manually"
        log_info "Required packages: docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin"
        exit 1
    fi
else
    # Online installation (should not reach here in air-gapped mode)
    log_step "Installing prerequisites..."
    sudo dnf install -y yum-utils device-mapper-persistent-data lvm2

    log_step "Adding Docker repository..."
    sudo dnf config-manager --add-repo "${URL_DOCKER_REPO_RHEL}"

    log_step "Installing Docker Engine..."
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Start and enable Docker service
log_step "Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Add current user to docker group
log_step "Adding user to docker group..."
sudo usermod -aG docker $USER

log_info "✅ Docker Engine installed successfully!"
log_warn ""
log_warn "⚠️  IMPORTANT: Please log out and log back in for group changes to take effect"
log_warn "    Or run: newgrp docker"
log_warn ""

# Verify installation
if docker --version &> /dev/null; then
    INSTALLED_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    log_info "Version: $INSTALLED_VERSION"
    log_info "Location: $(which docker)"
    
    # Test Docker (may require newgrp docker first)
    log_step "Testing Docker installation..."
    if sudo docker run --rm hello-world &> /dev/null; then
        log_info "✅ Docker test successful!"
    else
        log_warn "Docker is installed but test requires group permissions (run: newgrp docker)"
    fi
    
    # Show Docker Compose version
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version --short)
        log_info "Docker Compose version: $COMPOSE_VERSION"
    fi
else
    log_error "Installation verification failed. Docker not found in PATH"
    exit 1
fi

log_info ""
log_info "🎉 Installation complete!"
log_info "Source: ${URL_DOCKER_REPO_RHEL}"
log_info ""
log_info "Next steps:"
log_info "  1. Log out and log back in (or run: newgrp docker)"
log_info "  2. Test Docker: docker run hello-world"
log_info "  3. Build an image: docker build -t myapp ."
log_info "  4. Use Docker Compose: docker compose up"

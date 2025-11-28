#!/usr/bin/env bash

###############################################################################
# Install Additional Tools for RHEL DevOps Toolbox
# Installs: yq, jq, istioctl, promtool, chartmuseum, cmctl, rke2
# Sources: Various GitHub releases and official repositories
###############################################################################

set -euo pipefail

# Load common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common-lib.sh"

# Check if installation is enabled
if [ "${__INSTALL_ADDITIONAL_TOOLS:-1}" != "1" ]; then
    log_info "Additional tools installation is disabled in .env (__INSTALL_ADDITIONAL_TOOLS != 1)"
    exit 0
fi

###############################################################################
# Install yq (YAML processor)
###############################################################################
install_yq() {
    log_step "Installing yq (YAML processor)..."
    
    if command_exists yq; then
        log_info "yq already installed: $(yq --version)"
        return 0
    fi
    
    # Use version from .env or fetch latest
    if [ -n "${VERSION_YQ:-}" ]; then
        YQ_VERSION="$VERSION_YQ"
    else
        YQ_VERSION="v$(get_github_latest_version 'mikefarah/yq')"
    fi
    
    log_info "Installing yq version: $YQ_VERSION"
    download_file "${URL_YQ_DOWNLOAD}/${YQ_VERSION}/yq_${DETECTED_OS}_${DETECTED_ARCH}" "/tmp/yq"
    install_binary "/tmp/yq" "${INSTALL_DIR}"
    
    log_info "✅ yq installed: $(yq --version)"
    log_info "Source: ${URL_YQ_DOWNLOAD}"
}

###############################################################################
# Install jq (JSON processor)
###############################################################################
install_jq() {
    log_step "Installing jq (JSON processor)..."
    
    if command_exists jq; then
        log_info "jq already installed: $(jq --version)"
        return 0
    fi
    
    # Use version from .env or fetch latest
    if [ -n "${VERSION_JQ:-}" ]; then
        JQ_VERSION="$VERSION_JQ"
    else
        JQ_VERSION=$(get_github_latest_version 'jqlang/jq')
    fi
    
    # Determine jq OS naming
    if [[ "$DETECTED_OS" == "linux" ]]; then
        JQ_OS="linux-amd64"
    elif [[ "$DETECTED_OS" == "darwin" ]]; then
        JQ_OS="osx-amd64"
    fi
    
    log_info "Installing jq version: $JQ_VERSION"
    download_file "${URL_JQ_DOWNLOAD}/jq-${JQ_VERSION}/jq-${JQ_OS}" "/tmp/jq"
    install_binary "/tmp/jq" "${INSTALL_DIR}"
    
    log_info "✅ jq installed: $(jq --version)"
    log_info "Source: ${URL_JQ_DOWNLOAD}"
}

###############################################################################
# Install Istio CLI (istioctl)
###############################################################################
install_istioctl() {
    log_step "Installing istioctl..."
    
    if command_exists istioctl; then
        log_info "istioctl already installed: $(istioctl version --remote=false 2>/dev/null | head -1)"
        return 0
    fi
    
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    
    cd "$TMP_DIR"
    
    # Use Istio installer with version from .env if available
    if [ -n "${VERSION_ISTIO:-}" ]; then
        export ISTIO_VERSION="${VERSION_ISTIO}"
    fi
    
    log_info "Downloading Istio from: ${URL_ISTIO_INSTALLER}"
    curl -L "${URL_ISTIO_INSTALLER}" | sh -
    
    ISTIO_DIR=$(ls -d istio-* | head -1)
    install_binary "$ISTIO_DIR/bin/istioctl" "${INSTALL_DIR}"
    
    log_info "✅ istioctl installed: $(istioctl version --remote=false)"
    log_info "Source: ${URL_ISTIO_INSTALLER}"
}

###############################################################################
# Install Prometheus CLI tools (promtool)
###############################################################################
install_promtool() {
    log_step "Installing promtool..."
    
    if command_exists promtool; then
        log_info "promtool already installed: $(promtool --version 2>/dev/null | head -1)"
        return 0
    fi
    
    # Use version from .env or fetch latest
    if [ -n "${VERSION_PROMETHEUS:-}" ]; then
        PROM_VERSION="$VERSION_PROMETHEUS"
    else
        PROM_VERSION=$(get_github_latest_version 'prometheus/prometheus')
    fi
    
    log_info "Installing promtool version: $PROM_VERSION"
    
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    
    cd "$TMP_DIR"
    download_file "${URL_PROMETHEUS_DOWNLOAD}/v${PROM_VERSION}/prometheus-${PROM_VERSION}.${DETECTED_OS}-${DETECTED_ARCH}.tar.gz" "prometheus.tar.gz"
    tar -xzf prometheus.tar.gz
    
    install_binary "prometheus-${PROM_VERSION}.${DETECTED_OS}-${DETECTED_ARCH}/promtool" "${INSTALL_DIR}"
    
    log_info "✅ promtool installed: $(promtool --version 2>/dev/null | head -1)"
    log_info "Source: ${URL_PROMETHEUS_DOWNLOAD}"
}

###############################################################################
# Install ChartMuseum
###############################################################################
install_chartmuseum() {
    log_step "Installing ChartMuseum..."
    
    if command_exists chartmuseum; then
        log_info "ChartMuseum already installed: $(chartmuseum --version 2>/dev/null)"
        return 0
    fi
    
    # Use version from .env or fetch latest
    if [ -n "${VERSION_CHARTMUSEUM:-}" ]; then
        CM_VERSION="$VERSION_CHARTMUSEUM"
    else
        CM_VERSION="v$(get_github_latest_version 'helm/chartmuseum')"
    fi
    
    log_info "Installing ChartMuseum version: $CM_VERSION"
    
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    
    cd "$TMP_DIR"
    download_file "${URL_CHARTMUSEUM_DOWNLOAD}/chartmuseum-${CM_VERSION}-${DETECTED_OS}-${DETECTED_ARCH}.tar.gz" "chartmuseum.tar.gz"
    tar -xzf chartmuseum.tar.gz
    
    install_binary "${DETECTED_OS}-${DETECTED_ARCH}/chartmuseum" "${INSTALL_DIR}"
    
    log_info "✅ ChartMuseum installed: $(chartmuseum --version)"
    log_info "Source: ${URL_CHARTMUSEUM_DOWNLOAD}"
}

###############################################################################
# Install cert-manager CLI (cmctl)
###############################################################################
install_cmctl() {
    log_step "Installing cmctl (cert-manager CLI)..."
    
    if command_exists cmctl; then
        log_info "cmctl already installed: $(cmctl version --client 2>/dev/null | head -1)"
        return 0
    fi
    
    if [[ "$DETECTED_OS" == "darwin" ]]; then
        log_warn "cmctl is not officially supported for macOS. Skipping."
        return 0
    fi
    
    log_info "Installing cmctl..."
    
    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT
    
    cd "$TMP_DIR"
    download_file "${URL_CERTMANAGER_DOWNLOAD}/cmctl-${DETECTED_OS}-${DETECTED_ARCH}.tar.gz" "cmctl.tar.gz"
    tar -xzf cmctl.tar.gz
    
    install_binary "cmctl" "${INSTALL_DIR}"
    
    log_info "✅ cmctl installed: $(cmctl version --client 2>/dev/null | head -1)"
    log_info "Source: ${URL_CERTMANAGER_DOWNLOAD}"
}

###############################################################################
# Install RKE2 tools
###############################################################################
install_rke2() {
    log_step "Installing RKE2 tools..."
    
    if command_exists rke2; then
        log_info "RKE2 already installed"
        return 0
    fi
    
    if [[ "$DETECTED_OS" == "darwin" ]]; then
        log_warn "RKE2 is not available for macOS. Skipping."
        return 0
    fi
    
    log_info "Installing RKE2 from: ${URL_RKE2_INSTALLER}"
    curl -sfL "${URL_RKE2_INSTALLER}" | sudo INSTALL_RKE2_TYPE="agent" sh -
    
    log_info "✅ RKE2 tools installed"
    log_info "Source: ${URL_RKE2_INSTALLER}"
}

###############################################################################
# Main installation
###############################################################################
main() {
    log_section "Installing additional DevOps tools for RHEL"
    
    install_yq
    echo ""
    install_jq
    echo ""
    install_istioctl
    echo ""
    install_promtool
    echo ""
    install_chartmuseum
    echo ""
    install_cmctl
    echo ""
    install_rke2
    
    echo ""
    log_section "🎉 All additional tools installed successfully!"
    echo ""
    log_info "Installed tools summary:"
    log_info "  • yq:          $(yq --version 2>/dev/null || echo 'N/A')"
    log_info "  • jq:          $(jq --version 2>/dev/null || echo 'N/A')"
    log_info "  • istioctl:    $(istioctl version --remote=false 2>/dev/null | head -1 || echo 'N/A')"
    log_info "  • promtool:    $(promtool --version 2>/dev/null | head -1 || echo 'N/A')"
    log_info "  • chartmuseum: $(chartmuseum --version 2>/dev/null || echo 'N/A')"
    log_info "  • cmctl:       $(cmctl version --client 2>/dev/null | head -1 || echo 'N/A')"
    log_info "  • rke2:        $(rke2 --version 2>/dev/null | head -1 || echo 'Installed')"
}

main

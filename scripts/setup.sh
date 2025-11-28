#!/usr/bin/env bash

###############################################################################
# RHEL DevOps Toolbox - Setup Script
# Installs all required tools for DevOps workflows in dependency order
###############################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_section() { echo -e "\n${CYAN}═══════════════════════════════════════════════════${NC}"; echo -e "${CYAN}$1${NC}"; echo -e "${CYAN}═══════════════════════════════════════════════════${NC}\n"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make all scripts executable
chmod +x "$SCRIPT_DIR"/*.sh

# Load environment variables
source /project/.env 2>/dev/null || source "$SCRIPT_DIR/../.env" 2>/dev/null || log_warn "No .env file found"

log_section "RHEL 9.3 DevOps Toolbox - Complete Setup"

# Check if running on RHEL or macOS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "rhel" && "$ID" != "centos" && "$ID" != "rocky" && "$ID" != "almalinux" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "Detected macOS. Using Homebrew for package management."
            OS="macos"
        else
            log_warn "This script is optimized for RHEL-based systems or macOS"
            log_warn "Detected: $PRETTY_NAME"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            OS="unknown"
        fi
    else
        OS="rhel"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    log_info "Detected macOS. Using Homebrew for package management."
    OS="macos"
else
    log_warn "Unable to detect OS. Assuming RHEL-like system."
    OS="rhel"
fi

###############################################################################
# Phase 1: System Prerequisites
###############################################################################
install_system_prerequisites() {
    log_section "Phase 1: Installing System Prerequisites"

    # Force air-gapped mode - no internet access
    AIR_GAPPED=true
    log_info "Running in AIR-GAPPED mode - all packages must be pre-installed or available locally"
    log_info "Skipping all DNF/yum/apt/brew package manager operations"

    # Install Java (required for Kafka)
    if [ "${__INSTALL_JAVA:-0}" = "1" ]; then
        log_step "Installing Java JDK..."
        "$SCRIPT_DIR/../tools/install-java.sh"
    fi

    # Skip all package manager operations in air-gapped mode
    log_info "Skipping system package installation (air-gapped mode)"
    log_warn "⚠️  Ensure these packages are pre-installed:"
    echo "  • curl, wget, git, vim, nano"
    echo "  • bash-completion"
    echo "  • ca-certificates"
    echo "  • openssl, openssh"
    echo "  • tar, gzip, unzip"
    echo "  • python3"
    echo ""
    log_warn "⚠️  All installation files must be in: Installation_Files/"
    log_info "✅ System prerequisites phase complete"
}

###############################################################################
# Phase 2: Core Infrastructure Tools
###############################################################################
install_core_infrastructure() {
    log_section "Phase 2: Installing Core Infrastructure"

    # Docker (standalone, required for Harbor)
    if [ "${__INSTALL_DOCKER:-0}" = "1" ]; then
        log_step "Installing Docker..."
        "$SCRIPT_DIR/../tools/install-docker.sh"
    fi

    # kubectl (standalone CLI)
    if [ "${__INSTALL_KUBECTL:-0}" = "1" ]; then
        log_step "Installing kubectl..."
        "$SCRIPT_DIR/../tools/install-kubectl.sh"
    fi

    # Helm (requires kubectl)
    if [ "${__INSTALL_HELM:-0}" = "1" ]; then
        log_step "Installing Helm..."
        "$SCRIPT_DIR/../tools/install-helm.sh"
    fi

    # k9s (standalone CLI, optional)
    if [ "${__INSTALL_K9S:-0}" = "1" ]; then
        log_step "Installing k9s..."
        "$SCRIPT_DIR/../tools/install-k9s.sh"
    fi

    log_info "✅ Core infrastructure installed"
}

###############################################################################
# Phase 3: Kubernetes Cluster (Optional)
###############################################################################
install_kubernetes_cluster() {
    log_section "Phase 3: Kubernetes Cluster Setup (Optional)"

    # Setup Kubernetes cluster with RKE2
    if [ "${__RUN_INIT_CLUSTER:-0}" = "1" ]; then
        log_step "Installing RKE2..."
        "$SCRIPT_DIR/../tools/install-rke2.sh"

        if [ "${__RUN_SETUP_3NODE_CLUSTER:-0}" = "1" ]; then
            log_step "Setting up 3-node cluster..."
            "$SCRIPT_DIR/setup-3node-cluster.sh" setup
        fi

        log_step "Initializing cluster..."
        "$SCRIPT_DIR/init-cluster.sh"
    fi

    log_info "✅ Kubernetes cluster phase complete"
}

###############################################################################
# Phase 4: Kubernetes-Based Tools (Require Cluster)
###############################################################################
install_kubernetes_tools() {
    log_section "Phase 4: Installing Kubernetes Tools"

    # Check if we have a cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_warn "No Kubernetes cluster detected. Skipping cluster-dependent tools."
        log_info "Run 'export KUBECONFIG=~/.kube/config' if you have a cluster config"
        return 0
    fi

    CLUSTER_INFO=$(kubectl cluster-info 2>/dev/null | head -1)
    log_info "Connected to: $CLUSTER_INFO"

    # ArgoCD (requires kubectl + cluster)
    if [ "${__INSTALL_ARGOCD:-0}" = "1" ]; then
        log_step "Installing ArgoCD..."
        "$SCRIPT_DIR/../tools/install-argocd.sh"
    fi

    # cert-manager (requires kubectl + cluster)
    if [ "${__INSTALL_CERTMANAGER:-0}" = "1" ]; then
        log_step "Installing cert-manager..."
        "$SCRIPT_DIR/../tools/install-cert-manager.sh"
    fi

    # Istio (requires kubectl + cluster)
    if [ "${__INSTALL_ISTIO:-0}" = "1" ]; then
        log_step "Installing Istio..."
        "$SCRIPT_DIR/../tools/install-istio.sh"
    fi

    # Prometheus (requires kubectl + Helm + cluster)
    if [ "${__INSTALL_PROMETHEUS:-0}" = "1" ]; then
        log_step "Installing Prometheus..."
        "$SCRIPT_DIR/../tools/install-prometheus.sh"
    fi

    # Grafana (requires kubectl + Helm + cluster)
    if [ "${__INSTALL_GRAFANA:-0}" = "1" ]; then
        log_step "Installing Grafana..."
        "$SCRIPT_DIR/../tools/install-grafana.sh"
    fi

    # Kafka on Kubernetes (requires kubectl + Helm + cluster + Java)
    if [ "${__INSTALL_KAFKA:-0}" = "1" ]; then
        log_step "Installing Kafka on Kubernetes..."
        "$SCRIPT_DIR/../tools/install-kafka-cluster.sh" kubernetes
    fi

    log_info "✅ Kubernetes tools installed"
}

###############################################################################
# Phase 5: Standalone Tools (No Cluster Required)
###############################################################################
install_standalone_tools() {
    log_section "Phase 5: Installing Standalone Tools"

    # Utilities (yq, jq)
    if [ "${__INSTALL_YQ_JQ:-0}" = "1" ]; then
        log_step "Installing utilities..."
        "$SCRIPT_DIR/../tools/install-yq-jq.sh"
    fi

    # ChartMuseum (standalone)
    if [ "${__INSTALL_CHARTMUSEUM:-0}" = "1" ]; then
        log_step "Installing ChartMuseum..."
        "$SCRIPT_DIR/../tools/install-chartmuseum.sh"
    fi

    # Harbor (requires Docker)
    if [ "${__INSTALL_HARBOR:-0}" = "1" ]; then
        if command -v docker &> /dev/null; then
            log_step "Installing Harbor..."
            "$SCRIPT_DIR/../tools/install-harbor.sh"
        else
            log_error "Docker not found. Install Docker first for Harbor."
        fi
    fi

    # NFS tools (system utilities)
    if [ "${__INSTALL_NFS_TOOLS:-0}" = "1" ]; then
        log_step "Installing NFS tools..."
        chmod +x "$SCRIPT_DIR/../tools/install-nfs-tools.sh"
        "$SCRIPT_DIR/../tools/install-nfs-tools.sh"
    
    fi

    # Redis Stack (standalone)
    if [ "${__INSTALL_REDIS:-0}" = "1" ]; then
        log_step "Installing Redis Stack..."
        "$SCRIPT_DIR/../tools/install-redis.sh"
    fi

    # Kafka standalone (requires Java)
    if [ "${__INSTALL_KAFKA:-0}" = "1" ]; then
        log_step "Installing Kafka standalone..."
        "$SCRIPT_DIR/../tools/install-kafka-cluster.sh" standalone
    fi

    log_info "✅ Standalone tools installed"
}

###############################################################################
# Configure Environment
###############################################################################
configure_environment() {
    log_section "Configuring Environment"

    # Setup bash completion
    log_step "Setting up bash completion..."
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        if ! grep -q "bash_completion" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# Enable bash completion" >> ~/.bashrc
            echo "if [ -f /usr/share/bash-completion/bash_completion ]; then" >> ~/.bashrc
            echo "    . /usr/share/bash-completion/bash_completion" >> ~/.bashrc
            echo "fi" >> ~/.bashrc
        fi
    fi

    # Add kubectl alias
    if ! grep -q "alias k=" ~/.bashrc; then
        echo "" >> ~/.bashrc
        echo "# Kubectl alias" >> ~/.bashrc
        echo "alias k=kubectl" >> ~/.bashrc
    fi

    # Source completion files
    if command -v kubectl &> /dev/null; then
        if ! grep -q "kubectl completion" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# Kubectl completion" >> ~/.bashrc
            echo "source <(kubectl completion bash)" >> ~/.bashrc
            echo "complete -F __start_kubectl k" >> ~/.bashrc
        fi
    fi

    if command -v helm &> /dev/null; then
        if ! grep -q "helm completion" ~/.bashrc; then
            echo "" >> ~/.bashrc
            echo "# Helm completion" >> ~/.bashrc
            echo "source <(helm completion bash)" >> ~/.bashrc
        fi
    fi

    log_info "✅ Environment configured"
}

###############################################################################
# Run Verification
###############################################################################
run_verification() {
    log_section "Running Verification"

    if [ -f "$SCRIPT_DIR/doctor.sh" ]; then
        "$SCRIPT_DIR/doctor.sh"
    else
        log_warn "doctor.sh not found. Skipping verification."
    fi
}

###############################################################################
# Main Execution
###############################################################################
main() {
    log_info "Installation will proceed in dependency order:"
    echo "  Phase 1: System Prerequisites (Java, base packages)"
    echo "  Phase 2: Core Infrastructure (Docker, kubectl, Helm)"
    echo "  Phase 3: Kubernetes Cluster (optional)"
    echo "  Phase 4: Kubernetes Tools (require cluster)"
    echo "  Phase 5: Standalone Tools (no cluster required)"
    echo ""

    install_system_prerequisites
    install_core_infrastructure
    install_kubernetes_cluster
    install_kubernetes_tools
    install_standalone_tools
    configure_environment
    run_verification

    log_section "🎉 Setup Complete!"

    cat << EOF

${GREEN}Your RHEL DevOps Toolbox is ready!${NC}

${YELLOW}Next Steps:${NC}

1. ${BLUE}Reload your shell to apply changes:${NC}
   source ~/.bashrc

2. ${BLUE}Verify installation:${NC}
   ./scripts/doctor.sh

3. ${BLUE}Test tools:${NC}
   kubectl version --client
   helm version
   java -version
   docker --version 2>/dev/null || echo "Docker not installed"

4. ${BLUE}Configure Kubernetes access (if using cluster):${NC}
   export KUBECONFIG=~/.kube/config

5. ${BLUE}Run comprehensive tests:${NC}
   ./scripts/test-all.sh

${YELLOW}Installation Summary:${NC}
  ✅ Java JDK (required for Kafka)
  ✅ kubectl + Helm (Kubernetes CLI tools)
  ✅ Docker (container runtime)
  ✅ Kubernetes cluster (optional)
  ✅ Cluster tools (ArgoCD, Istio, Prometheus, etc.)
  ✅ Standalone tools (Kafka, Harbor, utilities)

${YELLOW}Documentation:${NC}
  • README.md          - Complete documentation
  • scripts/           - All installation and utility scripts

${YELLOW}Support:${NC}
  • Run doctor: ./scripts/doctor.sh
  • Check logs: journalctl -xe (Linux) or brew services list (macOS)

EOF
}

# Run main function
main

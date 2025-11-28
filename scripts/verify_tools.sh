#!/usr/bin/env bash

###############################################################################
# RHEL DevOps Toolbox - Doctor Script
# Comprehensive health check for all installed tools
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_section() { echo -e "\n${CYAN}═══════════════════════════════════════════════════${NC}"; echo -e "${CYAN}$1${NC}"; echo -e "${CYAN}═══════════════════════════════════════════════════${NC}\n"; }

# Track issues
ISSUES_FOUND=0
CHECKS_RUN=0

check_tool() {
    local tool_name=$1
    local tool_cmd=$2
    local version_cmd=${3:-"--version"}
    local optional=${4:-false}
    
    CHECKS_RUN=$((CHECKS_RUN + 1))
    
    printf "%-30s" "$tool_name:"
    
    if command -v "$tool_cmd" &> /dev/null; then
        local version=$("$tool_cmd" $version_cmd 2>&1 | head -1 || echo "installed")
        echo -e "${GREEN}✅ $version${NC}"
        return 0
    else
        if [ "$optional" = "true" ]; then
            echo -e "${YELLOW}⚠️  Not installed (optional)${NC}"
        else
            echo -e "${RED}❌ Not installed${NC}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
        return 1
    fi
}

log_section "RHEL DevOps Toolbox - Health Check"

###############################################################################
# System Information
###############################################################################
echo -e "${BLUE}System Information:${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "  OS: $PRETTY_NAME"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
fi
echo ""

###############################################################################
# Check Core Kubernetes Tools
###############################################################################
echo -e "${BLUE}🔍 Kubernetes Tools:${NC}"
check_tool "kubectl" "kubectl" "version --client"
check_tool "helm" "helm" "version --short"
check_tool "k9s" "k9s" "version --short"
echo ""

###############################################################################
# Check Container Tools
###############################################################################
echo -e "${BLUE}🐳 Container Tools:${NC}"
check_tool "docker" "docker"
if command -v docker &> /dev/null; then
    # Check if docker daemon is running
    if docker ps &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker daemon running"
    else
        echo -e "  ${YELLOW}⚠${NC} Docker daemon not running"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(docker compose version 2>&1 | head -1)
    echo -e "docker compose:              ${GREEN}✅ $DOCKER_COMPOSE_VERSION${NC}"
else
    echo -e "docker compose:              ${YELLOW}⚠️  Not available${NC}"
fi
echo ""

###############################################################################
# Check GitOps Tools
###############################################################################
echo -e "${BLUE}🚀 GitOps Tools:${NC}"
check_tool "argocd" "argocd" "version --client --short" "true"
echo ""

###############################################################################
# Check Utilities
###############################################################################
echo -e "${BLUE}🛠️  Utilities:${NC}"
check_tool "yq" "yq" "true"
check_tool "jq" "jq"
echo ""

###############################################################################
# Check Service Mesh Tools
###############################################################################
echo -e "${BLUE}🕸️  Service Mesh Tools:${NC}"
check_tool "istioctl" "istioctl" "version --remote=false" "true"
check_tool "kiali" "kiali" "true"
echo ""

###############################################################################
# Check Monitoring Tools
###############################################################################
echo -e "${BLUE}📊 Monitoring Tools:${NC}"
check_tool "promtool" "promtool" "--version" "true"
check_tool "grafana-cli" "grafana-cli" "true"
echo ""

###############################################################################
# Check Package Management
###############################################################################
echo -e "${BLUE}📦 Package Management:${NC}"
check_tool "chartmuseum" "chartmuseum" "true"
check_tool "cmctl" "cmctl" "true"
echo ""

###############################################################################
# Check Kubernetes Cluster Connection
###############################################################################
echo -e "${BLUE}☸️  Kubernetes Cluster:${NC}"
CHECKS_RUN=$((CHECKS_RUN + 1))

if [ -f "$HOME/.kube/config" ]; then
    echo -e "  ${GREEN}✓${NC} Kubeconfig found: $HOME/.kube/config"
    
    if kubectl cluster-info &> /dev/null; then
        CLUSTER_INFO=$(kubectl cluster-info 2>/dev/null | head -1)
        echo -e "  ${GREEN}✓${NC} Connected to cluster"
        echo -e "    ${CLUSTER_INFO}"
        
        # Get current context
        CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "N/A")
        echo -e "  ${GREEN}✓${NC} Current context: $CURRENT_CONTEXT"
        
        # Get node count
        NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || echo "0")
        echo -e "  ${GREEN}✓${NC} Nodes: $NODE_COUNT"
    else
        echo -e "  ${YELLOW}⚠${NC} Cannot connect to cluster"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
else
    echo -e "  ${YELLOW}⚠${NC} No kubeconfig found"
    echo -e "    Set KUBECONFIG or copy config to ~/.kube/config"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi
echo ""

###############################################################################
# Check NFS Configuration (if needed)
###############################################################################
echo -e "${BLUE}💾 Storage:${NC}"
if systemctl is-active --quiet nfs-server 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} NFS server active"
else
    echo -e "  ${YELLOW}ℹ${NC}  NFS server not running (optional)"
fi
echo ""

###############################################################################
# Summary
###############################################################################
log_section "Summary"

echo -e "${BLUE}Total Checks:${NC}  $CHECKS_RUN"
echo -e "${GREEN}Passed:${NC}        $((CHECKS_RUN - ISSUES_FOUND))"
echo -e "${RED}Issues:${NC}        $ISSUES_FOUND"
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 ALL CHECKS PASSED!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}✅ Your RHEL DevOps Toolbox is ready!${NC}"
else
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠️  FOUND $ISSUES_FOUND ISSUE(S)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}Fix the issues above and run again:${NC}"
    echo "  ./scripts/doctor.sh"
fi

echo ""
echo -e "${CYAN}💡 Quick Fixes:${NC}"
echo "  • Install all tools:     ./scripts/setup.sh"
echo "  • Install Docker:        ./tools/install-docker.sh"
echo "  • Install kubectl:       ./tools/install-kubectl.sh"
echo "  • Start Docker:          sudo systemctl start docker"
echo "  • Configure kubeconfig:  export KUBECONFIG=~/.kube/config"
echo ""

exit $ISSUES_FOUND

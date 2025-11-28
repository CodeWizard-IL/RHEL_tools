#!/bin/bash
###############################################################################
# Container Entry Point
# Initializes the DevOps toolbox container environment
###############################################################################

set -e

echo "========================================"
echo "  RHEL 9.3 DevOps Toolbox"
echo "========================================"
echo ""

# Display installed tool versions
echo "📦 Installed Tools:"
echo "  • kubectl:     $(kubectl version --client --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo 'N/A')"
echo "  • helm:        $(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo 'N/A')"
echo "  • k9s:         $(k9s version --short 2>/dev/null | grep Version | awk '{print $2}' || echo 'N/A')"
echo "  • argocd:      $(argocd version --client --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || echo 'N/A')"
echo "  • docker:      $(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//' || echo 'N/A')"
echo "  • yq:          $(yq --version 2>/dev/null | awk '{print $NF}' || echo 'N/A')"
echo "  • jq:          $(jq --version 2>/dev/null | sed 's/jq-//' || echo 'N/A')"
echo "  • istioctl:    $(istioctl version --remote=false 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'N/A')"
echo "  • promtool:    $(promtool --version 2>/dev/null | grep promtool | awk '{print $3}' || echo 'N/A')"
echo "  • chartmuseum: $(chartmuseum --version 2>/dev/null || echo 'N/A')"
echo ""

# Check for kubeconfig
if [ -f "$HOME/.kube/config" ]; then
    echo "✅ Kubernetes config found"
    if kubectl cluster-info &>/dev/null; then
        echo "✅ Connected to Kubernetes cluster"
    else
        echo "⚠️  Kubernetes config exists but cannot connect to cluster"
    fi
else
    echo "ℹ️  No Kubernetes config found (mount at ~/.kube/config)"
fi

echo ""
echo "📚 Available commands:"
echo "  • doctor.sh        - Check tool installation"
echo "  • verify-tools.sh  - Verify all tools"
echo "  • init-cluster.sh  - Initialize Kubernetes cluster"
echo "  • test-all.sh      - Run all tests"
echo ""
echo "🔗 Workspace: /workspace"
echo ""

# Execute command or start bash
exec "$@"

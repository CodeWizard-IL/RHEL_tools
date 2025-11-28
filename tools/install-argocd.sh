#!/bin/bash

set -e

# Global variables
source "../scripts/common.sh"

# Set the tool name
TOOL_CMD="argocd"
TOOL_NAME="ARGOCD"
TOOL_CMD_VERIFY="argocd version --client"
TOOL_PATH="/usr/local/bin/argocd"

# Copy ArgoCD binary
SRC_PATH="${SCRIPT_DIR}/../Installation_Files/argocd/argocd-${PLATFORM_OS}-${PLATFORM_ARCH}"

# Check if installation is enabled
check_install_enabled "$TOOL_NAME" "$TOOL_CMD_VERIFY"
install_binary "$SRC_PATH" "$DEST_PATH"
log_info "ArgoCD CLI installed successfully."

#!/bin/bash
# install-yq-jq.sh: Installs yq and jq inside the container
set -e

# Load environment
if [ -f "/project/.env" ]; then
    set -a
    . "/project/.env"
    set +a
fi

# Check if installation is enabled
if [ "${__INSTALL_YQ_JQ:-1}" != "1" ]; then
    echo "[INFO] yq/jq installation is disabled in .env (__INSTALL_YQ_JQ != 1)"
    exit 0
fi

INSTALLATION_BASE="${INSTALLATION_FILES_BASE:-/project/Installation_Files}"
YQ_VERSION="${VERSION_YQ:-v4.40.5}"

echo "[INFO] Running in AIR-GAPPED mode"
echo "[INFO] Checking for yq/jq in: $INSTALLATION_BASE/yq-jq"

# Install jq from local files
if [ -f "$INSTALLATION_BASE/yq-jq/jq-linux-amd64" ]; then
    echo "[INFO] Installing jq from local files"
    cp "$INSTALLATION_BASE/yq-jq/jq-linux-amd64" /usr/local/bin/jq
    chmod +x /usr/local/bin/jq
    echo "[INFO] ✅ jq installed: $(jq --version)"
else
    echo "[WARN] jq binary not found in $INSTALLATION_BASE/yq-jq/"
    echo "[INFO] Checking for system jq..."
    if command -v jq &> /dev/null; then
        echo "[INFO] ✅ jq already available: $(jq --version)"
    else
        echo "[ERROR] jq not found. Please place jq-linux-amd64 in $INSTALLATION_BASE/yq-jq/"
    fi
fi

# Install yq from local files
if [ -f "$INSTALLATION_BASE/yq-jq/yq_linux_amd64" ]; then
    echo "[INFO] Installing yq from local files"
    cp "$INSTALLATION_BASE/yq-jq/yq_linux_amd64" /usr/local/bin/yq
    chmod +x /usr/local/bin/yq
    echo "[INFO] ✅ yq installed: $(yq --version)"
else
    echo "[WARN] yq binary not found in $INSTALLATION_BASE/yq-jq/"
    echo "[INFO] Checking for system yq..."
    if command -v yq &> /dev/null; then
        echo "[INFO] ✅ yq already available: $(yq --version)"
    else
        echo "[ERROR] yq not found. Please place yq_linux_amd64 in $INSTALLATION_BASE/yq-jq/"
    fi
fi

echo "[INFO] yq and jq setup complete."

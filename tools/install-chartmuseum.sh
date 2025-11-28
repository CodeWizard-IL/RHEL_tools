#!/bin/bash
# install-chartmuseum.sh: Installs Chartmuseum inside the container
set -e

# Load environment
if [ -f "/project/.env" ]; then
    set -a
    . "/project/.env"
    set +a
fi

# Check if installation is enabled
if [ "${__INSTALL_CHARTMUSEUM:-1}" != "1" ]; then
    echo "[INFO] Chartmuseum installation is disabled in .env (__INSTALL_CHARTMUSEUM != 1)"
    exit 0
fi

CHARTMUSEUM_VERSION="${VERSION_CHARTMUSEUM:-v0.15.0}"
Installation_FilesS="${Installation_FilesS}"
FILENAME="chartmuseum_${CHARTMUSEUM_VERSION}_linux_amd64.tar.gz"

# Check if offline installation is available
if [ -f "$Installation_FilesS/chartmuseum/$FILENAME" ]; then
    echo "[INFO] Using offline installation from Installation_Filess"
    tar xzf "$Installation_FilesS/chartmuseum/$FILENAME"
    mv chartmuseum /usr/local/bin/
    chmod +x /usr/local/bin/chartmuseum

# Example: run Chartmuseum (customize as needed)
chartmuseum --port=8080 &

fi

echo "Chartmuseum installation complete."

#!/bin/bash
# install-nfs-tools.sh: Installs NFS client tools inside the container
set -e

# Load environment
if [ -f "/project/.env" ]; then
    set -a
    . "/project/.env"
    set +a
fi

# Check if installation is enabled
if [ "${__INSTALL_NFS_TOOLS:-1}" != "1" ]; then
    echo "[INFO] NFS tools installation is disabled in .env (__INSTALL_NFS_TOOLS != 1)"
    exit 0
fi

# Install NFS client utilities from local RPM (air-gapped mode)
RPM_DIR="${INSTALLATION_FILES_BASE}/nfs-tools"
if [ ! -d "$RPM_DIR" ]; then
    echo "[ERROR] RPM directory not found at $RPM_DIR. Cannot install NFS tools in air-gapped mode."
    exit 1
fi

echo "[INFO] Installing NFS tools and dependencies from local RPMs: $RPM_DIR"

# Install dependencies first in order
rpm -ivh "$RPM_DIR/libbasicobjects-0.1.1-53.el9.x86_64.rpm" || echo "[WARN] libbasicobjects already installed or failed"
rpm -ivh "$RPM_DIR/libcollection-0.7.0-53.el9.x86_64.rpm" || echo "[WARN] libcollection already installed or failed"
rpm -ivh "$RPM_DIR/libpath_utils-0.2.1-53.el9.x86_64.rpm" || echo "[WARN] libpath_utils already installed or failed"
rpm -ivh "$RPM_DIR/libref_array-0.1.5-53.el9.x86_64.rpm" || echo "[WARN] libref_array already installed or failed"
rpm -ivh "$RPM_DIR/libini_config-1.3.1-53.el9.x86_64.rpm" || echo "[WARN] libini_config already installed or failed"
rpm -ivh "$RPM_DIR/libverto-libevent-0.3.2-3.el9.x86_64.rpm" || echo "[WARN] libverto-libevent already installed or failed"
rpm -ivh "$RPM_DIR/libverto-0.3.2-3.el9.x86_64.rpm" || echo "[WARN] libverto already installed or failed"
rpm -ivh "$RPM_DIR/gssproxy-0.8.4-6.el9.x86_64.rpm" || echo "[WARN] gssproxy already installed or failed"
rpm -ivh "$RPM_DIR/kmod-28-9.el9.x86_64.rpm" || echo "[WARN] kmod already installed or failed"
rpm -ivh "$RPM_DIR/device-mapper-libs-1.02.195-2.el9.x86_64.rpm" || echo "[WARN] device-mapper-libs already installed or failed"
rpm -ivh "$RPM_DIR/libnfsidmap-1-2.5.4-18.el9.x86_64.rpm" || echo "[WARN] libnfsidmap already installed or failed"
rpm -ivh "$RPM_DIR/libtirpc-1.3.3-2.el9.x86_64.rpm" || echo "[WARN] libtirpc already installed or failed"
rpm -ivh "$RPM_DIR/python3-pyyaml-5.4.1-6.el9.x86_64.rpm" || echo "[WARN] python3-pyyaml already installed or failed"
rpm -ivh "$RPM_DIR/e2fsprogs-libs-1.46.5-5.el9.x86_64.rpm" || echo "[WARN] e2fsprogs-libs already installed or failed"
rpm -ivh "$RPM_DIR/quota-nls-4.06-6.el9.noarch.rpm" || echo "[WARN] quota-nls already installed or failed"
rpm -ivh "$RPM_DIR/quota-4.06-6.el9.x86_64.rpm" || echo "[WARN] quota already installed or failed"
rpm -ivh "$RPM_DIR/diffutils-3.7-12.el9.x86_64.rpm" || echo "[WARN] diffutils already installed or failed"
rpm -ivh "$RPM_DIR/libselinux-utils-3.6-1.el9.x86_64.rpm" || echo "[WARN] libselinux-utils already installed or failed"
rpm -ivh "$RPM_DIR/policycoreutils-3.6-2.1.el9.x86_64.rpm" || echo "[WARN] policycoreutils already installed or failed"
rpm -ivh "$RPM_DIR/rpcbind-1.2.6-5.el9.x86_64.rpm" || echo "[WARN] rpcbind already installed or failed"

# Install nfs-utils (try newer version first, fallback to older)
if [ -f "$RPM_DIR/nfs-utils-2.5.4-38.el9.x86_64.rpm" ]; then
    rpm -ivh "$RPM_DIR/nfs-utils-2.5.4-38.el9.x86_64.rpm"
elif [ -f "$RPM_DIR/nfs-utils-2.5.4-20.el9.x86_64.rpm" ]; then
    rpm -ivh "$RPM_DIR/nfs-utils-2.5.4-20.el9.x86_64.rpm"
else
    echo "[ERROR] NFS utils RPM not found."
    exit 1
fi

echo "NFS client tools installation complete."

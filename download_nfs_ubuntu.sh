#!/bin/bash
# download_nfs_ubuntu.sh: Universal download script for RHEL 9 NFS packages
# Works on any Linux distribution with curl or wget
set -e

# Configuration
TARGET_DIR="Installation_Files/nfs-tools"
ARCH="x86_64"
RHEL_MAJOR="9"

# Rocky Linux mirror
MIRROR="https://download.rockylinux.org/pub/rocky/${RHEL_MAJOR}"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}[INFO] Downloading NFS packages for RHEL 9.x from Rocky Linux mirrors${NC}"
echo -e "${GREEN}[INFO] This script works on any Linux distribution${NC}"

# Create target directory
mkdir -p "$TARGET_DIR"

# Detect download tool
DOWNLOAD_CMD=""
if command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl"
    echo -e "${GREEN}[INFO] Using curl for downloads${NC}"
elif command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget"
    echo -e "${GREEN}[INFO] Using wget for downloads${NC}"
else
    echo -e "${RED}[ERROR] Neither curl nor wget is available${NC}"
    echo -e "${YELLOW}[INFO] Please install one of them:${NC}"
    echo -e "${YELLOW}  Ubuntu/Debian: sudo apt-get install curl${NC}"
    echo -e "${YELLOW}  RHEL/CentOS:   sudo yum install curl${NC}"
    echo -e "${YELLOW}  Fedora:        sudo dnf install curl${NC}"
    echo -e "${YELLOW}  Arch:          sudo pacman -S curl${NC}"
    echo -e "${YELLOW}  Alpine:        sudo apk add curl${NC}"
    exit 1
fi

# Function to download a package by searching in repo
download_package() {
    local pkg_name=$1
    local repo=$2  # BaseOS or AppStream
    
    # Get first letter for subdirectory
    local first_char=$(echo "$pkg_name" | cut -c1)
    local pkg_dir="${MIRROR}/${repo}/${ARCH}/os/Packages/${first_char}/"
    
    echo -e "${GREEN}[INFO] Searching for ${pkg_name} in ${repo}...${NC}"
    
    # Get directory listing (compatible with both curl and wget)
    local listing=""
    if [ "$DOWNLOAD_CMD" = "curl" ]; then
        listing=$(curl -s "${pkg_dir}" 2>/dev/null || echo "")
    else
        listing=$(wget -q -O - "${pkg_dir}" 2>/dev/null || echo "")
    fi
    
    if [ -z "$listing" ]; then
        echo -e "${YELLOW}[WARN] Could not access ${repo}/${first_char}/${NC}"
        return 1
    fi
    
    # Find the RPM file (get latest version if multiple exist)
    local rpm_file=$(echo "$listing" | grep -oP "href=\"\K${pkg_name}-[0-9][^\"]*\.rpm(?=\")" | sort -V | tail -1)
    
    # Fallback for systems without grep -P (like macOS or busybox)
    if [ -z "$rpm_file" ]; then
        rpm_file=$(echo "$listing" | grep -o "${pkg_name}-[0-9][^\"]*\.rpm" | sort -V | tail -1)
    fi
    
    if [ -z "$rpm_file" ]; then
        echo -e "${YELLOW}[WARN] Package ${pkg_name} not found in ${repo}${NC}"
        return 1
    fi
    
    # Check if already downloaded
    if [ -f "${TARGET_DIR}/${rpm_file}" ]; then
        echo -e "${YELLOW}[INFO] Already exists: ${rpm_file}${NC}"
        return 0
    fi
    
    # Download the package
    local download_url="${pkg_dir}${rpm_file}"
    echo -e "${GREEN}[INFO] Downloading ${rpm_file}...${NC}"
    
    local download_success=0
    if [ "$DOWNLOAD_CMD" = "curl" ]; then
        if curl -f -L -o "${TARGET_DIR}/${rpm_file}" "${download_url}" 2>/dev/null; then
            download_success=1
        fi
    else
        if wget -q -O "${TARGET_DIR}/${rpm_file}" "${download_url}" 2>/dev/null; then
            download_success=1
        fi
    fi
    
    if [ $download_success -eq 1 ]; then
        echo -e "${GREEN}[SUCCESS] Downloaded ${rpm_file}${NC}"
        return 0
    else
        echo -e "${RED}[ERROR] Failed to download ${rpm_file}${NC}"
        rm -f "${TARGET_DIR}/${rpm_file}" 2>/dev/null
        return 1
    fi
}

# Function to try downloading from both repos
try_download() {
    local pkg=$1
    
    # Try BaseOS first, then AppStream
    if ! download_package "$pkg" "BaseOS"; then
        download_package "$pkg" "AppStream" || echo -e "${YELLOW}[WARN] Could not download ${pkg} from any repo${NC}"
    fi
}

# List of packages to download
echo -e "${GREEN}[INFO] Starting downloads...${NC}"

# Core NFS packages
CORE_PACKAGES=(
    "nfs-utils"
    "rpcbind"
    "libtirpc"
    "libnfsidmap"
    "gssproxy"
    "quota"
    "quota-nls"
)

echo -e "${GREEN}[INFO] Downloading core NFS packages...${NC}"
for pkg in "${CORE_PACKAGES[@]}"; do
    try_download "$pkg"
done

# Library dependencies
LIB_PACKAGES=(
    "libbasicobjects"
    "libcollection"
    "libini_config"
    "libpath_utils"
    "libref_array"
    "libverto"
    "libverto-libevent"
    "libevent"
    "libcom_err"
)

echo -e "${GREEN}[INFO] Downloading library dependencies...${NC}"
for pkg in "${LIB_PACKAGES[@]}"; do
    try_download "$pkg"
done

# System utilities
UTIL_PACKAGES=(
    "kmod"
    "device-mapper-libs"
    "e2fsprogs-libs"
    "diffutils"
    "libselinux-utils"
    "policycoreutils"
    "keyutils"
    "python3-pyyaml"
)

echo -e "${GREEN}[INFO] Downloading system utilities...${NC}"
for pkg in "${UTIL_PACKAGES[@]}"; do
    try_download "$pkg"
done

# Additional dependencies
ADDITIONAL_PACKAGES=(
    "sssd-client"
    "krb5-libs"
    "audit-libs"
    "libcap-ng"
)

echo -e "${GREEN}[INFO] Downloading additional dependencies...${NC}"
for pkg in "${ADDITIONAL_PACKAGES[@]}"; do
    try_download "$pkg" || true
done

# Count downloaded packages
PACKAGE_COUNT=$(ls -1 "$TARGET_DIR"/*.rpm 2>/dev/null | wc -l)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}[INFO] Download summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Packages location: ${TARGET_DIR}${NC}"
echo -e "${GREEN}Total packages downloaded: ${PACKAGE_COUNT}${NC}"

# List all downloaded packages
if [ $PACKAGE_COUNT -gt 0 ]; then
    echo -e "${GREEN}[INFO] Downloaded packages:${NC}"
    ls -1 "$TARGET_DIR"/*.rpm | xargs -n1 basename
    
    # Create manifest
    echo "# NFS Packages for RHEL 9" > "$TARGET_DIR/package-manifest.txt"
    echo "# Downloaded on: $(date)" >> "$TARGET_DIR/package-manifest.txt"
    echo "" >> "$TARGET_DIR/package-manifest.txt"
    ls -1 "$TARGET_DIR"/*.rpm | xargs -n1 basename >> "$TARGET_DIR/package-manifest.txt"
    
    # Create checksums
    echo -e "${GREEN}[INFO] Creating SHA256 checksums...${NC}"
    cd "$TARGET_DIR"
    
    # Check if sha256sum is available, fallback to shasum
    if command -v sha256sum &> /dev/null; then
        sha256sum *.rpm > sha256sums.txt
    elif command -v shasum &> /dev/null; then
        shasum -a 256 *.rpm > sha256sums.txt
    else
        echo -e "${YELLOW}[WARN] No SHA256 tool available (sha256sum or shasum)${NC}"
    fi
    
    cd - > /dev/null
    
    echo -e "${GREEN}[SUCCESS] Download complete!${NC}"
    echo -e "${YELLOW}[NOTE] Transfer the '${TARGET_DIR}' directory to your offline RHEL system${NC}"
else
    echo -e "${RED}[ERROR] No packages were downloaded${NC}"
    exit 1
fi

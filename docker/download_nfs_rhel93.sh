#!/bin/bash
# download_nfs_rhel93.sh: Download NFS packages for RHEL 9.3 offline installation
# Works on any Linux distribution (Ubuntu, Debian, RHEL, CentOS, Fedora, Arch, Alpine, etc.)
set -e

# Configuration
RHEL_VERSION="9.3"
RHEL_MINOR="9"
TARGET_DIR="Installation_Files/nfs-tools"
ARCH="x86_64"
REPO_BASE_URL="https://download.rockylinux.org/pub/rocky/${RHEL_MINOR}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}[INFO] Downloading NFS packages for RHEL ${RHEL_VERSION} (offline installation)${NC}"
echo -e "${GREEN}[INFO] This script works on any Linux distribution${NC}"

# Create target directory
mkdir -p "$TARGET_DIR"

# Detect operating system
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
else
    OS_NAME="unknown"
fi

echo -e "${GREEN}[INFO] Detected OS: ${OS_NAME}${NC}"

# Detect download tool
DOWNLOAD_CMD=""
if command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl"
    echo -e "${GREEN}[INFO] Using curl for downloads${NC}"
elif command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget"
    echo -e "${GREEN}[INFO] Using wget for downloads${NC}"
else
    echo -e "${YELLOW}[WARN] Neither curl nor wget found. Will only work on RHEL-based systems.${NC}"
fi

# Function to download package from Rocky Linux mirrors (for non-RHEL systems)
download_from_url() {
    local package=$1
    
    if [ -z "$DOWNLOAD_CMD" ]; then
        echo -e "${RED}[ERROR] No download tool available${NC}"
        return 1
    fi
    
    echo -e "${GREEN}[INFO] Searching for ${package}...${NC}"
    
    # Try multiple Rocky Linux mirrors
    local MIRRORS=(
        "https://download.rockylinux.org/pub/rocky"
        "https://mirrors.xtom.com/rocky"
        "https://mirror.rackspace.com/rocky"
    )
    
    for MIRROR in "${MIRRORS[@]}"; do
        for repo in BaseOS AppStream; do
            local REPO_URL="${MIRROR}/${RHEL_MINOR}/${repo}/${ARCH}/os/Packages"
            
            # Get the first letter of package name for subdirectory
            local FIRST_CHAR=$(echo "$package" | cut -c1)
            local PKG_URL="${REPO_URL}/${FIRST_CHAR}/"
            
            echo -e "${YELLOW}[DEBUG] Trying ${MIRROR}/${repo}...${NC}"
            
            # List files and find matching package (compatible with both curl and wget)
            local LISTING=""
            if [ "$DOWNLOAD_CMD" = "curl" ]; then
                LISTING=$(curl -s -f "${PKG_URL}" 2>/dev/null || echo "")
            else
                LISTING=$(wget -q -O - "${PKG_URL}" 2>/dev/null || echo "")
            fi
            
            if [ -n "$LISTING" ]; then
                # Extract href links for RPM files matching our package
                local RPM_FILE=$(echo "$LISTING" | grep -oP "href=\"\K${package}-[0-9][^\"]*\.rpm(?=\")" | head -1)
                
                # Fallback for systems without grep -P
                if [ -z "$RPM_FILE" ]; then
                    RPM_FILE=$(echo "$LISTING" | grep -o "${package}-[0-9][^\"]*\.rpm" | head -1)
                fi
                
                if [ -n "$RPM_FILE" ]; then
                    # Check if already downloaded
                    if [ -f "${TARGET_DIR}/${RPM_FILE}" ]; then
                        echo -e "${YELLOW}[INFO] Already exists: ${RPM_FILE}${NC}"
                        return 0
                    fi
                    
                    local DOWNLOAD_URL="${PKG_URL}${RPM_FILE}"
                    echo -e "${GREEN}[INFO] Downloading ${RPM_FILE}...${NC}"
                    
                    local download_success=0
                    if [ "$DOWNLOAD_CMD" = "curl" ]; then
                        if curl -L -f -o "${TARGET_DIR}/${RPM_FILE}" "${DOWNLOAD_URL}" 2>/dev/null; then
                            download_success=1
                        fi
                    else
                        if wget -q -O "${TARGET_DIR}/${RPM_FILE}" "${DOWNLOAD_URL}" 2>/dev/null; then
                            download_success=1
                        fi
                    fi
                    
                    if [ $download_success -eq 1 ]; then
                        echo -e "${GREEN}[SUCCESS] Downloaded ${RPM_FILE}${NC}"
                        return 0
                    fi
                fi
            fi
        done
    done
    
    echo -e "${YELLOW}[WARN] Could not find or download package: ${package}${NC}"
    return 1
}

# Function to download package and its dependencies
download_package() {
    local package=$1
    
    if [ "$OS_NAME" = "ubuntu" ] || [ "$OS_NAME" = "debian" ] || [ "$OS_NAME" = "arch" ] || [ "$OS_NAME" = "alpine" ] || [ "$OS_NAME" = "unknown" ]; then
        # Non-RHEL systems: download from Rocky Linux repos
        download_from_url "$package"
    else
        # RHEL/CentOS/Fedora: use native tools
        echo -e "${GREEN}[INFO] Downloading ${package} and dependencies...${NC}"
        
        if command -v dnf &> /dev/null; then
            dnf download --resolve --destdir="$TARGET_DIR" "$package" 2>&1 | grep -v "already downloaded" || true
        elif command -v yumdownloader &> /dev/null; then
            yumdownloader --resolve --destdir="$TARGET_DIR" "$package" || true
        else
            # Fallback to direct download if no package manager available
            echo -e "${YELLOW}[WARN] No package manager available, using direct download${NC}"
            download_from_url "$package"
        fi
    fi
}

# Install required tools based on OS (only on RHEL-based systems)
if [ "$OS_NAME" = "rhel" ] || [ "$OS_NAME" = "centos" ] || [ "$OS_NAME" = "rocky" ] || [ "$OS_NAME" = "almalinux" ] || [ "$OS_NAME" = "fedora" ]; then
    # Ensure yum-utils is installed for yumdownloader
    if ! command -v yumdownloader &> /dev/null && ! command -v dnf &> /dev/null; then
        echo -e "${YELLOW}[INFO] Installing yum-utils...${NC}"
        yum install -y yum-utils 2>/dev/null || dnf install -y yum-utils 2>/dev/null || true
    fi
fi

# Core NFS packages and dependencies (exact package names for RHEL 9)
PACKAGES=(
    "nfs-utils"
    "rpcbind"
    "libtirpc"
    "gssproxy"
    "quota"
    "quota-nls"
    "libbasicobjects"
    "libcollection"
    "libini_config"
    "libpath_utils"
    "libref_array"
    "libverto"
    "libverto-libevent"
    "kmod"
    "device-mapper-libs"
    "libnfsidmap"
    "python3-pyyaml"
    "e2fsprogs-libs"
    "diffutils"
    "libselinux-utils"
    "policycoreutils"
    "keyutils"
    "libcom_err"
    "libevent"
)

echo -e "${GREEN}[INFO] Starting package downloads...${NC}"
echo -e "${GREEN}[INFO] Target directory: ${TARGET_DIR}${NC}"
echo -e "${GREEN}[INFO] Method: ${OS_NAME} compatible download${NC}"

# Download each package with dependencies
for package in "${PACKAGES[@]}"; do
    download_package "$package"
done

# For Ubuntu systems, we need to manually handle dependencies
if [ "$OS_NAME" = "ubuntu" ] || [ "$OS_NAME" = "debian" ]; then
    echo -e "${GREEN}[INFO] Downloading additional known dependencies for RHEL 9.3...${NC}"
    
    # Additional specific packages that might be dependencies
    ADDITIONAL_PACKAGES=(
        "sssd-client"
        "krb5-libs"
        "libselinux"
        "audit-libs"
        "libcap-ng"
        "systemd-libs"
        "dbus-libs"
        "libblkid"
        "libuuid"
        "libmount"
        "libsmartcols"
        "libfdisk"
        "glibc"
        "bash"
        "coreutils"
        "util-linux"
    )
    
    for package in "${ADDITIONAL_PACKAGES[@]}"; do
        download_package "$package" || true
    done
fi

# List downloaded packages
echo -e "${GREEN}[INFO] Downloaded packages:${NC}"
ls -lh "$TARGET_DIR"/*.rpm 2>/dev/null || echo -e "${YELLOW}[WARN] No RPM files found${NC}"

# Count packages
PACKAGE_COUNT=$(ls -1 "$TARGET_DIR"/*.rpm 2>/dev/null | wc -l)
echo -e "${GREEN}[INFO] Total packages downloaded: ${PACKAGE_COUNT}${NC}"

# Create a manifest file
MANIFEST_FILE="$TARGET_DIR/package-manifest.txt"
echo "# NFS Packages for RHEL $RHEL_VERSION" > "$MANIFEST_FILE"
echo "# Downloaded on: $(date)" >> "$MANIFEST_FILE"
echo "# Architecture: $ARCH" >> "$MANIFEST_FILE"
echo "" >> "$MANIFEST_FILE"
ls -1 "$TARGET_DIR"/*.rpm 2>/dev/null | xargs -n1 basename >> "$MANIFEST_FILE"

echo -e "${GREEN}[INFO] Package manifest created: ${MANIFEST_FILE}${NC}"

# Create installation order file
INSTALL_ORDER="$TARGET_DIR/install-order.txt"
cat > "$INSTALL_ORDER" << 'EOF'
# Installation order for NFS packages (dependencies first)
# Use: while read rpm; do rpm -ivh "$rpm" || echo "Already installed or failed: $rpm"; done < install-order.txt

# Base libraries
libbasicobjects-*.rpm
libcollection-*.rpm
libpath_utils-*.rpm
libref_array-*.rpm
libini_config-*.rpm
libverto-*.rpm
libverto-libevent-*.rpm
libevent-*.rpm
libcom_err-*.rpm

# System utilities
kmod-*.rpm
device-mapper-libs-*.rpm
e2fsprogs-libs-*.rpm
diffutils-*.rpm
libselinux-utils-*.rpm
policycoreutils-*.rpm

# NFS dependencies
keyutils-*.rpm
libtirpc-*.rpm
libnfsidmap-*.rpm
python3-pyyaml-*.rpm
quota-nls-*.rpm
quota-[0-9]*.rpm
gssproxy-*.rpm
sssd-client-*.rpm

# RPC and NFS
rpcbind-*.rpm
nfs-utils-*.rpm
EOF

echo -e "${GREEN}[INFO] Installation order file created: ${INSTALL_ORDER}${NC}"

# Create checksum file
echo -e "${GREEN}[INFO] Creating SHA256 checksums...${NC}"
cd "$TARGET_DIR"
if ls *.rpm 1> /dev/null 2>&1; then
    # Check if sha256sum is available, fallback to shasum (for macOS/BSD)
    if command -v sha256sum &> /dev/null; then
        sha256sum *.rpm > sha256sums.txt 2>/dev/null || true
    elif command -v shasum &> /dev/null; then
        shasum -a 256 *.rpm > sha256sums.txt 2>/dev/null || true
    else
        echo -e "${YELLOW}[WARN] No SHA256 tool available (sha256sum or shasum)${NC}"
    fi
else
    echo -e "${YELLOW}[WARN] No RPM files found to checksum${NC}"
fi
cd - > /dev/null

# Verify we have the essential packages
echo -e "${GREEN}[INFO] Verifying essential packages...${NC}"
ESSENTIAL_PACKAGES=("nfs-utils" "rpcbind" "libtirpc")
MISSING_ESSENTIAL=0

for essential in "${ESSENTIAL_PACKAGES[@]}"; do
    if ! ls "$TARGET_DIR"/${essential}-*.rpm 1> /dev/null 2>&1; then
        echo -e "${RED}[ERROR] Essential package missing: ${essential}${NC}"
        MISSING_ESSENTIAL=1
    else
        echo -e "${GREEN}[OK] Found: ${essential}${NC}"
    fi
done

if [ $MISSING_ESSENTIAL -eq 1 ]; then
    echo -e "${RED}[WARNING] Some essential packages are missing!${NC}"
    echo -e "${YELLOW}[INFO] You may need to download them manually from:${NC}"
    echo -e "${YELLOW}       https://download.rockylinux.org/pub/rocky/${RHEL_MINOR}/BaseOS/${ARCH}/os/Packages/${NC}"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}[SUCCESS] NFS package download complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Packages location: ${TARGET_DIR}${NC}"
echo -e "${GREEN}Total packages: ${PACKAGE_COUNT}${NC}"
echo -e "${YELLOW}[NOTE] Transfer the entire '${TARGET_DIR}' directory to your offline system${NC}"
echo -e "${YELLOW}[NOTE] Use 'install-nfs-tools.sh' on the offline system to install${NC}"

if [ "$OS_NAME" = "ubuntu" ] || [ "$OS_NAME" = "debian" ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}[UBUNTU/DEBIAN NOTE] Alternative download method${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}If some packages failed to download, you can manually download from:${NC}"
    echo -e "${YELLOW}1. https://download.rockylinux.org/pub/rocky/${RHEL_MINOR}/BaseOS/${ARCH}/os/Packages/${NC}"
    echo -e "${YELLOW}2. https://download.rockylinux.org/pub/rocky/${RHEL_MINOR}/AppStream/${ARCH}/os/Packages/${NC}"
    echo -e "${YELLOW}Or use a RHEL/Rocky/Alma Linux system to run this script for better results.${NC}"
elif [ "$OS_NAME" = "arch" ] || [ "$OS_NAME" = "alpine" ] || [ "$OS_NAME" = "unknown" ]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}[${OS_NAME} NOTE] Cross-distribution download${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}This script downloads RHEL 9 packages from Rocky Linux mirrors.${NC}"
    echo -e "${YELLOW}For best results, run this script on a RHEL-based system.${NC}"
    echo -e "${YELLOW}Manual download: https://download.rockylinux.org/pub/rocky/${RHEL_MINOR}/${NC}"
fi

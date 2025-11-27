#!/bin/bash

#####################################################################
# RHEL Air Gap Package Download Script
# 
# This script downloads RHEL packages and their dependencies
# for installation on air-gapped systems.
#
# Usage: ./download-packages.sh [OPTIONS]
#####################################################################

set -e

# Default values
CONFIG_FILE="packages.conf"
OUTPUT_DIR="repo-export"
REPO_NAME="local-airgap-repo"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Download RHEL packages and dependencies for air-gapped installation.

OPTIONS:
    -c, --config FILE     Package configuration file (default: packages.conf)
    -o, --output DIR      Output directory (default: repo-export)
    -n, --name NAME       Repository name (default: local-airgap-repo)
    -h, --help           Display this help message

EXAMPLES:
    $0
    $0 -c custom-packages.conf -o /tmp/myrepo
    $0 --config packages.conf --output ./offline-repo

EOF
    exit 1
}

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$*${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_msg "$RED" "ERROR: This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check required commands
check_dependencies() {
    local missing_deps=()
    
    # Check for package manager
    if command -v dnf &> /dev/null; then
        PKG_MGR="dnf"
    elif command -v yum &> /dev/null; then
        PKG_MGR="yum"
    else
        print_msg "$RED" "ERROR: Neither dnf nor yum found on system"
        exit 1
    fi
    
    # Check for createrepo
    if command -v createrepo_c &> /dev/null; then
        CREATEREPO="createrepo_c"
    elif command -v createrepo &> /dev/null; then
        CREATEREPO="createrepo"
    else
        missing_deps+=("createrepo_c or createrepo")
    fi
    
    # Check for repoquery
    if ! command -v repoquery &> /dev/null; then
        if [[ "$PKG_MGR" == "dnf" ]]; then
            missing_deps+=("dnf-plugins-core")
        else
            missing_deps+=("yum-utils")
        fi
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_msg "$RED" "ERROR: Missing required dependencies: ${missing_deps[*]}"
        print_msg "$YELLOW" "Install them with: $PKG_MGR install ${missing_deps[*]}"
        exit 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -n|--name)
                REPO_NAME="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                print_msg "$RED" "ERROR: Unknown option: $1"
                usage
                ;;
        esac
    done
}

# Read packages from config file
read_packages() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_msg "$RED" "ERROR: Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Read non-empty, non-comment lines
    mapfile -t PACKAGES < <(grep -v '^#' "$CONFIG_FILE" | grep -v '^[[:space:]]*$')
    
    if [[ ${#PACKAGES[@]} -eq 0 ]]; then
        print_msg "$RED" "ERROR: No packages found in $CONFIG_FILE"
        exit 1
    fi
    
    print_msg "$GREEN" "Found ${#PACKAGES[@]} packages/groups in configuration"
}

# Create output directory structure
create_output_dir() {
    print_msg "$YELLOW" "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR/packages"
    mkdir -p "$OUTPUT_DIR/repodata"
}

# Download packages and dependencies
download_packages() {
    print_msg "$YELLOW" "Downloading packages and dependencies..."
    
    local download_dir="$OUTPUT_DIR/packages"
    
    # Use downloadonly plugin to download packages with dependencies
    if [[ "$PKG_MGR" == "dnf" ]]; then
        print_msg "$GREEN" "Using dnf to download packages..."
        dnf download --resolve --alldeps --downloaddir="$download_dir" "${PACKAGES[@]}" || {
            print_msg "$RED" "ERROR: Failed to download packages"
            exit 1
        }
    else
        print_msg "$GREEN" "Using yumdownloader to download packages..."
        yumdownloader --resolve --destdir="$download_dir" "${PACKAGES[@]}" || {
            print_msg "$RED" "ERROR: Failed to download packages"
            exit 1
        }
    fi
    
    local pkg_count=$(find "$download_dir" -name "*.rpm" | wc -l)
    print_msg "$GREEN" "Downloaded $pkg_count RPM packages"
}

# Create repository metadata
create_repo_metadata() {
    print_msg "$YELLOW" "Creating repository metadata..."
    
    cd "$OUTPUT_DIR"
    $CREATEREPO --update . || {
        print_msg "$RED" "ERROR: Failed to create repository metadata"
        exit 1
    }
    
    print_msg "$GREEN" "Repository metadata created successfully"
}

# Generate repo file for reference
generate_repo_file() {
    local repo_file="$OUTPUT_DIR/${REPO_NAME}.repo"
    
    print_msg "$YELLOW" "Generating repository configuration file..."
    
    cat > "$repo_file" << EOF
# Local Air-Gapped Repository Configuration
# Copy this file to /etc/yum.repos.d/ on the air-gapped system
# Adjust the baseurl to match your repository location

[$REPO_NAME]
name=Local Air-Gapped Repository
baseurl=file:///var/local-repo
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

# For network-based repository (HTTP), use:
# baseurl=http://<server-ip>/local-repo
EOF
    
    print_msg "$GREEN" "Repository configuration file created: $repo_file"
}

# Create summary file
create_summary() {
    local summary_file="$OUTPUT_DIR/TRANSFER-GUIDE.txt"
    
    cat > "$summary_file" << EOF
================================================================
RHEL Air Gap Package Repository - Transfer Guide
================================================================

Generated on: $(date)
Number of packages: $(find "$OUTPUT_DIR/packages" -name "*.rpm" 2>/dev/null | wc -l)
Repository size: $(du -sh "$OUTPUT_DIR" | cut -f1)

NEXT STEPS:
-----------

1. TRANSFER THIS DIRECTORY
   Copy the entire '$OUTPUT_DIR' directory to your air-gapped system
   using approved transfer media (USB drive, DVD, etc.)

   Example:
     rsync -av $OUTPUT_DIR/ <destination>
     # or
     tar czf $(basename "$OUTPUT_DIR").tar.gz $OUTPUT_DIR/

2. ON THE AIR-GAPPED SYSTEM
   Run the setup-local-repo.sh script:
     sudo ./setup-local-repo.sh /path/to/$OUTPUT_DIR

3. INSTALL PACKAGES
   Once the repository is set up, install packages using:
     sudo yum install <package-name>
     # or
     sudo dnf install <package-name>

INCLUDED FILES:
---------------
  packages/          - Downloaded RPM packages
  repodata/          - Repository metadata
  ${REPO_NAME}.repo  - Example repository configuration
  TRANSFER-GUIDE.txt - This file

================================================================
For more information, see the README.md file
================================================================
EOF
    
    print_msg "$GREEN" "Transfer guide created: $summary_file"
}

# Display completion summary
display_summary() {
    local pkg_count=$(find "$OUTPUT_DIR/packages" -name "*.rpm" 2>/dev/null | wc -l)
    local repo_size=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
    
    echo ""
    print_msg "$GREEN" "================================================================"
    print_msg "$GREEN" "                   DOWNLOAD COMPLETE"
    print_msg "$GREEN" "================================================================"
    echo ""
    print_msg "$GREEN" "Output directory: $OUTPUT_DIR"
    print_msg "$GREEN" "Packages downloaded: $pkg_count"
    print_msg "$GREEN" "Total size: $repo_size"
    echo ""
    print_msg "$YELLOW" "Next steps:"
    echo "  1. Transfer '$OUTPUT_DIR' to your air-gapped system"
    echo "  2. Run setup-local-repo.sh on the air-gapped system"
    echo "  3. Install packages using yum/dnf"
    echo ""
    print_msg "$YELLOW" "See $OUTPUT_DIR/TRANSFER-GUIDE.txt for detailed instructions"
    print_msg "$GREEN" "================================================================"
    echo ""
}

# Main execution
main() {
    print_msg "$GREEN" "RHEL Air Gap Package Downloader"
    print_msg "$GREEN" "================================"
    echo ""
    
    parse_args "$@"
    check_root
    check_dependencies
    read_packages
    create_output_dir
    download_packages
    create_repo_metadata
    generate_repo_file
    create_summary
    display_summary
}

# Run main function
main "$@"

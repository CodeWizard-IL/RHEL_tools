#!/bin/bash

#####################################################################
# RHEL Air Gap Local Repository Setup Script
# 
# This script sets up a local YUM/DNF repository on an air-gapped
# system using packages downloaded by download-packages.sh
#
# Usage: ./setup-local-repo.sh [OPTIONS] REPO_DIR
#####################################################################

set -e

# Default values
REPO_NAME="local-airgap-repo"
REPO_PATH="/var/local-repo"
VERIFY_PACKAGES=true

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] REPO_DIR

Set up a local YUM/DNF repository on an air-gapped system.

ARGUMENTS:
    REPO_DIR             Directory containing downloaded packages

OPTIONS:
    -n, --name NAME      Repository name (default: local-airgap-repo)
    -p, --path PATH      Repository mount point (default: /var/local-repo)
    --no-verify         Skip package verification
    -h, --help          Display this help message

EXAMPLES:
    $0 /path/to/repo-export
    $0 -n my-repo -p /opt/my-repo /path/to/repo-export
    $0 --name offline-repo --path /mnt/offline-repo ./repo-export

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
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_msg "$RED" "ERROR: Missing required dependencies: ${missing_deps[*]}"
        print_msg "$YELLOW" "These packages must be included in your air-gapped repository"
        print_msg "$YELLOW" "Or install from RHEL installation media"
        exit 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                REPO_NAME="$2"
                shift 2
                ;;
            -p|--path)
                REPO_PATH="$2"
                shift 2
                ;;
            --no-verify)
                VERIFY_PACKAGES=false
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                print_msg "$RED" "ERROR: Unknown option: $1"
                usage
                ;;
            *)
                SOURCE_DIR="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$SOURCE_DIR" ]]; then
        print_msg "$RED" "ERROR: Repository directory not specified"
        usage
    fi
}

# Validate source directory
validate_source() {
    if [[ ! -d "$SOURCE_DIR" ]]; then
        print_msg "$RED" "ERROR: Source directory does not exist: $SOURCE_DIR"
        exit 1
    fi
    
    # Check for packages directory or RPM files
    local rpm_count=0
    if [[ -d "$SOURCE_DIR/packages" ]]; then
        rpm_count=$(find "$SOURCE_DIR/packages" -name "*.rpm" 2>/dev/null | wc -l)
    else
        rpm_count=$(find "$SOURCE_DIR" -name "*.rpm" 2>/dev/null | wc -l)
    fi
    
    if [[ $rpm_count -eq 0 ]]; then
        print_msg "$RED" "ERROR: No RPM packages found in $SOURCE_DIR"
        exit 1
    fi
    
    print_msg "$GREEN" "Found $rpm_count RPM packages in source directory"
}

# Copy repository to target location
copy_repository() {
    print_msg "$YELLOW" "Creating repository directory: $REPO_PATH"
    
    # Create target directory
    mkdir -p "$REPO_PATH"
    
    # Copy files
    print_msg "$YELLOW" "Copying packages to $REPO_PATH..."
    
    if [[ -d "$SOURCE_DIR/packages" ]]; then
        # If packages are in a subdirectory, copy them to root of repo
        # Check if there are any files to copy first
        if [[ -n "$(ls -A "$SOURCE_DIR/packages" 2>/dev/null)" ]]; then
            cp -r "$SOURCE_DIR/packages"/* "$REPO_PATH/" 2>/dev/null || {
                print_msg "$RED" "ERROR: Failed to copy packages"
                exit 1
            }
        else
            print_msg "$RED" "ERROR: No files found in $SOURCE_DIR/packages"
            exit 1
        fi
    else
        # Copy all RPM files from source
        local rpm_files
        rpm_files=$(find "$SOURCE_DIR" -name "*.rpm")
        if [[ -z "$rpm_files" ]]; then
            print_msg "$RED" "ERROR: No RPM files found in $SOURCE_DIR"
            exit 1
        fi
        find "$SOURCE_DIR" -name "*.rpm" -exec cp {} "$REPO_PATH/" \; || {
            print_msg "$RED" "ERROR: Failed to copy packages"
            exit 1
        }
    fi
    
    # Copy repodata if it exists
    if [[ -d "$SOURCE_DIR/repodata" ]]; then
        print_msg "$YELLOW" "Copying existing repository metadata..."
        cp -r "$SOURCE_DIR/repodata" "$REPO_PATH/" 2>/dev/null || true
    fi
    
    # Copy GPG keys if they exist
    if [[ -f "$SOURCE_DIR/RPM-GPG-KEY-redhat-release" ]]; then
        print_msg "$YELLOW" "Copying GPG keys..."
        mkdir -p "$REPO_PATH/gpgkeys"
        cp "$SOURCE_DIR"/RPM-GPG-KEY-* "$REPO_PATH/gpgkeys/" 2>/dev/null || true
        print_msg "$GREEN" "GPG keys copied to $REPO_PATH/gpgkeys/"
        print_msg "$YELLOW" "To import keys, run: sudo rpm --import $REPO_PATH/gpgkeys/RPM-GPG-KEY-*"
    fi
    
    print_msg "$GREEN" "Repository files copied successfully"
}

# Verify packages
verify_packages() {
    if [[ "$VERIFY_PACKAGES" == false ]]; then
        print_msg "$YELLOW" "Skipping package verification (--no-verify specified)"
        return
    fi
    
    print_msg "$YELLOW" "Verifying RPM packages..."
    
    local verified=0
    local failed=0
    
    while IFS= read -r rpm_file; do
        if rpm -K "$rpm_file" &> /dev/null; then
            ((verified++))
        else
            ((failed++))
            print_msg "$RED" "WARNING: Verification failed for $(basename "$rpm_file")"
        fi
    done < <(find "$REPO_PATH" -name "*.rpm")
    
    print_msg "$GREEN" "Verified: $verified packages"
    if [[ $failed -gt 0 ]]; then
        print_msg "$YELLOW" "WARNING: $failed packages failed verification"
        print_msg "$YELLOW" "This may be normal if GPG keys are not available"
    fi
}

# Create or update repository metadata
create_metadata() {
    print_msg "$YELLOW" "Creating repository metadata..."
    
    cd "$REPO_PATH"
    
    if [[ -d "repodata" ]]; then
        # Update existing metadata
        $CREATEREPO --update . || {
            print_msg "$RED" "ERROR: Failed to update repository metadata"
            exit 1
        }
    else
        # Create new metadata
        $CREATEREPO . || {
            print_msg "$RED" "ERROR: Failed to create repository metadata"
            exit 1
        }
    fi
    
    print_msg "$GREEN" "Repository metadata created successfully"
}

# Create repository configuration file
create_repo_config() {
    local repo_file="/etc/yum.repos.d/${REPO_NAME}.repo"
    
    print_msg "$YELLOW" "Creating repository configuration..."
    
    # Backup existing repo file if it exists
    if [[ -f "$repo_file" ]]; then
        print_msg "$YELLOW" "Backing up existing repository file..."
        cp "$repo_file" "${repo_file}.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Create new repo file
    # Detect GPG keys dynamically
    local gpg_keys=""
    if [[ -d "$REPO_PATH/gpgkeys" ]] && [[ -n "$(ls -A "$REPO_PATH/gpgkeys"/RPM-GPG-KEY-* 2>/dev/null)" ]]; then
        # Use keys from the repository
        gpg_keys="file://$REPO_PATH/gpgkeys/RPM-GPG-KEY-redhat-release"
        print_msg "$GREEN" "Found GPG keys in repository at $REPO_PATH/gpgkeys/"
    elif [[ -d "/etc/pki/rpm-gpg" ]] && [[ -n "$(ls -A /etc/pki/rpm-gpg/RPM-GPG-KEY-* 2>/dev/null)" ]]; then
        # Use system keys
        gpg_keys="file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release"
        print_msg "$GREEN" "Using system GPG keys from /etc/pki/rpm-gpg/"
    else
        print_msg "$YELLOW" "WARNING: No GPG keys found. Repository will be created without GPG verification."
    fi
    
    cat > "$repo_file" << EOF
# Local Air-Gapped Repository
# Created by setup-local-repo.sh on $(date)

[$REPO_NAME]
name=Local Air-Gapped Repository - $REPO_NAME
baseurl=file://$REPO_PATH
enabled=1
EOF
    
    # Add GPG configuration based on key availability
    if [[ -n "$gpg_keys" ]]; then
        cat >> "$repo_file" << EOF
gpgcheck=1
gpgkey=$gpg_keys
priority=1

# Note: If you encounter GPG key errors, you have two options:
# 1. Import the GPG keys:
#    sudo rpm --import $REPO_PATH/gpgkeys/RPM-GPG-KEY-* (if available)
#    sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-* (system keys)
# 2. Disable GPG checking (not recommended): set gpgcheck=0
EOF
        print_msg "$GREEN" "Repository configuration created: $repo_file (with GPG checking)"
    else
        cat >> "$repo_file" << EOF
gpgcheck=0
priority=1

# WARNING: GPG checking is disabled because no keys were found
# To enable GPG checking:
# 1. Obtain the appropriate RPM-GPG-KEY files
# 2. Import them: sudo rpm --import /path/to/RPM-GPG-KEY-*
# 3. Set gpgcheck=1 and add gpgkey=file:///path/to/key
EOF
        print_msg "$YELLOW" "Repository configuration created: $repo_file (GPG checking disabled)"
        print_msg "$YELLOW" "WARNING: GPG checking is disabled. Consider importing GPG keys for security."
    fi
}

# Clean YUM/DNF cache
clean_cache() {
    print_msg "$YELLOW" "Cleaning package manager cache..."
    
    $PKG_MGR clean all &> /dev/null || true
    
    print_msg "$GREEN" "Cache cleaned"
}

# Test repository
test_repository() {
    print_msg "$YELLOW" "Testing repository configuration..."
    
    # List available packages from the new repository
    if $PKG_MGR --disablerepo="*" --enablerepo="$REPO_NAME" list available &> /dev/null; then
        local pkg_count=$($PKG_MGR --disablerepo="*" --enablerepo="$REPO_NAME" list available 2>/dev/null | grep -c "^[a-zA-Z]" || true)
        print_msg "$GREEN" "Repository is working! $pkg_count packages available"
    else
        print_msg "$YELLOW" "WARNING: Could not list packages from repository"
        print_msg "$YELLOW" "This may be normal - try: $PKG_MGR repolist"
    fi
}

# Create usage guide
create_usage_guide() {
    local guide_file="$REPO_PATH/USAGE-GUIDE.txt"
    
    cat > "$guide_file" << EOF
================================================================
Local Air-Gapped Repository - Usage Guide
================================================================

Repository Name: $REPO_NAME
Repository Path: $REPO_PATH
Configuration:   /etc/yum.repos.d/${REPO_NAME}.repo
Setup Date:      $(date)

USING THE REPOSITORY:
---------------------

1. List available packages:
   $PKG_MGR --disablerepo="*" --enablerepo="$REPO_NAME" list available

2. Search for a package:
   $PKG_MGR search <package-name>

3. Install a package:
   sudo $PKG_MGR install <package-name>

4. Get package information:
   $PKG_MGR info <package-name>

5. Update repository cache:
   sudo $PKG_MGR clean all
   sudo $PKG_MGR makecache

TROUBLESHOOTING:
----------------

If packages are not found:
  - Verify repository is enabled: $PKG_MGR repolist
  - Clean cache: sudo $PKG_MGR clean all && sudo $PKG_MGR makecache
  - Check repo file: cat /etc/yum.repos.d/${REPO_NAME}.repo

If you need to update the repository:
  1. Add new RPM files to $REPO_PATH
  2. Run: sudo createrepo --update $REPO_PATH
  3. Run: sudo $PKG_MGR clean all

DISABLING THE REPOSITORY:
-------------------------

Temporarily:
  $PKG_MGR --disablerepo="$REPO_NAME" <command>

Permanently:
  Edit /etc/yum.repos.d/${REPO_NAME}.repo
  Change: enabled=1 to enabled=0

================================================================
For more information, see the project README.md
================================================================
EOF
    
    print_msg "$GREEN" "Usage guide created: $guide_file"
}

# Display completion summary
display_summary() {
    local pkg_count=$(find "$REPO_PATH" -name "*.rpm" 2>/dev/null | wc -l)
    local repo_size=$(du -sh "$REPO_PATH" 2>/dev/null | cut -f1)
    
    echo ""
    print_msg "$GREEN" "================================================================"
    print_msg "$GREEN" "            LOCAL REPOSITORY SETUP COMPLETE"
    print_msg "$GREEN" "================================================================"
    echo ""
    print_msg "$GREEN" "Repository Name:  $REPO_NAME"
    print_msg "$GREEN" "Repository Path:  $REPO_PATH"
    print_msg "$GREEN" "Configuration:    /etc/yum.repos.d/${REPO_NAME}.repo"
    print_msg "$GREEN" "Packages:         $pkg_count"
    print_msg "$GREEN" "Size:             $repo_size"
    echo ""
    print_msg "$YELLOW" "Quick Start:"
    echo "  List packages:     $PKG_MGR list available"
    echo "  Install package:   sudo $PKG_MGR install <package-name>"
    echo "  Search packages:   $PKG_MGR search <keyword>"
    echo ""
    print_msg "$YELLOW" "See $REPO_PATH/USAGE-GUIDE.txt for detailed usage instructions"
    print_msg "$GREEN" "================================================================"
    echo ""
}

# Main execution
main() {
    print_msg "$GREEN" "RHEL Air Gap Local Repository Setup"
    print_msg "$GREEN" "===================================="
    echo ""
    
    parse_args "$@"
    check_root
    check_dependencies
    validate_source
    copy_repository
    verify_packages
    create_metadata
    create_repo_config
    clean_cache
    test_repository
    create_usage_guide
    display_summary
}

# Run main function
main "$@"

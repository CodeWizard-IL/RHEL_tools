#!/usr/bin/env bash

###############################################################################
# Install Java JDK for RHEL
# Supports: RHEL 9.3 x86-64, Ubuntu/Debian, macOS
# Required for: Kafka, and other Java-based tools
###############################################################################

set -euo pipefail

# Load common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/common-lib.sh"

# Check if installation is enabled
if [ "${__INSTALL_JAVA:-1}" != "1" ]; then
    log_info "Java installation is disabled in .env (__INSTALL_JAVA != 1)"
    exit 0
fi

# Check if Java is already installed
if command_exists java; then
    CURRENT_VERSION=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}' || echo "unknown")
    log_info "Java is already installed (version: ${CURRENT_VERSION})"
    exit 0
fi

log_info "Installing Java JDK..."

# Get version from .env or use default
if [ -n "${VERSION_JAVA:-}" ]; then
    JAVA_VERSION="$VERSION_JAVA"
    log_info "Using version from .env: $JAVA_VERSION"
else
    JAVA_VERSION="17"
    log_info "Using default version: $JAVA_VERSION"
fi

# Check for air-gapped environment (forced to true)
AIR_GAPPED=true
if [ "${AIRGAPPED_MODE:-1}" = "1" ]; then
    log_info "Running in AIR-GAPPED mode"
fi

# Detect OS and install accordingly
case $DETECTED_OS in
    linux)
        log_step "Installing OpenJDK $JAVA_VERSION for Linux..."
        
        # Check for local installation files
        INSTALLATION_BASE="${INSTALLATION_FILES_BASE:-/project/Installation_Files}"
        
        log_info "Checking for Java installation files in: $INSTALLATION_BASE/java"
        
        # Check if directory exists
        if [ ! -d "$INSTALLATION_BASE/java" ]; then
            log_warn "Java installation directory does not exist: $INSTALLATION_BASE/java"
            log_info "Creating directory..."
            mkdir -p "$INSTALLATION_BASE/java" 2>/dev/null || true
        fi
        
        
        # Look for any Java tarball in the java directory
        JAVA_TARBALL=$(find "$INSTALLATION_BASE/java" -type f \( -name "*.tar.gz" -o -name "*.tgz" \) 2>/dev/null | head -1)
        
        if [ -n "$JAVA_TARBALL" ] && [ -f "$JAVA_TARBALL" ]; then
            log_info "Using offline installation from: $JAVA_TARBALL"
                    
            log_step "Extracting Java tarball..."
            tar -xzf "$JAVA_TARBALL" -C "$INSTALLATION_BASE/java/"
            
            # Find the extracted JDK directory
            JDK_DIR=$(find "$INSTALLATION_BASE/java" -maxdepth 1 -type d -name "jdk*" -o -name "OpenJDK*" -o -name "java-*" | head -1)
            if [ -z "$JDK_DIR" ]; then
                log_error "No JDK directory found after extraction"
                log_info "Extracted contents:"
                ls -la "$INSTALLATION_BASE/java"
                exit 1
            fi
            
            log_step "Installing Java to /opt/java..."
            mkdir -p /opt/java
            cp -r "$JDK_DIR"/* /opt/java/
            JAVA_HOME="/opt/java"
            log_info "Java installed successfully to: $JAVA_HOME"
        else
            log_warn "Air-gapped mode: Java installation file not found in $INSTALLATION_BASE/java/"
            log_info "Looking for pre-installed Java on system..."
            
            # Check if Java is already available on the system
            if command_exists java; then
                log_info "Java is already available on the system!"
                JAVA_VERSION_INSTALLED=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}' || echo "unknown")
                log_info "Installed version: $JAVA_VERSION_INSTALLED"
                
                # Try to find JAVA_HOME
                if [ -d "/usr/lib/jvm/java" ]; then
                    JAVA_HOME="/usr/lib/jvm/java"
                elif [ -d "/usr/lib/jvm/jre" ]; then
                    JAVA_HOME="/usr/lib/jvm/jre"
                elif [ -d "/opt/java" ]; then
                    JAVA_HOME="/opt/java"
                else
                    # Find any Java installation
                    JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java) 2>/dev/null || which java)))
                fi
                log_info "Using JAVA_HOME: $JAVA_HOME"
            else
                log_error "Java not found on system and no installation tarball available"
                log_info ""
                log_info "To install Java in air-gapped mode:"
                log_info "  1. Place a Java JDK tarball in: $INSTALLATION_BASE/java/"
                log_info "  2. Example filename: OpenJDK17U-jdk_x64_linux_hotspot_17.0.9_9.tar.gz"
                log_info "  3. Or install Java via system package manager before running this script"
                log_info ""
                log_warn "Skipping Java installation"
                exit 0
            fi
        fi
        ;;

    darwin)
        # macOS - check for pre-installed Java in air-gapped mode
        log_info "macOS detected - checking for Java..."
        
        if command_exists java; then
            log_info "Java is already installed"
            CURRENT_VERSION=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}' || echo "unknown")
            log_info "Java version: ${CURRENT_VERSION}"
            
            # Try to find JAVA_HOME
            if [ -x "/usr/libexec/java_home" ]; then
                JAVA_HOME=$(/usr/libexec/java_home 2>/dev/null || echo "/Library/Java/JavaVirtualMachines/jdk-${JAVA_VERSION}.jdk/Contents/Home")
            else
                JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk-${JAVA_VERSION}.jdk/Contents/Home"
            fi
        else
            log_info "Java not found in PATH, checking for local JDK installation..."
            LOCAL_JDK="/Users/dan/Repos/RHEL_tools_automation/Installation_Files/java/jdk-17.0.9+9"
            if [ -d "$LOCAL_JDK" ]; then
                JAVA_HOME="$LOCAL_JDK"
                log_info "Using local JDK: $JAVA_HOME"
            else
                log_error "Java not found in air-gapped macOS environment"
                log_info "Please install Java manually:"
                log_info "  1. Download OpenJDK from https://adoptium.net/"
                log_info "  2. Install the .pkg file"
                log_info "  3. Re-run this script"
                exit 1
            fi
        fi
        ;;

    *)
        log_error "Unsupported OS: $DETECTED_OS"
        log_info "Please install Java manually and set JAVA_HOME environment variable."
        exit 1
        ;;
esac

# Set environment variables if JAVA_HOME is defined
if [ -n "${JAVA_HOME:-}" ]; then
    log_step "Setting Java environment variables..."

    # Add to system-wide profile
    JAVA_ENV_FILE="/etc/profile.d/java.sh"
    tee "$JAVA_ENV_FILE" > /dev/null << EOF
export JAVA_HOME="$JAVA_HOME"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF

    # Also add to current session
    export JAVA_HOME
    export PATH="$JAVA_HOME/bin:$PATH"
    
    log_info "Environment variables set in: $JAVA_ENV_FILE"
else
    log_warn "JAVA_HOME not set, skipping environment variable configuration"
fi

# Verify installation
if command_exists java; then
    INSTALLED_VERSION=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}')
    log_info "✅ Java JDK verified!"
    log_info "Version: $INSTALLED_VERSION"
    log_info "JAVA_HOME: ${JAVA_HOME:-not set}"
    log_info "Location: $(which java)"

    # Test Java
    if java -version &> /dev/null; then
        log_info "✅ Java test successful!"
    else
        log_warn "Java found but test failed"
    fi

    # Show javac if available
    if command_exists javac; then
        JAVAC_VERSION=$(javac -version 2>&1 | head -1)
        log_info "Javac: $JAVAC_VERSION"
    else
        log_info "javac not found (JRE only installation)"
    fi
else
    log_warn "Java not found in PATH after installation"
    log_info "You may need to install Java manually or check your installation files"
fi

log_info ""
log_info "🎉 Java setup complete!"
if [ -n "${JAVA_HOME:-}" ]; then
    log_info ""
    log_info "Setting environment variables for current session:"
    export JAVA_HOME="$JAVA_HOME"
    export PATH="$JAVA_HOME/bin:$PATH"
    log_info "Testing Java installation:"
    java --version
    set +u  # Temporarily allow unset variables
    source ~/.bashrc 2>/dev/null || true
    set -u  # Re-enable unset variable checks
fi
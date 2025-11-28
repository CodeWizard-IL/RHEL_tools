#!/bin/bash

# Color output for better readability
NC='\033[0m' # No Color
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[1;31m'
YELLOW='\033[0;33m'

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log_info() {
     echo -e "${YELLOW}* $*${NC}"
}

log_success() {
  echo -e "${GREEN}* $*${NC}"
}

log_warn() {
  echo -e "${YELLOW}* $*${NC}"
}

log_error() {
  echo -e "${RED}[ERROR]${RED} $*${NC}"
}

log_ident(){
  echo -e "${BLUE}"
  $1 | sed 's/^/  /'
  echo -e "${NC}"
}

# Load .env if exists
if [ -f "../.env" ]; then
  log_info "Loading .env file from parent directory"
  set -a
  source ../.env
  set +a
else
  log_error ".env file not found in parent directory"
fi

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Generic function to check if installation is enabled
check_install_enabled() {
  
  echo -e ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}   Processing $1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo -e ""

  # Local variables
  local tool_name="$1"
  local tool_cmd="$2"
  local var_name="__INSTALL_$(echo "$tool_name" | tr '[:lower:]' '[:upper:]')"
  local value="${!var_name:-1}"

  if [ "$value" != "1" ]; then
    log_info "$tool_name installation is disabled in .env ($var_name != 1)"
    exit 0
  else
    log_info "$tool_name installation is enabled"
    # Check if tool is already installed
    check_tool_installed "$tool_name" "$tool_cmd"
    
  fi
}

# Generic function to check if tool is installed
# Arguments:
#   $1 - tool_name: The human-readable name of the tool (e.g., "kubectl")
#   $2 - tool_cmd: The command to execute to check if the tool is installed
#        The command should return success (exit 0) if the tool is available
# Returns:
#   Exits with 0 if the tool is already installed
#   Returns normally if the tool is not installed (allowing installation to proceed)
check_tool_installed() {
  
  local tool_name="$1"
  local tool_version_cmd="$2"
  
  # Check if tool is installed by running the version command
  if $tool_version_cmd >/dev/null 2>&1; then
    log_info "$tool_name is already installed"

    # Execute the command and print the version
    log_info "Installed version details:"
    log_ident "$tool_version_cmd"
    
    echo -e -n "${GREEN}Do you want to reinstall/upgrade? (Y/N): ${NC}"
    read -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_info "Skipping installation"
      return 0
    fi
    log_info "Proceeding with reinstall/upgrade"
  else
    log_info "$tool_name is not installed, proceeding with installation"
  fi
}

# Install binary function
install_binary() {
  local source="$1"
  local dest="$2"
  log_info "Copying binary from $source to $dest"
  # sudo cp "$source" "$dest"
  # sudo chmod +x "$dest"
}


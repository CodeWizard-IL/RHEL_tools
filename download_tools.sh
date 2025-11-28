#!/bin/bash

# Script to download all tools from .env URLs to Installation Files folder
# Downloads binaries and archives for RedHat/RHEL systems

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# Version variables
VERSION_ARGOCD=v3.2.0
VERSION_CERT_MANAGER=v1.19.1
VERSION_CHARTMUSEUM=0.15.0
VERSION_DOCKER=24.0.7
VERSION_GRAFANA=10.2.2
VERSION_HARBOR=v2.14.1
VERSION_HELM=v3.13.3
VERSION_ISTIO=1.28.0
VERSION_JQ=1.8.1
VERSION_K9S=v0.50.16
VERSION_KAFKA=3.8.0
VERSION_KUBECTL=v1.31.0
VERSION_PROMETHEUS=3.7.3
VERSION_RKE2=v1.34.2+rke2r1
VERSION_YQ=v4.49.2

# Platform variables
PLATFORM_BINARY_PATTERN=linux-amd64
PLATFORM_OS=linux
PLATFORM_ARCH=amd64

# Base URLs
URL_ARGOCD_BASE=https://github.com/argoproj/argo-cd/releases/download
URL_CERT_MANAGER_BASE=https://github.com/cert-manager/cert-manager/releases/download
URL_CHARTMUSEUM_BASE=https://github.com/chartmuseum/chartmuseum/releases/download
URL_DOCKER_BASE=https://download.docker.com/linux/static/stable/x86_64
URL_GRAFANA_BASE=https://dl.grafana.com/oss/release
URL_HARBOR_BASE=https://github.com/goharbor/harbor/releases
URL_HELM_BASE=https://get.helm.sh
URL_ISTIO_BASE=https://github.com/istio/istio/releases/download
URL_K9S_BASE=https://github.com/derailed/k9s/releases/download
URL_KAFKA_BASE=https://downloads.apache.org/kafka
URL_KUBECTL_BASE=https://dl.k8s.io/release
URL_PROMETHEUS_BASE=https://github.com/prometheus/prometheus/releases/download
URL_RKE2_BASE=https://github.com/rancher/rke2/releases/download
URL_YQ_BASE=https://github.com/mikefarah/yq/releases/download
URL_JQ_BASE=https://github.com/jqlang/jq/releases/download


###############################################################################
# Display Install Dialog (whiptail)
###############################################################################
display_install_dialog() {
    local options
    options=$(whiptail \
        --title "Artifacts" \
        --checklist "Select Artifacts to install" 20 78 14 \
        "ArgoCD"      "Install ArgoCD        (Binary)"    OFF \
        "CertManager" "Install Cert-Manager  (Helm)"      OFF \
        "ChartMuseum" "Install ChartMuseum   (Binary)"    OFF \
        "Docker"      "Install Docker        (Binary)"    OFF \
        "Grafana"     "Install Grafana       (Binary)"    OFF \
        "Harbor"      "Install Harbor        (Helm)"      OFF \
        "Helm"        "Install Helm          (Binary)"    OFF \
        "Istio"       "Install Istio         (Binary)"    OFF \
        "K9S"         "Install K9S           (Binary)"    OFF \
        "Kafka"       "Install Kafka         (Binary)"    OFF \
        "kubectl"     "Install kubectl       (Binary)"    OFF \
        "Prometheus"  "Install Prometheus    (Binary)"    OFF \
        "RKE2"        "Install RKE2          (Binary)"    OFF \
        "YQ_JQ"       "Install YQ and JQ     (Binary)"    OFF \
        3>&1 1>&2 2>&3)

    local status=$?

    # User pressed Cancel / ESC
    if [ $status -ne 0 ]; then
        echo "CANCEL"
        return 0
    fi

    # options is like: "Docker" "Helm" → turn into: DOCKER HELM ...
    local out=""
    local arr
    eval "arr=($options)"
    for opt in "${arr[@]}"; do
        out+=$(echo "$opt" | tr '[:lower:]' '[:upper:]')
        out+=" "
    done

    echo "$out"
}

# Array of URLs to download
urls=(
    "${URL_ARGOCD_BASE}/${VERSION_ARGOCD}/argocd-${PLATFORM_BINARY_PATTERN}"
    "${URL_CERT_MANAGER_BASE}/${VERSION_CERT_MANAGER}/cert-manager.yaml"
    "${URL_CHARTMUSEUM_BASE}/${VERSION_CHARTMUSEUM}/chartmuseum-${VERSION_CHARTMUSEUM}-linux-amd64.tar.gz"
    "${URL_GRAFANA_BASE}/grafana-${VERSION_GRAFANA}.${PLATFORM_BINARY_PATTERN}.tar.gz"
    "${URL_HARBOR_BASE}/download/${VERSION_HARBOR}/harbor-offline-installer-${VERSION_HARBOR}.tgz"
    "${URL_HELM_BASE}/helm-${VERSION_HELM}-${PLATFORM_BINARY_PATTERN}.tar.gz"
    "${URL_ISTIO_BASE}/${VERSION_ISTIO}/istio-${VERSION_ISTIO}-${PLATFORM_BINARY_PATTERN}.tar.gz"
    "${URL_K9S_BASE}/${VERSION_K9S}/k9s_Linux_amd64.tar.gz"
    "${URL_KAFKA_BASE}/${VERSION_KAFKA}/kafka_2.13-${VERSION_KAFKA}.tgz"
    "${URL_KUBECTL_BASE}/${VERSION_KUBECTL}/bin/${PLATFORM_OS}/${PLATFORM_ARCH}/kubectl"
    "${URL_PROMETHEUS_BASE}/v${VERSION_PROMETHEUS}/prometheus-${VERSION_PROMETHEUS}.${PLATFORM_BINARY_PATTERN}.tar.gz"
    "${URL_YQ_BASE}/${VERSION_YQ}/yq_${PLATFORM_OS}_${PLATFORM_ARCH}"
    "${URL_JQ_BASE}/jq-${VERSION_JQ}/jq-${PLATFORM_BINARY_PATTERN}"
)
# Create Installation Files directory structure if it doesn't exist
INSTALL_DIR="./Installation_Files"
if [ -d "$INSTALL_DIR" ]; then
    echo "Directory $INSTALL_DIR already exists."
else
    echo "Creating directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

###############################################################################
# Main Function
###############################################################################

# Download function with directory organization
download_to_dir() {
    local url="$1"
    local subdir="$2"
    local filename=$(basename "$url")
    local target_dir="$INSTALL_DIR/$subdir"
    local target_path="$target_dir/$filename"
    
    # Check if file already exists and is not empty
    if [ -f "$target_path" ] && [ $(stat -f%z "$target_path" 2>/dev/null || stat -c%s "$target_path" 2>/dev/null) -gt 1000 ]; then
        echo "⊘ Skipping (already exists): $subdir/$filename"
        echo "---"
        return 0
    fi
    
    echo "Downloading: $filename → $subdir/"
    echo "From: $url"
    cd "$target_dir"
    if curl -L -o "$filename" "$url"; then
        if [ -f "$filename" ] && [ $(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null) -gt 1000 ]; then
            echo "✓ Downloaded successfully: $subdir/$filename"
        else
            echo "✗ Downloaded but file too small or missing: $subdir/$filename"
        fi
    else
        echo "✗ Failed to download: $subdir/$filename"
    fi
    cd - > /dev/null
    echo "---"
}

    echo "---"
}

###############################################################################
# Download Functions for Each Tool
###############################################################################

download_argocd() {
    download_to_dir "${URL_ARGOCD_BASE}/${VERSION_ARGOCD}/argocd-${PLATFORM_BINARY_PATTERN}" "argocd"
}

download_cert_manager() {
    download_to_dir "${URL_CERT_MANAGER_BASE}/${VERSION_CERT_MANAGER}/cert-manager.yaml" "cert-manager"
}

download_chartmuseum() {
    echo "⚠ Skipping ChartMuseum: Pre-built binaries not available for v${VERSION_CHARTMUSEUM}"
    echo "---"
}

download_docker() {
    download_to_dir "${URL_DOCKER_BASE}/docker-${VERSION_DOCKER}.tgz" "docker"
}

download_grafana() {
    download_to_dir "${URL_GRAFANA_BASE}/grafana-${VERSION_GRAFANA}.${PLATFORM_BINARY_PATTERN}.tar.gz" "grafana"
}

download_harbor() {
    download_to_dir "${URL_HARBOR_BASE}/download/${VERSION_HARBOR}/harbor-offline-installer-${VERSION_HARBOR}.tgz" "harbor"
}

download_helm() {
    download_to_dir "${URL_HELM_BASE}/helm-${VERSION_HELM}-${PLATFORM_BINARY_PATTERN}.tar.gz" "helm"
}

download_istio() {
    download_to_dir "${URL_ISTIO_BASE}/${VERSION_ISTIO}/istio-${VERSION_ISTIO}-${PLATFORM_BINARY_PATTERN}.tar.gz" "istio"
}

download_k9s() {
    download_to_dir "${URL_K9S_BASE}/${VERSION_K9S}/k9s_Linux_amd64.tar.gz" "k9s"
}

download_kafka() {
    download_to_dir "${URL_KAFKA_BASE}/${VERSION_KAFKA}/kafka_2.13-${VERSION_KAFKA}.tgz" "kafka"
}

download_kubectl() {
    download_to_dir "${URL_KUBECTL_BASE}/${VERSION_KUBECTL}/bin/${PLATFORM_OS}/${PLATFORM_ARCH}/kubectl" "kubectl"
}

download_prometheus() {
    download_to_dir "${URL_PROMETHEUS_BASE}/v${VERSION_PROMETHEUS}/prometheus-${VERSION_PROMETHEUS}.${PLATFORM_BINARY_PATTERN}.tar.gz" "prometheus"
}

download_rke2() {
    echo "Downloading RKE2 files..."
    RKE2_BASE="${URL_RKE2_BASE}/${VERSION_RKE2}"
    RKE2_FILES=("rke2-images.linux-amd64.tar.gz" "rke2.linux-amd64.tar.gz" "sha256sum-amd64.txt")

    for file in "${RKE2_FILES[@]}"; do
        download_to_dir "${RKE2_BASE}/$file" "rke2"
    done
}

download_yq_jq() {
    download_to_dir "${URL_YQ_BASE}/${VERSION_YQ}/yq_${PLATFORM_OS}_${PLATFORM_ARCH}" "yq-jq"
    download_to_dir "${URL_JQ_BASE}/jq-${VERSION_JQ}/jq-${PLATFORM_BINARY_PATTERN}" "yq-jq"
}

###############################################################################
# Main Function
###############################################################################

main() {
    local selections
    if [ -t 0 ] && command -v whiptail >/dev/null 2>&1; then
        selections=$(display_install_dialog)
    else
        log_info "Non-interactive environment detected. Downloading all tools."
        selections="ARGOCD CERTMANAGER CHARTMUSEUM DOCKER GRAFANA HARBOR HELM ISTIO K9S KAFKA KUBECTL PROMETHEUS RKE2 YQ_JQ"
    fi

    if [[ "$selections" == "CANCEL" ]] || [[ -z "$selections" ]]; then
        echo "You chose to cancel or made no selection."
        exit 0
    fi

    # Create tools_dirs directory structure
    mkdir -p "$INSTALL_DIR"/{argocd,cert-manager,chartmuseum,docker,grafana,harbor,helm,istio,k9s,kafka,kubectl,prometheus,rke2,yq-jq}

    log_info "Tools will be downloaded to: $INSTALL_DIR"
    log_info ""

    log_info "Starting download of selected tools..."
    log_info ""

    # Track success/failure
    local failed_tools=()

    # Download each tool based on selection
    for tool in $selections; do
        case $tool in
            ARGOCD)      download_argocd      || failed_tools+=("argocd") ;;
            CERTMANAGER) download_cert_manager || failed_tools+=("cert-manager") ;;
            CHARTMUSEUM) download_chartmuseum || failed_tools+=("chartmuseum") ;;
            DOCKER)      download_docker      || failed_tools+=("docker") ;;
            GRAFANA)     download_grafana     || failed_tools+=("grafana") ;;
            HARBOR)      download_harbor      || failed_tools+=("harbor") ;;
            HELM)        download_helm        || failed_tools+=("helm") ;;
            ISTIO)       download_istio       || failed_tools+=("istio") ;;
            K9S)         download_k9s         || failed_tools+=("k9s") ;;
            KAFKA)       download_kafka       || failed_tools+=("kafka") ;;
            KUBECTL)     download_kubectl     || failed_tools+=("kubectl") ;;
            PROMETHEUS)  download_prometheus  || failed_tools+=("prometheus") ;;
            RKE2)        download_rke2        || failed_tools+=("rke2") ;;
            YQ_JQ)       download_yq_jq       || failed_tools+=("yq-jq") ;;
        esac
    done

    # Summary
    log_section "Download Summary"

    if [ ${#failed_tools[@]} -eq 0 ]; then
        log_info "✅ All selected tools downloaded successfully!"
    else
        log_warn "⚠️  Some tools failed to download:"
        for tool in "${failed_tools[@]}"; do
            log_error "  - $tool"
        done
    fi

    log_info ""
    log_info "Tools directory: $INSTALL_DIR"
    if [ -d "$INSTALL_DIR" ] && [ "$(ls -A $INSTALL_DIR)" ]; then
      log_info "Total size: $(du -sh "$INSTALL_DIR" | cut -f1)"
    fi
    log_info ""
    log_info "You can now use these tools in air-gapped environments!"

    log_info "Directory structure:"
    for dir in argocd cert-manager chartmuseum docker grafana harbor helm istio k9s kafka kubectl prometheus rke2 yq-jq; do
        if [ -d "$INSTALL_DIR/$dir" ] && [ "$(ls -A "$INSTALL_DIR/$dir" 2>/dev/null)" ]; then
            log_info "  $dir/: $(ls "$INSTALL_DIR/$dir" | wc -l | tr -d ' ') file(s)"
        fi
    done
}
}

# Run main function
main

#!/usr/bin/env bash

###############################################################################
# Download Installation Files for Container/Offline Deployment
# Downloads all tool binaries, installers, and manifests to Installation_Files
# Designed to run in a container or air-gapped environment preparation
###############################################################################

set -euo pipefail

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

###############################################################################
# Configuration: Versions and Platform
###############################################################################

# Platform detection (default to linux-amd64 for containers)
PLATFORM_OS="${PLATFORM_OS:-linux}"
PLATFORM_ARCH="${PLATFORM_ARCH:-amd64}"
PLATFORM_BINARY_PATTERN="${PLATFORM_OS}-${PLATFORM_ARCH}"

# Tool versions
VERSION_ARGOCD="${VERSION_ARGOCD:-v3.2.0}"
VERSION_CERT_MANAGER="${VERSION_CERT_MANAGER:-v1.19.1}"
VERSION_CHARTMUSEUM="${VERSION_CHARTMUSEUM:-v0.15.0}"
VERSION_DOCKER="${VERSION_DOCKER:-24.0.7}"
VERSION_GRAFANA="${VERSION_GRAFANA:-10.2.2}"
VERSION_HARBOR="${VERSION_HARBOR:-v2.14.1}"
VERSION_HELM="${VERSION_HELM:-v3.13.3}"
VERSION_ISTIO="${VERSION_ISTIO:-1.28.0}"
VERSION_JAVA="${VERSION_JAVA:-17}"
VERSION_JQ="${VERSION_JQ:-1.8.1}"
VERSION_K9S="${VERSION_K9S:-v0.50.16}"
VERSION_KAFKA="${VERSION_KAFKA:-3.8.0}"_
VERSION_KUBECTL="${VERSION_KUBECTL:-v1.31.0}"
VERSION_PROMETHEUS="${VERSION_PROMETHEUS:-3.7.3}"
VERSION_RKE2="${VERSION_RKE2:-v1.34.2+rke2r1}"
VERSION_REDIS="${VERSION_REDIS:-7.4.0-v0}"
VERSION_YQ="${VERSION_YQ:-v4.49.2}"

# Base URLs
URL_ARGOCD_BASE="https://github.com/argoproj/argo-cd/releases/download"
URL_CERT_MANAGER_BASE="https://github.com/cert-manager/cert-manager/releases/download"
URL_CHARTMUSEUM_BASE="https://get.helm.sh/chartmuseum"
URL_DOCKER_BASE="https://download.docker.com/linux/static/stable/x86_64"
URL_GRAFANA_BASE="https://dl.grafana.com/oss/release"
URL_HARBOR_BASE="https://github.com/goharbor/harbor/releases"
URL_HELM_BASE="https://get.helm.sh"
URL_ISTIO_BASE="https://github.com/istio/istio/releases/download"
URL_JAVA_BASE="https://github.com/adoptium/temurin17-binaries/releases/download"
URL_K9S_BASE="https://github.com/derailed/k9s/releases/download"
URL_KAFKA_BASE="https://downloads.apache.org/kafka"
URL_KUBECTL_BASE="https://dl.k8s.io/release"
URL_PROMETHEUS_BASE="https://github.com/prometheus/prometheus/releases/download"
URL_RKE2_BASE="https://github.com/rancher/rke2/releases/download"
URL_REDIS_BASE="https://packages.redis.io/redis-stack"
URL_YQ_BASE="https://github.com/mikefarah/yq/releases/download"
URL_JQ_BASE="https://github.com/jqlang/jq/releases/download"

# Installation directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-${SCRIPT_DIR}/Installation_Files}"

# Download configuration
CURL_OPTS="${CURL_OPTS:--L --retry 3 --retry-delay 5 --max-time 300}"
SKIP_EXISTING="${SKIP_EXISTING:-true}"

###############################################################################
# Helper Functions
###############################################################################

# Download file with error handling
download_file() {
    local url="$1"
    local output_path="$2"
    local description="${3:-$(basename "$output_path")}"
    
    # Skip if file exists and SKIP_EXISTING is true
    if [ "$SKIP_EXISTING" = "true" ] && [ -f "$output_path" ] && [ -s "$output_path" ]; then
        log_info "Skipping (exists): $description"
        return 0
    fi
    
    log_info "Downloading: $description"
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$output_path")"
    
    # Download with curl
    if curl $CURL_OPTS -f -o "$output_path" "$url"; then
        # Verify file was downloaded and has content
        if [ -f "$output_path" ] && [ -s "$output_path" ]; then
            local size=$(du -h "$output_path" | cut -f1)
            log_success "Downloaded: $description ($size)"
            return 0
        else
            log_error "Downloaded file is empty: $description"
            rm -f "$output_path"
            return 1
        fi
    else
        log_error "Failed to download: $description"
        rm -f "$output_path"
        return 1
    fi
}

###############################################################################
# Download Functions for Each Tool
###############################################################################

download_argocd() {
    local dir="$INSTALL_DIR/argocd"
    download_file \
        "${URL_ARGOCD_BASE}/${VERSION_ARGOCD}/argocd-${PLATFORM_BINARY_PATTERN}" \
        "$dir/argocd-${PLATFORM_BINARY_PATTERN}" \
        "ArgoCD CLI (${VERSION_ARGOCD})"
}

download_cert_manager() {
    local dir="$INSTALL_DIR/cert-manager"
    
    download_file \
        "${URL_CERT_MANAGER_BASE}/${VERSION_CERT_MANAGER}/cert-manager.yaml" \
        "$dir/cert-manager.yaml" \
        "Cert-Manager Manifests (${VERSION_CERT_MANAGER})"
}

download_chartmuseum() {
    log_warn "ChartMuseum binaries are distributed via Docker images"
    log_info "To use ChartMuseum, pull the Docker image: docker pull ghcr.io/helm/chartmuseum:${VERSION_CHARTMUSEUM}"
}

download_docker() {
    local dir="$INSTALL_DIR/docker"
    
    download_file \
        "${URL_DOCKER_BASE}/docker-${VERSION_DOCKER}.tgz" \
        "$dir/docker-${VERSION_DOCKER}.tgz" \
        "Docker (${VERSION_DOCKER})"
}

download_grafana() {
    local dir="$INSTALL_DIR/grafana"
    
    download_file \
        "${URL_GRAFANA_BASE}/grafana-${VERSION_GRAFANA}.${PLATFORM_BINARY_PATTERN}.tar.gz" \
        "$dir/grafana-${VERSION_GRAFANA}.${PLATFORM_BINARY_PATTERN}.tar.gz" \
        "Grafana (${VERSION_GRAFANA})"
}

download_harbor() {
    local dir="$INSTALL_DIR/harbor"
    
    download_file \
        "${URL_HARBOR_BASE}/download/${VERSION_HARBOR}/harbor-offline-installer-${VERSION_HARBOR}.tgz" \
        "$dir/harbor-offline-installer-${VERSION_HARBOR}.tgz" \
        "Harbor Offline Installer (${VERSION_HARBOR})"
}

download_helm() {
    local dir="$INSTALL_DIR/helm"
    
    download_file \
        "${URL_HELM_BASE}/helm-${VERSION_HELM}-${PLATFORM_BINARY_PATTERN}.tar.gz" \
        "$dir/helm-${VERSION_HELM}-${PLATFORM_BINARY_PATTERN}.tar.gz" \
        "Helm (${VERSION_HELM})"
}

download_istio() {
    local dir="$INSTALL_DIR/istio"
    
    download_file \
        "${URL_ISTIO_BASE}/${VERSION_ISTIO}/istio-${VERSION_ISTIO}-${PLATFORM_BINARY_PATTERN}.tar.gz" \
        "$dir/istio-${VERSION_ISTIO}-${PLATFORM_BINARY_PATTERN}.tar.gz" \
        "Istio (${VERSION_ISTIO})"
}

download_java() {
    local dir="$INSTALL_DIR/java"
    
    download_file \
        "${URL_JAVA_BASE}/jdk-17.0.9+9/OpenJDK17U-jdk_x64_linux_hotspot_17.0.9_9.tar.gz" \
        "$dir/OpenJDK17U-jdk_x64_linux_hotspot_17.0.9_9.tar.gz" \
        "OpenJDK (${VERSION_JAVA})"
}

download_k9s() {
    local dir="$INSTALL_DIR/k9s"
    
    # K9s uses capitalized OS names (Linux, Darwin, Windows)
    local os_caps="$(echo "${PLATFORM_OS}" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')"
    
    download_file \
        "${URL_K9S_BASE}/${VERSION_K9S}/k9s_${os_caps}_${PLATFORM_ARCH}.tar.gz" \
        "$dir/k9s_${os_caps}_${PLATFORM_ARCH}.tar.gz" \
        "K9s (${VERSION_K9S})"
}

download_kafka() {
    local dir="$INSTALL_DIR/kafka"
    
    download_file \
        "${URL_KAFKA_BASE}/${VERSION_KAFKA}/kafka_2.13-${VERSION_KAFKA}.tgz" \
        "$dir/kafka_2.13-${VERSION_KAFKA}.tgz" \
        "Kafka (${VERSION_KAFKA})"
}

download_kubectl() {
    local dir="$INSTALL_DIR/kubectl"
    download_file \
        "${URL_KUBECTL_BASE}/${VERSION_KUBECTL}/bin/${PLATFORM_OS}/${PLATFORM_ARCH}/kubectl" \
        "$dir/kubectl" \
        "Kubectl (${VERSION_KUBECTL})"
}

download_prometheus() {
    local dir="$INSTALL_DIR/prometheus"
    
    download_file \
        "${URL_PROMETHEUS_BASE}/v${VERSION_PROMETHEUS}/prometheus-${VERSION_PROMETHEUS}.${PLATFORM_BINARY_PATTERN}.tar.gz" \
        "$dir/prometheus-${VERSION_PROMETHEUS}.${PLATFORM_BINARY_PATTERN}.tar.gz" \
        "Prometheus (${VERSION_PROMETHEUS})"
}

download_redis() {
    local dir="$INSTALL_DIR/redis"
    
    download_file \
        "${URL_REDIS_BASE}/redis-stack-server-${VERSION_REDIS}.linux-x86_64.tar.gz" \
        "$dir/redis-stack-server-${VERSION_REDIS}.linux-x86_64.tar.gz" \
        "Redis Stack (${VERSION_REDIS})"
}

download_rke2() {
    local dir="$INSTALL_DIR/rke2"
    local version_encoded="${VERSION_RKE2//+/%2B}"  # URL encode the + sign
    local base_url="${URL_RKE2_BASE}/${version_encoded}"
    local success=0
    
    # RKE2 installation files
    local files=(
        "rke2-images.linux-amd64.tar.gz"
        "rke2.linux-amd64.tar.gz"
        "sha256sum-amd64.txt"
    )
    
    for file in "${files[@]}"; do
        if download_file \
            "${base_url}/${file}" \
            "$dir/$file" \
            "RKE2 - $file (${VERSION_RKE2})"; then
            ((success++))
        fi
    done
    
    return $([ $success -gt 0 ] && echo 0 || echo 1)
}

download_yq_jq() {
    local dir="$INSTALL_DIR/yq-jq"
    local success=0
    
    # Download yq
    if download_file \
        "${URL_YQ_BASE}/${VERSION_YQ}/yq_${PLATFORM_OS}_${PLATFORM_ARCH}" \
        "$dir/yq_${PLATFORM_OS}_${PLATFORM_ARCH}" \
        "YQ (${VERSION_YQ})"; then
        ((success++))
    fi
    
    # Download jq
    if download_file \
        "${URL_JQ_BASE}/jq-${VERSION_JQ}/jq-${PLATFORM_BINARY_PATTERN}" \
        "$dir/jq-${PLATFORM_BINARY_PATTERN}" \
        "JQ (${VERSION_JQ})"; then
        ((success++))
    fi
    
    return $([ $success -gt 0 ] && echo 0 || echo 1)
}

download_nfs_tools() {
    local dir="$INSTALL_DIR/nfs-tools"
    local success=0
    
    # NFS tools RPMs and dependencies - with multiple mirror URLs
    # Format: "rpm_name|mirror_urls_separated_by_pipe"
    local rpms=(
        "libbasicobjects-0.1.1-53.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "libcollection-0.7.0-53.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "libpath_utils-0.2.1-53.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "libref_array-0.1.5-53.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "libini_config-1.3.1-53.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "libverto-libevent-0.3.2-3.el9.x86_64.rpm|https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/Packages/libverto-libevent-0.3.2-3.el9.x86_64.rpm"
        "libverto-0.3.2-3.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "gssproxy-0.8.4-6.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "kmod-28-9.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "device-mapper-libs-1.02.195-2.el9.x86_64.rpm|https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/Packages/device-mapper-libs-1.02.195-2.el9.x86_64.rpm"
        "libnfsidmap-1-2.5.4-18.el9.x86_64.rpm|https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/Packages/libnfsidmap-1-2.5.4-18.el9.x86_64.rpm"
        "libtirpc-1.3.3-2.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "python3-pyyaml-5.4.1-6.el9.x86_64.rpm|https://repo.almalinux.org/almalinux/9/AppStream/x86_64/os/Packages/python3-pyyaml-5.4.1-6.el9.x86_64.rpm"
        "e2fsprogs-libs-1.46.5-5.el9.x86_64.rpm|https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/Packages/e2fsprogs-libs-1.46.5-5.el9.x86_64.rpm"
        "quota-nls-4.06-6.el9.noarch.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/|https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/q/"
        "quota-4.06-6.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "diffutils-3.7-12.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/|https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/d/"
        "libselinux-utils-3.6-1.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/|https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/l/"
        "policycoreutils-3.6-2.1.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/|https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/p/"
        "rpcbind-1.2.6-5.el9.x86_64.rpm|https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/Packages/|http://mirror.centos.org/centos/9-stream/BaseOS/x86_64/os/Packages/"
        "nfs-utils-2.5.4-38.el9.x86_64.rpm|https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/Packages/nfs-utils-2.5.4-38.el9.x86_64.rpm"
    )
    
    for entry in "${rpms[@]}"; do
        IFS='|' read -r rpm mirrors <<< "$entry"
        IFS='|' read -ra mirror_array <<< "$mirrors"
        
        local downloaded=false
        for base_url in "${mirror_array[@]}"; do
            if download_file \
                "${base_url}${rpm}" \
                "$dir/${rpm}" \
                "NFS RPM: ${rpm}"; then
                ((success++))
                downloaded=true
                break
            fi
        done
        
        if [ "$downloaded" = false ]; then
            log_warn "Failed to download ${rpm} from all mirrors"
        fi
    done
    
    return $([ $success -gt 0 ] && echo 0 || echo 1)
}

###############################################################################
# Main Execution
###############################################################################

###############################################################################
# Display Install Dialog (whiptail)
###############################################################################
main() {
    log_info "Container Installation Files Downloader"
    log_info "Platform: ${PLATFORM_OS}-${PLATFORM_ARCH}"
    log_info "Target Directory: $INSTALL_DIR"
    log_info "Skip Existing: $SKIP_EXISTING"
    
    local selections="ARGOCD CERTMANAGER CHARTMUSEUM DOCKER GRAFANA HARBOR HELM ISTIO JAVA K9S KAFKA KUBECTL NFS PROMETHEUS REDIS RKE2 YQ_JQ"
    
    log_info "Downloading all tools..."
    
    # Track success/failure
    local failed_tools=()
    
    # Download each tool
    for tool in $selections; do
        case $tool in
            ARGOCD)      download_argocd      || failed_tools+=("argocd") ;;
            CERTMANAGER) download_cert_manager || failed_tools+=("cert-manager") ;;
            CHARTMUSEUM) download_chartmuseum ;;
            DOCKER)      download_docker      || failed_tools+=("docker") ;;
            GRAFANA)     download_grafana     || failed_tools+=("grafana") ;;
            HARBOR)      download_harbor      || failed_tools+=("harbor") ;;
            HELM)        download_helm        || failed_tools+=("helm") ;;
            ISTIO)       download_istio       || failed_tools+=("istio") ;;
            JAVA)        download_java        || failed_tools+=("java") ;;
            K9S)         download_k9s         || failed_tools+=("k9s") ;;
            KAFKA)       download_kafka       || failed_tools+=("kafka") ;;
            KUBECTL)     download_kubectl     || failed_tools+=("kubectl") ;;
            NFS)         download_nfs_tools   || failed_tools+=("nfs-tools") ;;
            PROMETHEUS)  download_prometheus  || failed_tools+=("prometheus") ;;
            REDIS)       download_redis       || failed_tools+=("redis") ;;
            RKE2)        download_rke2        || failed_tools+=("rke2") ;;
            YQ_JQ)       download_yq_jq       || failed_tools+=("yq-jq") ;;
        esac
    done
    
    # Summary
    if [ ${#failed_tools[@]} -eq 0 ]; then
        log_success "All tools downloaded successfully!"
    else
        log_warn "Some tools failed to download:"
        for tool in "${failed_tools[@]}"; do
            log_error "  - $tool"
        done
    fi
    
    log_info "Tools directory: $INSTALL_DIR"
    if [ -d "$INSTALL_DIR" ] && [ "$(ls -A $INSTALL_DIR)" ]; then
        log_info "Total size: $(du -sh "$INSTALL_DIR" | cut -f1)"
    fi
    log_info "Ready for air-gapped environments!"
}

# Script entry point
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi

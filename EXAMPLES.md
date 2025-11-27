# RHEL Air Gap Installation Examples

This document provides practical examples for using the RHEL air gap installation tools in various scenarios.

## Table of Contents

- [Basic Usage](#basic-usage)
- [Advanced Scenarios](#advanced-scenarios)
- [Real-World Examples](#real-world-examples)
- [Troubleshooting Examples](#troubleshooting-examples)

## Basic Usage

### Example 1: Setting Up a Basic Development Environment

**Scenario**: You need to set up a development environment with basic tools on an air-gapped system.

**Step 1**: On the connected system, create a custom package list:

```bash
cat > dev-packages.conf << 'EOF'
# Development essentials
gcc
gcc-c++
make
git
vim
gdb

# Python development
python3
python3-devel
python3-pip

# Version control and utilities
curl
wget
screen
EOF
```

**Step 2**: Download the packages:

```bash
sudo ./download-packages.sh -c dev-packages.conf -o dev-repo-export
```

**Step 3**: Transfer to air-gapped system:

```bash
tar czf dev-repo.tar.gz dev-repo-export/
# Transfer dev-repo.tar.gz via approved media
```

**Step 4**: On the air-gapped system:

```bash
tar xzf dev-repo.tar.gz
sudo ./setup-local-repo.sh -n dev-repo dev-repo-export/
sudo yum install gcc python3 git vim
```

---

### Example 2: Creating a Web Server Repository

**Scenario**: Set up Apache web server with PHP on an air-gapped system.

**Step 1**: Create package list:

```bash
cat > webserver-packages.conf << 'EOF'
httpd
mod_ssl
php
php-mysql
php-cli
php-common
mysql-server
EOF
```

**Step 2**: Download and setup:

```bash
sudo ./download-packages.sh -c webserver-packages.conf -o webserver-repo
# Transfer to air-gapped system
sudo ./setup-local-repo.sh -n webserver webserver-repo/
```

**Step 3**: Install and configure:

```bash
sudo yum install httpd php mysql-server
sudo systemctl enable httpd
sudo systemctl start httpd
```

---

## Advanced Scenarios

### Example 3: Multi-Architecture Support

**Scenario**: You need packages for both x86_64 and aarch64 architectures.

On each architecture's connected system:

```bash
# On x86_64 system
sudo ./download-packages.sh -o repo-export-x64

# On aarch64 system
sudo ./download-packages.sh -o repo-export-arm64
```

Combine repositories:

```bash
mkdir combined-repo
cp repo-export-x64/packages/*.rpm combined-repo/
cp repo-export-arm64/packages/*.rpm combined-repo/
cd combined-repo
createrepo .
```

---

### Example 4: Using Package Groups

**Scenario**: Download entire package groups for comprehensive installations.

```bash
cat > group-packages.conf << 'EOF'
@development-tools
@system-admin-tools
@security-tools
@network-tools

# Additional individual packages
ansible
docker
kubernetes
EOF
```

```bash
sudo ./download-packages.sh -c group-packages.conf -o complete-repo
```

---

### Example 5: Setting Up a Network-Shared Repository

**Scenario**: Share the repository across multiple air-gapped systems on an internal network.

**On the repository server**:

```bash
# Setup the repository
sudo ./setup-local-repo.sh -p /var/www/html/rhel-repo repo-export/

# Install and configure Apache
sudo yum install httpd
sudo systemctl enable httpd
sudo systemctl start httpd

# Allow firewall access
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

**On client systems**:

```bash
# Create repo file pointing to the server
sudo tee /etc/yum.repos.d/network-repo.repo << 'EOF'
[network-airgap-repo]
name=Network Air-Gapped Repository
baseurl=http://192.168.1.100/rhel-repo
enabled=1
gpgcheck=0
EOF

# Use the repository
sudo yum install <package-name>
```

---

## Real-World Examples

### Example 6: Security Hardening Tools

**Scenario**: Install security and compliance tools on an air-gapped security appliance.

```bash
cat > security-packages.conf << 'EOF'
# Security scanning
aide
clamav
clamav-update
rkhunter
lynis

# Firewall and network security
firewalld
iptables
nmap
tcpdump
wireshark

# Authentication and encryption
openssl
openssh-server
openssh-clients
krb5-workstation

# Compliance and auditing
audit
rsyslog
logwatch
EOF
```

---

### Example 7: Database Server Setup

**Scenario**: Deploy PostgreSQL database on an air-gapped production server.

```bash
cat > database-packages.conf << 'EOF'
postgresql-server
postgresql-contrib
postgresql-devel
postgresql-libs
pgadmin4

# Backup tools
barman
pg_repack

# Monitoring
postgresql-monitoring
EOF
```

**Installation and initialization**:

```bash
sudo yum install postgresql-server
sudo postgresql-setup --initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

---

### Example 8: Container Runtime Environment

**Scenario**: Set up container runtime (Podman) on air-gapped system.

```bash
cat > container-packages.conf << 'EOF'
podman
buildah
skopeo
crun
containernetworking-plugins
container-tools

# Additional utilities
podman-docker
slirp4netns
fuse-overlayfs
EOF
```

---

## Troubleshooting Examples

### Example 9: Handling Missing Dependencies

**Problem**: Package installation fails due to missing dependencies.

**Solution**:

```bash
# On connected system, download with all dependencies explicitly
sudo yum install --downloadonly --downloaddir=./extra-deps <package-name>

# Verify all dependencies
rpm -qpR /path/to/package.rpm

# Add missing packages to packages.conf and re-run download script
```

---

### Example 10: Updating an Existing Repository

**Scenario**: Need to add new packages to an existing air-gapped repository.

```bash
# On connected system, download only new packages
sudo ./download-packages.sh -c new-packages.conf -o updates-repo

# Transfer to air-gapped system
# Add to existing repository
sudo cp updates-repo/packages/*.rpm /var/local-repo/

# Update repository metadata
sudo createrepo --update /var/local-repo

# Clean cache and update
sudo yum clean all
sudo yum makecache
```

---

### Example 11: Handling GPG Key Issues

**Problem**: GPG verification fails for packages.

**Solution**:

```bash
# Export GPG keys on connected system
sudo rpm -q gpg-pubkey --qf '%{name}-%{version}-%{release} --> %{summary}\n'
sudo cp /etc/pki/rpm-gpg/RPM-GPG-KEY-* ./repo-export/

# On air-gapped system, import keys
sudo rpm --import /path/to/RPM-GPG-KEY-*

# Or disable gpgcheck in repo file (not recommended for production)
gpgcheck=0
```

---

### Example 12: Creating Incremental Updates

**Scenario**: Regular monthly updates for air-gapped systems.

**Monthly process**:

```bash
# Month 1: Full repository
sudo ./download-packages.sh -o repo-2024-01

# Month 2: Only download updates
sudo yum check-update | awk '{print $1}' > update-packages.txt
sudo ./download-packages.sh -c update-packages.txt -o repo-2024-02

# Transfer and merge repositories
sudo cp repo-2024-02/packages/*.rpm /var/local-repo/
sudo createrepo --update /var/local-repo
```

---

## Best Practices

### Example 13: Version Pinning

**Scenario**: Ensure consistent versions across multiple systems.

```bash
# On connected system, list exact versions
yum list available > available-packages.txt

# Create specific version list
cat > versioned-packages.conf << 'EOF'
vim-8.0.1763-15.el8
gcc-8.5.0-10.el8
python3-3.6.8-44.el8
EOF

# Download specific versions
sudo yumdownloader vim-8.0.1763-15.el8 gcc-8.5.0-10.el8 python3-3.6.8-44.el8
```

---

### Example 14: Creating Minimal Repositories

**Scenario**: Minimize transfer size for bandwidth-limited environments.

```bash
# Download only essential packages without docs
cat > minimal-packages.conf << 'EOF'
bash
coreutils
systemd
openssh-server
EOF

# Use --nodocs flag during installation
sudo yum install --setopt=tsflags=nodocs <package-name>
```

---

## Automation Examples

### Example 15: Automated Monthly Repository Updates

```bash
#!/bin/bash
# monthly-update.sh

DATE=$(date +%Y-%m)
REPO_DIR="repo-${DATE}"

# Download latest packages
sudo ./download-packages.sh -o "$REPO_DIR"

# Create archive
tar czf "${REPO_DIR}.tar.gz" "$REPO_DIR"

# Calculate checksum
sha256sum "${REPO_DIR}.tar.gz" > "${REPO_DIR}.tar.gz.sha256"

echo "Repository update complete: ${REPO_DIR}.tar.gz"
echo "Transfer this file to air-gapped systems"
```

---

## Summary

These examples cover common scenarios for air-gapped RHEL installations. Adapt them to your specific requirements and security policies.

For more information, see the main [README.md](README.md) file.

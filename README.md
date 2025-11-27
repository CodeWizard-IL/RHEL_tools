# RHEL_tools

Tools for managing Red Hat Enterprise Linux (RHEL) installations in air-gapped environments.

## Overview

This repository provides utilities for installing and managing RHEL packages on systems without internet access (air-gapped environments). The tools help you download packages on an internet-connected system and deploy them on isolated systems.

## Documentation

- **[README.md](README.md)** - This file, provides overview and quick start guide
- **[EXAMPLES.md](EXAMPLES.md)** - Detailed examples and real-world scenarios
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Guidelines for contributing to this project
- **[LICENSE](LICENSE)** - MIT License

## Features

- **Package Download Tool**: Download RHEL packages and their dependencies on a connected system
- **Local Repository Setup**: Create and configure local YUM/DNF repositories on air-gapped systems
- **Dependency Resolution**: Automatically resolve and download all package dependencies
- **Configuration Management**: Easy-to-use configuration files for specifying packages

## Prerequisites

### On the Internet-Connected System:
- RHEL 7, 8, or 9 (or compatible distribution)
- Active RHEL subscription or access to RHEL repositories
- `yum` or `dnf` package manager
- `createrepo` or `createrepo_c` package installed
- Sufficient disk space for downloaded packages

### On the Air-Gapped System:
- RHEL 7, 8, or 9 (or compatible distribution)
- `createrepo` or `createrepo_c` package installed
- Web server (optional, for network-based repository)

## Quick Start

### 1. Download Packages (On Connected System)

```bash
# Edit packages.conf to list your required packages
vim packages.conf

# Run the download script
sudo ./download-packages.sh

# This creates a 'repo-export' directory with all packages
```

### 2. Transfer to Air-Gapped System

Transfer the `repo-export` directory to your air-gapped system using approved media (USB drive, DVD, etc.).

```bash
# Example using rsync or scp before disconnecting
rsync -av repo-export/ airgapped-system:/path/to/repo-export/
```

### 3. Set Up Local Repository (On Air-Gapped System)

```bash
# Run the setup script
sudo ./setup-local-repo.sh /path/to/repo-export

# Install packages using the local repository
sudo yum install <package-name>
# or
sudo dnf install <package-name>
```

## Usage

### Configuration File (packages.conf)

Edit `packages.conf` to specify which packages to download:

```
# Core packages
vim
git
wget
curl

# Development tools
gcc
make
python3
```

### Download Script Options

```bash
./download-packages.sh [OPTIONS]

Options:
  -c, --config FILE     Configuration file (default: packages.conf)
  -o, --output DIR      Output directory (default: repo-export)
  -h, --help           Show help message
```

### Repository Setup Options

```bash
./setup-local-repo.sh [OPTIONS] REPO_DIR

Options:
  -n, --name NAME      Repository name (default: local-airgap-repo)
  -p, --path PATH      Repository mount point (default: /var/local-repo)
  -h, --help          Show help message
```

## Directory Structure

```
RHEL_tools/
├── README.md                    # This file
├── packages.conf               # Package list configuration
├── download-packages.sh        # Script to download packages
├── setup-local-repo.sh         # Script to setup local repository
└── repo-export/                # Created by download script (not in git)
    └── packages/               # Downloaded RPM packages
```

## Advanced Usage

### Downloading Specific Package Groups

You can also download entire package groups:

```bash
# Add to packages.conf:
@development-tools
@system-tools
```

### Creating a Network-Accessible Repository

On the air-gapped system, you can set up an HTTP server to share the repository across multiple systems:

```bash
# Install httpd if not already available
sudo yum install httpd

# Copy repository to web root
sudo cp -r /path/to/repo-export /var/www/html/local-repo

# Start httpd
sudo systemctl start httpd
sudo systemctl enable httpd
```

Then configure client systems to use `http://<server-ip>/local-repo` as their repository URL.

## Troubleshooting

### Issue: GPG Key Errors

If you encounter GPG key verification errors:
```bash
# Import the RHEL GPG key
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
```

### Issue: Dependency Resolution Failures

If dependencies cannot be resolved:
```bash
# Ensure all required repositories are enabled on the download system
sudo subscription-manager repos --enable=<repo-name>
```

### Issue: Repository Metadata Corruption

If repository metadata appears corrupted:
```bash
# Recreate repository metadata
cd /path/to/repo-export
sudo createrepo --update .
```

## Security Considerations

- Always verify package signatures before installation
- Use checksums to verify file integrity after transfer
- Keep your RHEL subscription credentials secure
- Regularly update your air-gapped packages by repeating the download process

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on:

- Reporting bugs
- Suggesting enhancements
- Submitting pull requests
- Code style guidelines

## More Examples

For detailed examples and real-world scenarios, see [EXAMPLES.md](EXAMPLES.md) which includes:

- Basic usage scenarios
- Advanced configurations
- Multi-architecture support
- Network-shared repositories
- Security hardening
- Database and web server setups
- Container runtime environments
- Troubleshooting guides

## Support

For issues specific to these tools, please open a GitHub issue.
For RHEL-specific support, contact Red Hat support.
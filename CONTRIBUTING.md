# Contributing to RHEL_tools

Thank you for considering contributing to RHEL_tools! This document provides guidelines for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When creating a bug report, include:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples**
- **Describe the behavior you observed and what you expected**
- **Include relevant logs and screenshots**
- **Specify your RHEL version and environment details**

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:

- **Use a clear and descriptive title**
- **Provide a detailed description of the suggested enhancement**
- **Explain why this enhancement would be useful**
- **List any alternative solutions you've considered**

### Pull Requests

1. Fork the repository and create your branch from `main`
2. Make your changes following the style guidelines
3. Test your changes thoroughly
4. Update documentation as needed
5. Write clear, descriptive commit messages
6. Submit a pull request

## Development Setup

### Prerequisites

- RHEL 7, 8, or 9 (or compatible distribution)
- Bash 4.0 or higher
- Basic understanding of YUM/DNF package management

### Testing Your Changes

Before submitting changes, test your modifications:

```bash
# Syntax check for shell scripts
bash -n download-packages.sh
bash -n setup-local-repo.sh

# Test help messages
./download-packages.sh --help
./setup-local-repo.sh --help

# If possible, test actual functionality
sudo ./download-packages.sh -c test-packages.conf -o /tmp/test-repo
```

## Submitting Changes

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters or less
- Reference issues and pull requests after the first line

Example:
```
Add support for DNF package groups

- Implement package group detection
- Add documentation for group syntax
- Update examples with group usage

Fixes #123
```

### Pull Request Process

1. **Update the README.md** with details of changes if applicable
2. **Update EXAMPLES.md** if you add new features
3. **Add tests** if you're adding functionality
4. **Ensure scripts remain POSIX-compliant** where possible
5. **Get review approval** from maintainers

## Style Guidelines

### Shell Script Style

Follow these guidelines for shell scripts:

#### General

- Use `#!/bin/bash` shebang
- Use `set -e` for error handling
- Use functions to organize code
- Add comments for complex logic
- Use meaningful variable names

#### Variables

```bash
# Use uppercase for constants
readonly CONFIG_FILE="packages.conf"
readonly OUTPUT_DIR="repo-export"

# Use lowercase for local variables
local package_count=0
local repo_size=""
```

#### Functions

```bash
# Function names should be descriptive and use underscores
check_dependencies() {
    local missing_deps=()
    # Function body
}

# Always validate input
validate_input() {
    if [[ -z "$1" ]]; then
        print_msg "$RED" "ERROR: Missing required argument"
        return 1
    fi
}
```

#### Error Handling

```bash
# Check command success
if ! command -v dnf &> /dev/null; then
    print_msg "$RED" "ERROR: dnf not found"
    exit 1
fi

# Use || for simple error handling
mkdir -p "$OUTPUT_DIR" || {
    print_msg "$RED" "ERROR: Failed to create directory"
    exit 1
}
```

#### Output Messages

```bash
# Use consistent messaging
print_msg "$GREEN" "SUCCESS: Operation completed"
print_msg "$YELLOW" "WARNING: Potential issue detected"
print_msg "$RED" "ERROR: Operation failed"
```

### Documentation Style

- Use clear, concise language
- Include practical examples
- Keep line length under 100 characters
- Use markdown formatting consistently
- Update table of contents when adding sections

### Code Comments

```bash
# Good: Explains why, not what
# Download packages with dependencies to handle version conflicts
dnf download --resolve --alldeps "${PACKAGES[@]}"

# Avoid: States the obvious
# Download packages
dnf download "${PACKAGES[@]}"
```

## Areas for Contribution

We welcome contributions in these areas:

### Features

- Support for additional RHEL versions
- Integration with other package managers
- Automated repository synchronization
- Web-based management interface
- Repository mirroring capabilities

### Documentation

- Additional examples and use cases
- Troubleshooting guides
- Video tutorials
- Translation to other languages

### Testing

- Automated test scripts
- Integration tests
- Compatibility testing across RHEL versions
- Performance benchmarks

### Bug Fixes

- Fix reported issues
- Improve error handling
- Enhance validation logic

## Questions?

If you have questions about contributing, please:

1. Check existing documentation
2. Search closed issues for similar questions
3. Open a new issue with the "question" label

## Recognition

Contributors will be recognized in:

- The project README
- Release notes
- Git commit history

Thank you for contributing to RHEL_tools!

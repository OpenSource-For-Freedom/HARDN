# HARDN-XDR Build Process Documentation

## Answer to: "Do we need the docker files to help the dpkg build?"

**Short Answer: NO** - Docker files are not needed for the dpkg build process.

## Build Process Overview

### Native Dpkg Build (Recommended)

The HARDN-XDR package builds perfectly using standard Debian build tools without any Docker involvement:

```bash
# Install build dependencies
sudo apt install -y debhelper-compat devscripts build-essential

# Build the package
dpkg-buildpackage -us -uc -b
```

**Requirements:**
- debhelper-compat (or debhelper)
- devscripts
- build-essential
- Standard Debian/Ubuntu system

**Output:** `hardn-xdr_2.0.0-1_all.deb` package file

### Docker Files Purpose

The Docker files in this repository serve **testing purposes only**, not building:

#### 1. Dockerfile
- Creates isolated testing environments
- Pre-installs Lynis and security tools
- Used for compliance testing
- Provides clean Debian 12 environment

#### 2. docker-compose.yml
- Facilitates development and testing
- Provides two services:
  - `hardn-test`: Automated compliance testing
  - `hardn-dev`: Development environment
- Enables easy local testing

## CI/CD Pipeline Breakdown

### Build Stage (No Docker)
```yaml
# .github/workflows/build-and-test.yml
runs-on: ubuntu-latest  # Direct Ubuntu runner
steps:
  - name: Install build dependencies
    run: sudo apt-get install -y debhelper-compat devscripts build-essential
  - name: Build package
    run: dpkg-buildpackage -us -uc -b
```

### Test Stage (Uses Docker)
```yaml
strategy:
  matrix:
    debian-version: ['debian:12', 'ubuntu:24.04']
steps:
  - name: Test in container
    run: docker run --rm -v "$PWD":/workspace ${{ matrix.debian-version }} bash -c "..."
```

## Installation Methods

### 1. Pre-built Package (Recommended)
```bash
wget https://github.com/OpenSource-For-Freedom/HARDN/releases/latest/download/hardn-xdr.deb
sudo dpkg -i hardn-xdr.deb
```

### 2. Build from Source (No Docker)
```bash
git clone https://github.com/OpenSource-For-Freedom/HARDN.git
cd HARDN
sudo apt install -y debhelper-compat devscripts build-essential
dpkg-buildpackage -us -uc -b
sudo dpkg -i ../hardn-xdr_*.deb
```

### 3. Using install.sh (Automated)
```bash
curl -sSL https://raw.githubusercontent.com/OpenSource-For-Freedom/HARDN/main/install.sh | sudo bash
```

The install.sh script automatically:
1. Tries to download pre-built package
2. Falls back to building from source using dpkg-buildpackage
3. **Never uses Docker**

## Testing with Docker (Optional)

### Local Development Testing
```bash
# Run compliance test
docker-compose up hardn-test

# Development environment
docker-compose up -d hardn-dev
docker-compose exec hardn-dev bash
```

### Manual Testing
```bash
# Build test image
docker build -t hardn-test .

# Run compliance test
docker run --privileged hardn-test /hardn/test-lynis-compliance.sh
```

## Summary

| Component | Purpose | Docker Required |
|-----------|---------|----------------|
| dpkg build | Create .deb package | ❌ No |
| CI/CD build | Automated package creation | ❌ No |
| install.sh | User installation | ❌ No |
| Compliance testing | Lynis security testing | ✅ Yes (for isolation) |
| Multi-distro testing | Test on different systems | ✅ Yes (for isolation) |
| Development | Local development environment | ⚠️ Optional |

## Conclusion

**Docker files are completely optional for building HARDN-XDR packages.** They provide valuable testing capabilities but are not part of the build process. The dpkg build system works perfectly with standard Debian build tools on any Debian/Ubuntu system.

Keep the Docker files for their testing benefits, but understand they are not build dependencies.
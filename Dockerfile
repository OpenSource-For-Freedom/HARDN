FROM debian:12

# Set environment variables to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV APT_LISTBUGS_FRONTEND=none

# Update system and install basic dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        curl \
        wget \
        git \
        sudo \
        apt-utils \
        ca-certificates \
        gnupg \
        lsb-release \
        procps \
        whiptail && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Lynis security auditing tool and jq for JSON processing
RUN apt-get update && \
    apt-get install -y lynis jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a working directory
WORKDIR /hardn

# Copy HARDN files
COPY . /hardn/

# Make scripts executable
RUN chmod +x /hardn/install.sh && \
    chmod +x /hardn/src/setup/hardn-main.sh && \
    chmod +x /hardn/src/setup/generate-remediation-report.sh && \
    chmod +x /hardn/src/setup/hardn-uninstall.sh && \
    chmod +x /hardn/test-hardn-installation.sh && \
    chmod +x /hardn/test-comprehensive-compliance.sh && \
    chmod +x /hardn/test-lynis-compliance.sh

# Set default command
CMD ["/bin/bash"]
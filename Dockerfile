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
    chmod +x /hardn/test-hardn-installation.sh && \
    chmod +x /hardn/test-comprehensive-compliance.sh

# Create a script to run Lynis and check compliance
RUN echo '#!/bin/bash\n\
echo "Running Lynis security audit..."\n\
lynis audit system --quiet --no-colors --log-file /tmp/lynis.log --report-file /tmp/lynis-report.dat\n\
echo "\n=== LYNIS AUDIT COMPLETE ==="\n\
echo "Checking compliance score..."\n\
if [ -f /tmp/lynis-report.dat ]; then\n\
    HARDENING_INDEX=$(grep "hardening_index" /tmp/lynis-report.dat | cut -d"=" -f2 | tr -d " ")\n\
    echo "Hardening Index: $HARDENING_INDEX%"\n\
    if [ "$HARDENING_INDEX" -ge 90 ]; then\n\
        echo "✅ PASS: Lynis compliance score is $HARDENING_INDEX% (>= 90%)"\n\
        exit 0\n\
    else\n\
        echo "❌ FAIL: Lynis compliance score is $HARDENING_INDEX% (< 90%)"\n\
        exit 1\n\
    fi\n\
else\n\
    echo "❌ ERROR: Lynis report file not found"\n\
    exit 1\n\
fi' > /hardn/test-lynis-compliance.sh && \
    chmod +x /hardn/test-lynis-compliance.sh

# Set default command
CMD ["/bin/bash"]
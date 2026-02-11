FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install core dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    nodejs \
    npm \
    curl \
    git \
    wget \
    unzip \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install TruffleHog
RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin

# Install Semgrep
RUN python3 -m pip install semgrep

# Install Snyk
RUN npm install -g snyk

# Install Checkov
RUN python3 -m pip install checkov jinja2

# Install Trivy
RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Install Cosign
RUN curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign

# Copy scripts
COPY scripts/run-all.sh /usr/local/bin/fortressci-scan
COPY scripts/summarize.py /usr/local/bin/summarize.py
COPY scripts/generate-report.py /usr/local/bin/generate-report.py
COPY templates/ /templates/

# Set permissions
RUN chmod +x /usr/local/bin/fortressci-scan

# Create results directory
RUN mkdir -p /results

ENTRYPOINT ["fortressci-scan"]

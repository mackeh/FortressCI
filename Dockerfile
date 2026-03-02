FROM ubuntu:24.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

ARG SNYK_VERSION=1.1303.0
ARG TRIVY_VERSION=v0.69.2
ARG SYFT_VERSION=v1.42.1
ARG COSIGN_VERSION=v3.0.5

# Install core dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    ca-certificates \
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

# Install Security Tools
RUN curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh -o /tmp/install-trufflehog.sh && \
    sh /tmp/install-trufflehog.sh -b /usr/local/bin && \
    python3 -m pip install --no-cache-dir --break-system-packages semgrep checkov jinja2 && \
    npm install -g "snyk@${SNYK_VERSION}" && npm cache clean --force && \
    curl -sSfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh -o /tmp/install-trivy.sh && \
    sh /tmp/install-trivy.sh -b /usr/local/bin "${TRIVY_VERSION}" && \
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh -o /tmp/install-syft.sh && \
    sh /tmp/install-syft.sh -b /usr/local/bin "${SYFT_VERSION}" && \
    curl -sSfL "https://github.com/sigstore/cosign/releases/download/${COSIGN_VERSION}/cosign-linux-amd64" -o /usr/local/bin/cosign && \
    chmod +x /usr/local/bin/cosign && \
    rm -f /tmp/install-trufflehog.sh /tmp/install-trivy.sh /tmp/install-syft.sh

# Copy scripts
COPY scripts/run-all.sh /usr/local/bin/fortressci-scan
COPY scripts/summarize.py /usr/local/bin/summarize.py
COPY scripts/generate-report.py /usr/local/bin/generate-report.py
COPY scripts/check-thresholds.sh /usr/local/bin/check-thresholds.sh
COPY scripts/fortressci-waiver.sh /usr/local/bin/fortressci-waiver
COPY scripts/generate-sbom.sh /usr/local/bin/generate-sbom
COPY scripts/fortressci-policy-check.sh /usr/local/bin/fortressci-policy-check
COPY scripts/generate-compliance-report.py /usr/local/bin/generate-compliance-report
COPY scripts/ai-triage.py /usr/local/bin/ai-triage
COPY scripts/generate-badge.py /usr/local/bin/generate-badge
COPY scripts/auto-fix.sh /usr/local/bin/auto-fix
COPY scripts/build-attack-graph.py /usr/local/bin/build-attack-graph
COPY scripts/cross-repo-analyzer.py /usr/local/bin/cross-repo-analyzer
COPY scripts/fortressci-doctor.sh /usr/local/bin/fortressci-doctor
COPY scripts/generate-adoption-roadmap.py /usr/local/bin/generate-adoption-roadmap
COPY templates/ /templates/

# Set permissions
RUN chmod +x /usr/local/bin/fortressci-scan /usr/local/bin/check-thresholds.sh /usr/local/bin/fortressci-waiver /usr/local/bin/generate-sbom /usr/local/bin/fortressci-policy-check /usr/local/bin/generate-compliance-report /usr/local/bin/ai-triage /usr/local/bin/generate-badge /usr/local/bin/auto-fix /usr/local/bin/build-attack-graph /usr/local/bin/cross-repo-analyzer /usr/local/bin/fortressci-doctor /usr/local/bin/generate-adoption-roadmap

# Create results directory
RUN mkdir -p /results

ENTRYPOINT ["fortressci-scan"]

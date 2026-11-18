FROM ubuntu:24.10@sha256:cdf755952ed117f6126ff4e65810bf93767d4c38f5c7185b50ec1f1078b464cc

ARG TARGETARCH
ARG AGENT_VERSION=5.282.0
# Checksums from the release notes of github.com/microsoft/azure-pipelines-agent.
ARG AGENT_SHA256_AMD64=0c122d51aecdc248ca1f8e68711948adcad67d5a421d310a97a1d3e7aed8641c
ARG AGENT_SHA256_ARM64=64a9d28fadf46e22cb3f143caca54511cc838e33c4802798c80a8efec44d4d55

LABEL org.opencontainers.image.title="azure-pipelines-agent" \
      org.opencontainers.image.description="Self-hosted Azure Pipelines agent for Kubernetes, with the agent built in" \
      org.opencontainers.image.vendor="Think-Cube" \
      org.opencontainers.image.authors="contact@thinkcube.dev" \
      org.opencontainers.image.licenses="MIT"

ENV LANG=C.UTF-8 \
    AGENT_VERSION=${AGENT_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The upgrade is what lets the weekly rebuild pick up security patches
# while the base image stays pinned by digest. zip and unzip are needed by the archive tasks.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        unzip \
        zip && \
    rm -rf /var/lib/apt/lists/*

# The package without the end-of-life Node 6, 10 and 16 task runners.
RUN case "${TARGETARCH}" in \
        amd64) arch=x64; sha256="${AGENT_SHA256_AMD64}" ;; \
        arm64) arch=arm64; sha256="${AGENT_SHA256_ARM64}" ;; \
        *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac && \
    curl -fsSL -o /tmp/agent.tar.gz \
        "https://download.agent.dev.azure.com/agent/${AGENT_VERSION}/pipelines-agent-linux-${arch}-${AGENT_VERSION}.tar.gz" && \
    echo "${sha256}  /tmp/agent.tar.gz" | sha256sum --check --strict - && \
    mkdir -p /azp && \
    tar -xzf /tmp/agent.tar.gz -C /azp && \
    rm /tmp/agent.tar.gz && \
    DEBIAN_FRONTEND=noninteractive /azp/bin/installdependencies.sh && \
    rm -rf /var/lib/apt/lists/*

COPY start.sh /azp/start.sh

RUN groupadd --gid 10001 agent && \
    useradd --uid 10001 --gid 10001 --create-home --home-dir /home/agent --shell /bin/bash agent && \
    chmod 755 /azp/start.sh && \
    chown -R agent:agent /azp

WORKDIR /azp

USER 10001:10001

ENTRYPOINT ["/azp/start.sh"]

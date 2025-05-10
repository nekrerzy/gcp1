# Stage 1: Builder stage with all tools
FROM debian:bullseye-slim AS builder

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    ca-certificates \
    wget \
    unzip \
    git \
    sudo \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Install Google Cloud SDK
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | \
    tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && apt-get install -y google-cloud-sdk && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Install yq and jq
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod a+x /usr/local/bin/yq && \
    apt-get update && apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

# Stage 2: Final lightweight image
FROM debian:bullseye-slim

# Copy tools from builder stage
COPY --from=builder /usr/bin/gcloud /usr/bin/gcloud
COPY --from=builder /usr/lib/google-cloud-sdk /usr/lib/google-cloud-sdk
COPY --from=builder /usr/bin/git /usr/bin/git
COPY --from=builder /usr/bin/gh /usr/bin/gh
COPY --from=builder /usr/local/bin/yq /usr/local/bin/yq
COPY --from=builder /usr/bin/jq /usr/bin/jq
COPY --from=builder /usr/lib/google-cloud-sdk/lib /usr/lib/google-cloud-sdk/lib
COPY --from=builder /usr/lib/google-cloud-sdk/platform /usr/lib/google-cloud-sdk/platform
COPY --from=builder /usr/lib/google-cloud-sdk/data /usr/lib/google-cloud-sdk/data

# Set up environment
ENV PATH="/usr/lib/google-cloud-sdk/bin:${PATH}"
ENV CLOUDSDK_PYTHON="/usr/bin/python3"
# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    bash \
    curl \
    gosu \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Create original entrypoint script (for backward compatibility)
RUN echo '#!/bin/bash\n\
    \n\
    # If HOST_USER_ID and HOST_GROUP_ID are provided, run as that user\n\
    if [ -n "$HOST_USER_ID" ] && [ -n "$HOST_GROUP_ID" ]; then\n\
    # Create user and group with host IDs\n\
    groupadd -g $HOST_GROUP_ID hostuser 2>/dev/null || groupadd -g $HOST_GROUP_ID hostuser-$HOST_GROUP_ID\n\
    useradd -u $HOST_USER_ID -g $HOST_GROUP_ID -m hostuser 2>/dev/null || useradd -u $HOST_USER_ID -g $HOST_GROUP_ID -m hostuser-$HOST_USER_ID\n\
    \n\
    # Make sure the user has access to the necessary directories\n\
    chown -R $HOST_USER_ID:$HOST_GROUP_ID /root/.config/gcloud 2>/dev/null || true\n\
    chown -R $HOST_USER_ID:$HOST_GROUP_ID /root/.config/gh 2>/dev/null || true\n\
    \n\
    # Run the command as the host user\n\
    exec gosu $HOST_USER_ID:$HOST_GROUP_ID /repo/scripts/takeoff.sh "$@"\n\
    else\n\
    # Run as root if no host IDs provided\n\
    exec /repo/scripts/takeoff.sh "$@"\n\
    fi\n\
    ' > /usr/bin/entrypoint.sh

# Create Docker Compose aware entrypoint
RUN echo '#!/bin/bash\n\
    \n\
    # Initialize or migrate config if needed\n\
    SCRIPT_PATH="/repo/scripts/takeoff.sh"\n\
    CONFIG_PATH="/config/takeoff_config.yaml"\n\
    \n\
    # Create necessary directories\n\
    mkdir -p /config\n\
    \n\
    # Copy script to writable location\n\
    cp -f "$SCRIPT_PATH" /config/takeoff.sh\n\
    chmod +x /config/takeoff.sh\n\
    \n\
    # Override config path in the environment\n\
    export CONFIG_YAML="$CONFIG_PATH"\n\
    \n\
    # Run the script\n\
    cd /repo && /config/takeoff.sh "$@"\n\
    ' > /usr/bin/entrypoint-compose.sh

# Make sure entrypoint scripts are executable
RUN chmod +x /usr/bin/entrypoint.sh /usr/bin/entrypoint-compose.sh

# Set working directory
WORKDIR /repo

# Set default entrypoint (will be overridden in compose)
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
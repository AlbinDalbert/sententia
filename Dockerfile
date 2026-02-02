FROM ghcr.io/openclaw/openclaw:latest

USER root

ARG SIGNAL_CLI_VERSION=0.13.23

# Adoptium Temurin repo for JRE 21 (signal-cli 0.13.x needs Java 21+,
# Bookworm only ships Java 17 via default-jre)
RUN apt-get update && apt-get install -y --no-install-recommends wget apt-transport-https gnupg && \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /etc/apt/keyrings/adoptium.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb bookworm main" > /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    temurin-21-jre \
    ffmpeg \
    dumb-init \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install signal-cli
RUN curl -fsSL \
        "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}.tar.gz" \
    | tar xz -C /opt \
    && ln -sf "/opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli" /usr/local/bin/signal-cli

# signal-cli bundles libsignal_jni.so for x86_64 only.
# On aarch64 (Raspberry Pi) we swap it with a community ARM64 build.
# https://github.com/exquo/signal-libs-build
# /usr/java/packages/lib is on the default java.library.path and takes
# precedence over the x86_64 .so bundled inside the jar.
RUN ARCH="$(uname -m)" && \
    if [ "$ARCH" = "aarch64" ]; then \
        LIBSIGNAL_VER="$(basename /opt/signal-cli-${SIGNAL_CLI_VERSION}/lib/libsignal-client-*.jar .jar | sed 's/libsignal-client-//')" && \
        curl -fsSL \
            "https://github.com/exquo/signal-libs-build/releases/download/libsignal_v${LIBSIGNAL_VER}/libsignal_jni.so-v${LIBSIGNAL_VER}-aarch64-unknown-linux-gnu.tar.gz" \
        | tar xz && \
        mkdir -p /usr/java/packages/lib && \
        mv libsignal_jni.so /usr/java/packages/lib/ ; \
    fi

ENV SIGNAL_CLI_PATH=/usr/local/bin/signal-cli
USER node
WORKDIR /home/node

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "/app/openclaw.mjs", "gateway", "--bind", "0.0.0.0"]

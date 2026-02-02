FROM ghcr.io/openclaw/openclaw:latest

USER root

ARG SIGNAL_CLI_VERSION=0.13.23

# System deps:
# - default-jre: signal-cli is a Java app
# - ffmpeg: voice notes / video processing from WhatsApp/Signal
# - dumb-init: proper PID 1 signal handling in K8s (no zombie processes)
# - curl/zip: needed for signal-cli install + ARM64 native lib patching
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre \
    ffmpeg \
    dumb-init \
    curl \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Install signal-cli
RUN curl -fsSL \
        "https://github.com/AsamK/signal-cli/releases/download/v${SIGNAL_CLI_VERSION}/signal-cli-${SIGNAL_CLI_VERSION}.tar.gz" \
    | tar xz -C /opt \
    && ln -sf "/opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli" /usr/local/bin/signal-cli

# signal-cli bundles libsignal_jni.so for x86_64 only.
# On aarch64 (Raspberry Pi) we swap it with a community ARM64 build.
# https://github.com/exquo/signal-libs-build
RUN ARCH="$(uname -m)" && \
    if [ "$ARCH" = "aarch64" ]; then \
        JAR="$(ls /opt/signal-cli-${SIGNAL_CLI_VERSION}/lib/libsignal-client-*.jar)" && \
        LIBSIGNAL_VER="$(basename "$JAR" .jar | sed 's/libsignal-client-//')" && \
        curl -fsSL \
            "https://github.com/exquo/signal-libs-build/releases/download/libsignal_v${LIBSIGNAL_VER}/libsignal_jni.so-v${LIBSIGNAL_VER}-aarch64-unknown-linux-gnu.tar.gz" \
        | tar xz && \
        zip -d "$JAR" libsignal_jni.so && \
        mkdir -p /usr/java/packages/lib && \
        mv libsignal_jni.so /usr/java/packages/lib/ ; \
    fi

ENV SIGNAL_CLI_PATH=/usr/local/bin/signal-cli

# Playwright Chromium -- lets the agent browse the web for you.
# Only Chromium to keep image size reasonable.
RUN npx playwright install --with-deps chromium

USER node
WORKDIR /home/node

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["node", "/app/openclaw.mjs", "gateway", "--bind", "0.0.0.0"]

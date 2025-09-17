# multi-arch aware Dockerfile (supports amd64 and arm64)
FROM debian:stable-slim

ARG RACKET_VER=8.16-minimal
# Docker BuildKit will populate TARGETARCH (e.g. "amd64" or "arm64")
ARG TARGETARCH

# Set working directory
WORKDIR /app

# Install build dependencies only temporarily
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
       ca-certificates \
       sqlite3 \
       git \
       xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Download and install Racket Minimal (multi-arch)
# - uses TARGETARCH when provided by build system (buildx)
# - maps common architecture names, tries a fallback filename if needed
RUN set -eux; \
    # map Docker's TARGETARCH / uname -m to Racket release filenames
    arch="${TARGETARCH:-$(uname -m)}"; \
    case "$arch" in \
      amd64|x86_64) racket_arch="x86_64-linux-cs"; ;; \
      arm64|aarch64) racket_arch="aarch64-linux-cs"; ;; \
      *) racket_arch="${arch}-linux-cs"; ;; \
    esac; \
    base="https://download.racket-lang.org/installers/${RACKET_VER}"; \
    url="${base}/racket-minimal-${RACKET_VER}-${racket_arch}.tgz"; \
    echo "Trying to download $url"; \
    if ! curl -fSL "$url" -o /tmp/racket.tgz; then \
      # fallback: some releases omit the "-cs" suffix or use slightly different naming
      alt_arch="$(echo $racket_arch | sed 's/-cs//')"; \
      alt_url="${base}/racket-minimal-${RACKET_VER}-${alt_arch}.tgz"; \
      echo "Primary download failed, trying fallback $alt_url"; \
      curl -fSL "$alt_url" -o /tmp/racket.tgz; \
    fi; \
    tar xzf /tmp/racket.tgz -C /usr --strip-components=1; \
    rm -f /tmp/racket.tgz

# Clone your app repository
RUN git clone --depth=1 https://gitdab.com/cadence/breezewiki.git . \
    && apt-get purge -y git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Persist GC-related environment variables in the image
ENV PLT_GC_INITIAL_HEAP_MB=32
ENV PLT_GC_MAX_HEAP_MB=128

# Install Racket dependencies without docs
RUN raco pkg install --batch --auto --no-docs --skip-installed req-lib \
    && raco req -d \
    && rm -rf ~/.cache/racket ~/.local/share/racket/${RACKET_VER}/doc || true

# Expose the port your app uses
EXPOSE 10416

# Run your app
CMD ["racket", "dist.rkt"]


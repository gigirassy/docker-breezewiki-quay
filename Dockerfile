# Multi-arch multi-stage Dockerfile for Racket app (x86_64 & arm64)
# Final image is small (distroless/cc) and contains only runtime + app.

# ---- Build stage ----
FROM debian:stable-slim AS builder

ARG RACKET_VER=8.16
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /src

# Install minimal build/runtime helpers (kept only in builder)
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates xz-utils git sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Download and install Racket into /opt/racket (keeps /usr clean)
RUN set -eux; \
    arch="${TARGETARCH:-$(uname -m)}"; \
    case "$arch" in \
      amd64|x86_64) racket_arch="x86_64-linux-cs"; ;; \
      arm64|aarch64) racket_arch="aarch64-linux-cs"; ;; \
      *) racket_arch="${arch}-linux-cs"; ;; \
    esac; \
    base="https://download.racket-lang.org/installers/${RACKET_VER}"; \
    url="${base}/racket-minimal-${RACKET_VER}-${racket_arch}.tgz"; \
    echo "Downloading $url"; \
    if ! curl -fSL "$url" -o /tmp/racket.tgz; then \
      # try a common fallback name (sometimes naming varies)
      alt_arch="$(echo $racket_arch | sed 's/-cs//')"; \
      alt_url="${base}/racket-minimal-${RACKET_VER}-${alt_arch}.tgz"; \
      echo "Primary download failed, trying ${alt_url}"; \
      curl -fSL "$alt_url" -o /tmp/racket.tgz; \
    fi; \
    mkdir -p /opt/racket; \
    tar xzf /tmp/racket.tgz -C /opt/racket --strip-components=1; \
    rm -f /tmp/racket.tgz

# Make Racket tools available in PATH for the build steps
ENV PATH="/opt/racket/bin:${PATH}"
ENV PLT_GC_INITIAL_HEAP_MB=32
ENV PLT_GC_MAX_HEAP_MB=128

# Clone app, install runtime deps (raco pkgs)
# Adjust repo URL/path as needed; using user's URL from earlier conversation
RUN git clone --depth=1 https://gitdab.com/cadence/breezewiki.git . \
    && raco pkg install --batch --auto --no-docs --skip-installed req-lib \
    && raco req -d \
    && rm -rf ~/.cache/racket ~/.local/share/racket/${RACKET_VER}/doc \
    && apt-get purge -y git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# ---- Runtime stage (small) ----
# Use distroless cc (contains C runtime / glibc) — multi-arch variants available
FROM gcr.io/distroless/cc-debian11

# Copy Racket runtime installed under /opt/racket from the builder
COPY --from=builder /opt/racket /opt/racket
# Copy app
COPY --from=builder /src /app

# Ensure racket is on PATH
ENV PATH="/opt/racket/bin:${PATH}"
ENV PLT_GC_INITIAL_HEAP_MB=32
ENV PLT_GC_MAX_HEAP_MB=128
WORKDIR /app

# Expose your app port (doc-only)
EXPOSE 10416

# Use absolute path for entrypoint (distroless has no shell)
ENTRYPOINT ["/opt/racket/bin/racket"]
CMD ["dist.rkt"]

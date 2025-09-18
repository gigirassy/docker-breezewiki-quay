# Multi-arch multi-stage Dockerfile for Racket app (x86_64 & arm64)
FROM debian:stable-slim AS builder

ARG RACKET_VER=8.18
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /src

# Minimal tools for install/build
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates xz-utils git sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Download & install Racket into /opt/racket
# Download & install Racket into /opt/racket (robust, multiple filename attempts)
RUN set -eux; \
    arch="${TARGETARCH:-$(uname -m)}"; \
    case "$arch" in \
      amd64|x86_64) racket_arch="x86_64-linux-cs"; ;; \
      arm64|aarch64) racket_arch="aarch64-linux-cs"; ;; \
      *) racket_arch="${arch}-linux-cs"; ;; \
    esac; \
    base="https://download.racket-lang.org/installers/${RACKET_VER}"; \
    # candidate filenames (order intentionally covers common variants)
    candidates=( \
      "racket-minimal-${RACKET_VER}-${racket_arch}.tgz" \
      "racket-minimal-${RACKET_VER}-$(echo ${racket_arch} | sed 's/-cs//').tgz" \
      "racket-minimal-${RACKET_VER}-$(echo ${racket_arch} | sed 's/-cs//g' | sed 's/aarch64/arm64/').tgz" \
      "racket-minimal-${RACKET_VER}-x86_64-linux-cs.tgz" \
      "racket-minimal-${RACKET_VER}-x86_64-linux-buster-cs.tgz" \
      "racket-minimal-${RACKET_VER}-x86_64-linux.tgz" \
      "racket-minimal-${RACKET_VER}-aarch64-linux-cs.tgz" \
      "racket-minimal-${RACKET_VER}-aarch64-linux.tgz" \
      "racket-minimal-${RACKET_VER}-aarch64-linux-cs.tgz" \
      "racket-minimal-${RACKET_VER}-aarch64-linux-buster-cs.tgz" \
      "racket-minimal-${RACKET_VER}-aarch64-linux.tgz" \
    ); \
    echo "Arch detected: $arch -> trying racket_arch: $racket_arch"; \
    rm -f /tmp/racket.tgz || true; \
    success=0; \
    for f in "${candidates[@]}"; do \
      url="${base}/${f}"; \
      echo "Attempting: $url"; \
      # curl: follow redirects, fail on HTTP >=400, retry transient errors
      if curl --retry 3 --retry-delay 2 -fSL "$url" -o /tmp/racket.tgz; then \
        echo "Downloaded $url"; success=1; break; \
      else \
        echo "Failed to download $url (status/connection) — checking headers:"; \
        curl -I --max-time 10 "$url" || true; \
      fi; \
    done; \
    if [ "$success" -ne 1 ]; then \
      echo "ERROR: could not download any candidate Racket tarball. Tried:"; \
      for f in "${candidates[@]}"; do echo "  - ${base}/${f}"; done; \
      echo "If these URLs are missing, check the Racket download site for the exact filename for ${RACKET_VER} and ${arch}."; \
      exit 22; \
    fi; \
    mkdir -p /opt/racket; \
    tar xzf /tmp/racket.tgz -C /opt/racket --strip-components=1; \
    rm -f /tmp/racket.tgz



ENV PATH="/opt/racket/bin:${PATH}"
ENV PLT_GC_INITIAL_HEAP_MB=32
ENV PLT_GC_MAX_HEAP_MB=128

# Clone app, install required raco packages (install web-server explicitly)
RUN git clone --depth=1 https://gitdab.com/cadence/breezewiki.git . \
    && raco pkg install --batch --auto --no-docs --skip-installed web-server req-lib \
    && raco req -d \
    && rm -rf ~/.cache/racket ~/.local/share/racket/${RACKET_VER}/doc \
    && apt-get purge -y git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# ---- Runtime stage (small, distroless with glibc) ----
FROM gcr.io/distroless/cc-debian11

# Copy Racket runtime and app from builder
COPY --from=builder /opt/racket /opt/racket
COPY --from=builder /src /app

# IMPORTANT: copy user-installed racket packages so collections are available at runtime
# This is where raco put per-user packages in the builder; copying it makes collections such as "web-server" visible.
COPY --from=builder /root/.local/share/racket /root/.local/share/racket

ENV PATH="/opt/racket/bin:${PATH}"
ENV PLT_GC_INITIAL_HEAP_MB=32
ENV PLT_GC_MAX_HEAP_MB=128
WORKDIR /app

EXPOSE 10416
ENTRYPOINT ["/opt/racket/bin/racket"]
CMD ["dist.rkt"]

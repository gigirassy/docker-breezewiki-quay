
FROM racket:8.17-bc

# Set working directory
WORKDIR /app

# Install build/runtime utilities (keep them minimal)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       sqlite3 \
       git \
       xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Clone your app repository (shallow)
RUN git clone --depth=1 https://gitdab.com/cadence/breezewiki.git . \
    && apt-get purge -y git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Persist GC-related environment variables in the image
ENV PLT_GC_INITIAL_HEAP_MB=32
ENV PLT_GC_MAX_HEAP_MB=128

# Install Racket packages (no docs), then clean caches
RUN raco pkg install --batch --auto --no-docs --skip-installed req-lib \
    && raco req -d \
    && rm -rf ~/.cache/racket ~/.local/share/racket/${RACKET_VER}/doc || true

# Expose the port your app uses
EXPOSE 10416

# Run your app
CMD ["racket", "dist.rkt"]


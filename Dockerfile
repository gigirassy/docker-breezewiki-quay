FROM debian:stable-slim

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

# Download and install Racket Minimal
RUN curl -L https://download.racket-lang.org/installers/8.16/racket-minimal-8.16-x86_64-linux-cs.tgz \
    | tar xz -C /usr --strip-components=1

# Clone your app repository
RUN git clone --depth=1 https://gitdab.com/cadence/breezewiki.git . \
    && apt-get purge -y git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

RUN export PLT_GC_INITIAL_HEAP_MB=32
RUN export PLT_GC_MAX_HEAP_MB=128

# Install Racket dependencies without docs
RUN raco pkg install --batch --auto --no-docs --skip-installed req-lib \
    && raco req -d \
    && rm -rf ~/.cache/racket ~/.local/share/racket/8.16/doc

# Expose the port your app uses
EXPOSE 10416

# Run your app
CMD ["racket", "dist.rkt"]

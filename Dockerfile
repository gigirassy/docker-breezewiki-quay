# Build stage
FROM debian:stable-slim AS builder

WORKDIR /app

RUN apt update && \
    apt install -y --no-install-recommends \
    git \
    racket \
    ca-certificates \
    curl \
    sqlite3 && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://gitdab.com/cadence/breezewiki.git .

RUN raco pkg install --batch --auto --no-docs --skip-installed req-lib && \
    raco req -d

# Final stage
FROM debian:stable-slim

WORKDIR /app

COPY --from=builder /app /app

EXPOSE 10416

CMD ["racket", "dist.rkt"]

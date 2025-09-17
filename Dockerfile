# Build stage
FROM debian:stable-slim AS builder

WORKDIR /app

RUN apt update \
 && apt install -y --no-install-recommends \
    git racket ca-certificates curl sqlite3 \
    libfontconfig1 libcairo2 libpango-1.0-0 libfreetype6 libx11-6 libxrender1 libpng16-16 libjpeg62-turbo

RUN git clone --depth=1 https://gitdab.com/cadence/breezewiki.git .

RUN raco pkg install --batch --auto --no-docs --skip-installed req-lib && \
    raco req -d

FROM debian:stable-slim AS runtime

# Copy the app
COPY --from=builder /app /app
COPY --from=builder /usr/bin/racket /usr/bin/
COPY --from=builder /usr/bin/raco /usr/bin/
COPY --from=builder /usr/share/racket /usr/share/racket

# Runtime deps only
RUN apt update \
 && apt install -y --no-install-recommends \
    ca-certificates sqlite3 \
    libfontconfig1 libcairo2 libpango-1.0-0 libfreetype6 libx11-6 libxrender1 libpng16-16 libjpeg62-turbo \
 && rm -rf /var/lib/apt/lists/*

EXPOSE 10416
CMD ["racket", "/app/dist.rkt"]

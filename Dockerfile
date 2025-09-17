FROM debian:stable-slim

WORKDIR /app

# Install only required packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git \
       racket \
       ca-certificates \
       curl \
       sqlite3 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Clone repo with shallow history
RUN git clone --depth=1 https://gitdab.com/cadence/breezewiki.git . \
    && apt-get purge -y git \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Install Racket dependencies without docs
RUN raco pkg install --batch --auto --no-docs --skip-installed req-lib \
    && raco req -d

EXPOSE 10416

CMD ["racket", "dist.rkt"]

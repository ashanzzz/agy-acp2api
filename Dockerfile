FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    AGY2API_HOST=0.0.0.0 \
    AGY2API_PORT=8787 \
    AGY_BIN=/usr/local/bin/agy

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    bash \
    git \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 8787

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8787/health >/dev/null || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]

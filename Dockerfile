# ---- Stage 1 : Build ----
FROM node:20.19.0-alpine3.21 AS builder

WORKDIR /app

COPY src/package*.json ./
RUN npm ci --only=production

# ---- Stage 2 : Runtime ----
FROM node:20.19.0-alpine3.21 AS runtime

LABEL maintainer="devsecops@startup.io"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/startup/taskapi"

ENV NODE_ENV=production
ENV PORT=3000

WORKDIR /app

RUN apk upgrade --no-cache \
    && addgroup -S appgroup && adduser -S -u 1001 appuser -G appgroup \
    && mkdir -p /app/tmp \
    && chown -R appuser:appgroup /app

COPY --from=builder /app/node_modules ./node_modules
COPY src/server.js .

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]

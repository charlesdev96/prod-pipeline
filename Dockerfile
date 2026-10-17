# ---- Stage 1: builder - install production dependencies only ----
FROM node:20-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# ---- Stage 2: runner - small image that only runs the app ----
FROM node:20-alpine AS runner
ENV NODE_ENV=production
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]

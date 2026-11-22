FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json tsconfig.json ./
RUN npm install
COPY src ./src
RUN npm run build

FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

FROM node:22-alpine AS runtime
WORKDIR /app
RUN addgroup -g 10001 -S appgroup && adduser -u 10001 -S appuser -G appgroup
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --chown=appuser:appgroup public ./public
COPY --chown=appuser:appgroup package.json ./package.json
ENV NODE_ENV=production
ENV PORT=8080
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack
USER appuser
EXPOSE 8080
CMD ["node", "dist/app.js"]

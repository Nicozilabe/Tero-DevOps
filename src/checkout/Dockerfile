FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn
RUN YARN_ENABLE_IMMUTABLE_INSTALLS=false node .yarn/releases/yarn-4.11.0.cjs install
COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src
RUN node .yarn/releases/yarn-4.11.0.cjs build

FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json .yarnrc.yml ./
COPY .yarn ./.yarn
COPY --from=builder /app/yarn.lock ./yarn.lock
RUN YARN_ENABLE_IMMUTABLE_INSTALLS=false node .yarn/releases/yarn-4.11.0.cjs workspaces focus --production

FROM node:22-alpine AS runtime
WORKDIR /app
RUN addgroup -g 10001 -S appgroup && adduser -u 10001 -S appuser -G appgroup
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --chown=appuser:appgroup package.json ./package.json
ENV NODE_ENV=production
ENV PORT=8080
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack
USER appuser
EXPOSE 8080
CMD ["node", "dist/main.js"]

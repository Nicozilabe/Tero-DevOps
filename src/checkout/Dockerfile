FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn
RUN node .yarn/releases/yarn-4.11.0.cjs install --immutable
COPY tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src
RUN node .yarn/releases/yarn-4.11.0.cjs build

FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json yarn.lock .yarnrc.yml ./
COPY .yarn ./.yarn
RUN node .yarn/releases/yarn-4.11.0.cjs workspaces focus --production

FROM node:22-alpine AS runtime
WORKDIR /app
RUN addgroup -g 10001 -S appgroup && adduser -u 10001 -S appuser -G appgroup
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --chown=appuser:appgroup package.json ./package.json
ENV NODE_ENV=production
ENV PORT=8080
USER appuser
EXPOSE 8080
CMD ["node", "dist/main.js"]

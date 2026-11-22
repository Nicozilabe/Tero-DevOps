FROM golang:1.27-alpine AS builder
WORKDIR /app
RUN apk add --no-cache gcc musl-dev
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -o /catalog .

FROM alpine:3.23 AS runtime
WORKDIR /app
RUN apk add --no-cache ca-certificates \
    && addgroup -g 10001 -S appgroup \
    && adduser -u 10001 -S appuser -G appgroup
COPY --from=builder --chown=appuser:appgroup /catalog ./catalog
ENV GIN_MODE=release
ENV PORT=8080
USER appuser
EXPOSE 8080
CMD ["./catalog"]

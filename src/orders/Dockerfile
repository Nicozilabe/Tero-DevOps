FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /orders .

FROM gcr.io/distroless/static-debian12:nonroot AS runtime
WORKDIR /app
COPY --from=builder --chown=nonroot:nonroot /orders ./orders
ENV GIN_MODE=release
ENV PORT=8080
USER nonroot:nonroot
EXPOSE 8080
CMD ["./orders"]

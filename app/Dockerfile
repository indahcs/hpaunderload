FROM golang:1.23-alpine AS builder 

# makes /app the current directory inside the builder
WORKDIR /app

# copies the files into /app inside the builder
COPY go.mod .
COPY main.go .

# CGO_ENABLED=0 disables CGO
# GOOS=linux sets the target OS to Linux
RUN CGO_ENABLED=0 GOOS=linux go build -o burn-app main.go

FROM alpine:3.21
WORKDIR /app

# creates a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup 
# copies only the compiled binary
COPY --from=builder /app/burn-app .

USER appuser 
EXPOSE 8080 
CMD ["./burn-app"]
# Go Container Build Guide

This file documents the Go container recipe stored in `go.yml`. The file name is `.yml`, but the contents are Dockerfile instructions, so Docker can build it with the `--file` flag.

The image uses a two-stage build:

1. A Go builder image compiles the service binary.
2. A small Alpine runtime image copies in the binary and product data, then starts the service.

## What The Container Does

The Product Catalog service loads product data and serves it over gRPC. When the container starts successfully, you should see logs similar to:

```text
INFO[0000] Loaded 10 products
INFO[0000] Product Catalog gRPC server started on port: 8088
```

## `go.yml` Walkthrough

### 1. Builder stage

```dockerfile
FROM golang:1.22-alpine AS builder
```

Starts the build stage with the Go toolchain installed. This stage is only used to compile the application.

```dockerfile
WORKDIR /usr/src/app
```

Sets the working directory inside the container. Every later copy and command runs from this path.

```dockerfile
COPY go.mod go.sum ./
```

Copies the module definition files first. This is a caching optimization: Docker can reuse the dependency layer when source code changes but module requirements do not.

```dockerfile
RUN go mod download
```

Downloads Go dependencies into the build image before the rest of the source is copied. That keeps later builds faster and more repeatable.

```dockerfile
COPY . .
```

Copies the application source into the build container. This is the source-to-build mapping step.

```dockerfile
RUN go build -o product-catalog .
```

Compiles the Go service into a binary named `product-catalog`.

### 2. Runtime stage

```dockerfile
FROM alpine:latest
```

Starts a small runtime image. The application is already compiled, so the Go toolchain is no longer needed.

```dockerfile
WORKDIR /usr/src/app
```

Sets the runtime working directory.

```dockerfile
COPY --from=builder /usr/src/app/product-catalog .
COPY ./products ./products
```

Copies the compiled binary from the builder stage into the runtime image, then copies the `products` directory so the service can serve product data at runtime.

```dockerfile
ENV PRODUCT_CATALOG_PORT=8088
```

Sets the default port used by the service inside the container. You can override it at runtime if needed.

```dockerfile
CMD ["./product-catalog"]
```

Defines the container startup command. When the container starts, Docker launches the compiled binary.

## Build Locally

To compile the service directly on your machine, run:

```sh
export PRODUCT_CATALOG_PORT=<any-unique-port>
go build -o product-catalog .
```

The service should log output similar to the snippet above.

## Build The Docker Image

From the repository root, build the image with:

```sh
docker build --file ./docker-images/golang/go.yml --tag product-catalog ./docker-images/golang
```

If you are already inside `docker-images/golang`, you can also build with:

```sh
docker build --file ./go.yml --tag product-catalog .
```

## Run The Container

After the image is built, start it with:

```sh
docker run --rm -p 8088:8088 -e PRODUCT_CATALOG_PORT=8088 product-catalog
```

If you want to use a different port, make the host mapping and the environment variable match:

```sh
docker run --rm -p 8090:8090 -e PRODUCT_CATALOG_PORT=8090 product-catalog
```

## Docker Compose Build

The existing readme also mentions the compose flow. From the repository root, you can build the service with:

```sh
docker compose build product-catalog
```

## Regenerate Protobufs

If the generated protobuf files need to be refreshed, run:

```sh
make docker-generate-protobuf
```

## Bump Dependencies

To update Go dependencies, run:

```sh
go get -u -t ./...
go mod tidy
```

If you prefer Docker Compose, the existing workflow in this repository also supports:

```sh
docker compose build product-catalog
```

## Run The Container

After the image is built, run it with:

```sh
docker run --rm -p 8088:8088 -e PRODUCT_CATALOG_PORT=8088 product-catalog
```

If you want to use a different port, update both the environment variable and the port mapping.

## Regenerate Protos

If the protobuf definitions need to be regenerated, run:

```sh
make docker-generate-protobuf
```

## Update Dependencies

To bump Go module dependencies, run:

```sh
go get -u -t ./...
go mod tidy
```
# Docker Compose Demo

This folder contains a **demo-only** Docker Compose stack for the demo services in this repo.
It is not meant to be production-ready. The goal is to show how the services can be started together
and how the image templates in `docker-images/` map to the compose setup.

## What is included

- `product-service` uses the Go-based product catalog image.
- `ad-service` uses the Java-based ad image.
- `recommendation-service` uses the Python-based recommendation image.
- `mongo` provides the backing MongoDB container.

## Compose file

The active compose file is `docker-compose.yaml`.

```yaml
version: "3.9"

services:
  product-service:
    build: ./src/product-catalog
    ports:
      - "8088:8088"
    environment:
      PRODUCT_CATALOG_PORT: "8088"
    networks:
      - microservices-network

  ad-service:
    build: ./src/ad-service
    ports:
      - "9099:9099"
    environment:
      AD_PORT: "9099"
    networks:
      - microservices-network

  recommendation-service:
    build: ./src/recommendation-service
    ports:
      - "1010:1010"
    environment:
      RECOMMENDATION_PORT: "1010"
    networks:
      - microservices-network

  mongo:
    image: mongo:6
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db
    networks:
      - microservices-network

volumes:
  mongo_data:

networks:
  microservices-network:
    driver: bridge
```

## Line-by-line explanation

### `version: "3.9"`

Sets the Compose file format version. This keeps the file readable and compatible with modern Compose usage.

### `services:`

Starts the section where each containerized service is defined.

### `product-service`

Builds the Go product catalog image from its service folder.

- `build: ./src/product-catalog` points to the build context.
- `ports: "8088:8088"` maps host port `8088` to container port `8088`.
- `PRODUCT_CATALOG_PORT` tells the app which port to listen on.
- `networks` connects the service to the shared demo network.

### `ad-service`

Builds the Java ad service image.

- `build: ./src/ad-service` uses the ad service source tree.
- `ports: "9099:9099"` exposes the ad service on port `9099`.
- `AD_PORT` matches the port expected by the Java image template.
- `networks` keeps the service on the same bridge network as the others.

### `recommendation-service`

Builds the Python recommendation service image.

- `build: ./src/recommendation-service` points to the Python service source tree.
- `ports: "1010:1010"` exposes the recommendation service on port `1010`.
- `RECOMMENDATION_PORT` matches the Python image template.
- `networks` attaches it to the shared demo network.

### `mongo`

Uses the official MongoDB image instead of building a custom image.

- `image: mongo:6` pulls MongoDB version 6.
- `ports: "27017:27017"` exposes MongoDB on the default port.
- `volumes: mongo_data:/data/db` keeps database data on a named volume.
- `networks` places MongoDB on the same internal network as the services.

### `volumes:`

Defines named storage used by the database container.

- `mongo_data` persists MongoDB data even if the container is recreated.

### `networks:`

Defines the shared bridge network used by the demo stack.

- `microservices-network` is the internal network all services join.

## Demo compose notes

This compose file is intentionally simple:

- it shows how the services are wired together
- it mirrors the ports defined in the image templates under `docker-images/`
- it uses a named volume for MongoDB persistence
- it keeps every service on one shared bridge network

## Related image docs

See these files for the image-level details:

- `docker-images/golang/go.yml`
- `docker-images/java/java.yaml`
- `docker-images/python/py.yaml`


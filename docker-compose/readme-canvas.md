# Compose Canvas

This canvas shows the same **demo compose** in a clean, copyable form.

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

## Why this is a demo compose

It is only meant to demonstrate service wiring, ports, volumes, and the shared network.
The build contexts are placeholders for the service source directories in the fuller demo project.


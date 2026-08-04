# Python Service Docker Guide

This document explains how the Python-based recommendation service is packaged into a Docker image and how to build and run it locally.

## What this image does

The Docker image starts a Python application named `recommendation_server.py` inside a lightweight Linux container. It installs the Python dependencies from `requirements.txt`, copies the application files into the container, and exposes the service on a configurable port.

The default port for this service is set through the environment variable `RECOMMENDATION_PORT`, and the default value in the Dockerfile is `1010`.

---

## Prerequisites

Before building the image, make sure you have:

- Docker installed and running on your machine
- A valid `requirements.txt` file in the same folder as the Dockerfile
- The Python application file, such as `recommendation_server.py`

If Docker is not installed yet, install Docker Desktop or the Docker Engine appropriate for your operating system.

---

## File structure used by this image

The Docker build expects the following files to be available in the build context:

- `py.yaml` — the Dockerfile content
- `requirements.txt` — Python dependencies
- `recommendation_server.py` — the main application entrypoint
- any additional Python source files needed by the app

The build context is the folder containing these files, so Docker can copy them into the image.

---

## Step-by-step explanation of the Dockerfile

The Dockerfile used in this project is:

```dockerfile
FROM python:3.12-slim-bookworm AS builder
WORKDIR /usr/src/app 

COPY requirements.txt ./

RUN pip install --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV RECOMMENDATION_PORT=1010
ENTRYPOINT ["python", "recommendation_server.py"]
```

Each instruction is important:

1. `FROM python:3.12-slim-bookworm AS builder`
   - Starts from a lightweight Python 3.12 base image based on Debian Bookworm.
   - The `AS builder` label names this stage so it can be referenced later if needed.
   - Using a slim image keeps the final container smaller and more efficient.

2. `WORKDIR /usr/src/app`
   - Sets the working directory inside the container.
   - All later commands run from this location unless another directory is specified.

3. `COPY requirements.txt ./`
   - Copies the dependency list into the container.
   - This is done before the application code so Docker can cache dependency installation separately.

4. `RUN pip install --upgrade pip`
   - Upgrades `pip` to the latest available version inside the container.
   - This helps avoid compatibility issues while installing Python packages.

5. `RUN pip install --no-cache-dir -r requirements.txt`
   - Installs all required Python libraries from `requirements.txt`.
   - The `--no-cache-dir` option reduces image size by avoiding pip cache files.

6. `COPY . .`
   - Copies the rest of the application files into the container.
   - This includes the Python source code, configuration files, and any other required assets.

7. `ENV RECOMMENDATION_PORT=1010`
   - Defines the default environment variable for the application port.
   - If you run the container without specifying a port, the service will use `1010`.

8. `ENTRYPOINT ["python", "recommendation_server.py"]`
   - Tells Docker to start the application automatically when the container starts.
   - The command runs `recommendation_server.py` using Python.

---

## Building the Docker image

From the directory that contains the Dockerfile and application files, run:

```sh
docker build -t recommendation-service:latest .
```

### What this command does

- `build` tells Docker to create an image from the current folder.
- `-t recommendation-service:latest` gives the image a name and tag.
- The final `.` tells Docker to use the current directory as the build context.

If you want a different name, you can replace it with something like:

```sh
docker build -t my-python-service:dev .
```

---

## Running the container

After the image is built, start the service with:

```sh
docker run -p 1010:1010 recommendation-service:latest
```

### What the options mean

- `-p 1010:1010` maps port `1010` on your host machine to port `1010` inside the container.
- `recommendation-service:latest` is the image name created earlier.

If you want to run the container in the background, add the detached flag:

```sh
docker run -d -p 1010:1010 recommendation-service:latest
```

---

## Running with a different port

If your application should use a different port, you can override the environment variable at runtime:

```sh
docker run -p 8080:8080 -e RECOMMENDATION_PORT=8080 recommendation-service:latest
```

This is useful when the host machine already uses `1010` or when you want to avoid conflicts with another local service.

---

## Checking container logs

If you want to see what the service is doing while it is running, use:

```sh
docker ps
```

Then inspect the logs for a specific container:

```sh
docker logs <container_id_or_name>
```

---

## Stopping and removing the container

To stop a running container:

```sh
docker stop <container_id_or_name>
```

To remove it after stopping:

```sh
docker rm <container_id_or_name>
```

To remove the image as well:

```sh
docker rmi recommendation-service:latest
```

---

## Common issues and fixes

### 1. `requirements.txt` is missing

If `requirements.txt` is not present, the dependency installation step will fail.

Make sure the file exists in the build folder before running `docker build`.

### 2. The app starts but is not reachable

Check whether:

- the port mapping is correct
- the application actually listens on the expected port
- the container is still running

### 3. The container exits immediately

This usually means the Python entrypoint failed. Check the logs with:

```sh
docker logs <container_id_or_name>
```

Look for missing files, import errors, or invalid configuration values.

---

## Summary

This Docker image:

- uses a Python base image
- installs dependencies from `requirements.txt`
- copies the application source into the container
- exposes the service on `RECOMMENDATION_PORT`
- starts the service by launching `recommendation_server.py`

With these steps, the Python service can be built and run in a consistent, portable container environment.

# Java Container Build Guide

This file documents the Java container recipe stored in `java.yaml`. The file name is `.yaml`, but the contents are Dockerfile instructions, so Docker can build it with the `--file` flag.

The image packages the Ad service from source, builds the runnable distribution with Gradle, then copies only the runtime output into a smaller JRE image.

## What The Container Does

The Ad service returns ads based on context keys. When no keys are present, it serves random ads. The container build has two phases:

1. Build phase: use a full JDK image to resolve dependencies and compile the app.
2. Runtime phase: use a smaller JRE image to run the already-built application.

## `java.yaml` Walkthrough

### 1. Builder stage

```dockerfile
FROM eclipse-temurin:21-jdk AS builder
```

This starts a build stage with a full JDK. The JDK is required because Gradle must compile and package the application.

```dockerfile
WORKDIR /usr/src/app
```

Sets the working directory inside the container. Every following file copy and command runs from this path.

```dockerfile
COPY gradle* settings.gradle* build.gradle .
COPY ./gradle ./gradle
```

Copies the Gradle wrapper files and project build files first. This ordering helps Docker reuse cached layers when source code changes but build configuration does not.

```dockerfile
RUN chmod +x ./gradlew
RUN ./gradlew
RUN ./gradlew downloadRepos
```

Makes the wrapper executable, then runs Gradle to initialize the wrapper and prefetch dependencies. The dependency download step reduces the chance that the later compile step has to fetch everything from scratch.

```dockerfile
COPY . .
COPY ./pb ./proto
```

Copies the rest of the source tree and maps the protocol buffer directory to the location expected by the build. This is the source-to-build input mapping: local source files are made available inside the container under the paths the Gradle tasks use.

```dockerfile
RUN chmod +x ./gradlew
RUN ./gradlew installDist -PprotoSourceDir=./proto
```

Builds the distributable application. `installDist` creates a runnable layout with scripts and libraries, and `-PprotoSourceDir=./proto` tells the build where to find generated proto sources.

### 2. Runtime stage

```dockerfile
FROM eclipse-temurin:21-jre
```

Starts a smaller runtime image. The JRE is enough to execute the compiled app, so the final image stays smaller than the build image.

```dockerfile
WORKDIR /usr/src/app
```

Sets the runtime working directory. The application will execute relative to this directory.

```dockerfile
COPY --from=builder /usr/src/app ./
```

Copies the built output from the builder stage into the runtime image. This is the key handoff between build-time and run-time containers.

```dockerfile
ENV AD_PORT=9099
```

Sets the default port used by the Ad service inside the container. You can override this value at runtime with `-e AD_PORT=...`.

```dockerfile
ENTRYPOINT ["./build/install/opentelemetry-demo-ad/bin/Ad"]
```

Defines the command that runs when the container starts. Docker launches the Ad service script produced by Gradle.

## Build Locally

Before building the image, you can also build the service directly on your machine. The project requires at least JDK 17 and uses the Gradle wrapper.

```sh
./gradlew installDist
```

Or, if the proto source directory must be passed explicitly:

```sh
./gradlew installDist -PprotoSourceDir=./proto
```

That produces the runnable distribution under `build/install/opentelemetry-demo-ad/`.

## Build The Docker Image

From the repository root, build the image using the Dockerfile-style `java.yaml` file:

```sh
docker build --file ./docker-images/java/java.yaml --tag opentelemetry-java-ad ./docker-images/java
```

This command tells Docker:

1. Which file to use for the image definition.
2. Which build context to send to Docker.
3. What name to give the resulting image.

## Run The Container

After the image is built, start the service with:

```sh
docker run --rm -p 9099:9099 -e AD_PORT=9099 opentelemetry-java-ad
```

If the Ad service depends on the feature flag gRPC service in your environment, you can pass that address too:

```sh
docker run --rm -p 9099:9099 \
	-e AD_PORT=9099 \
	-e FEATURE_FLAG_GRPC_SERVICE_ADDR=featureflagservice:50053 \
	opentelemetry-java-ad
```

## Gradle Wrapper Upgrade

If you need to upgrade the version of Gradle, run:

```sh
./gradlew wrapper --gradle-version <new-version>
```
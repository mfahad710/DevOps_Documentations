# Saving & Loading Docker Images

Managing Docker images across different environments often requires exporting and importing images without relying on an online container registry. Docker provides two essential commands for this: **`docker save`** and **`docker load`**.

## 📦 Saving a Docker Image

### Purpose
The `docker save` command exports one or more Docker images into a **tar archive file (`.tar`)**.  
This file contains:
- Image layers
- Metadata (history, environment variables, entrypoints, etc.)
- Tags

### Syntax
```bash
docker save -o <file-name>.tar <image-name>:<tag>
```
Example
Save the `nginx:latest` image into a tar file:

```bash
docker save -o nginx.tar nginx:latest
```

This will create a `nginx.tar` file in your current directory containing the image.

We can save **multiple images at once**:

```bash
docker save -o my-images.tar nginx:latest redis:7 alpine:3.18
```

> Difference between `docker export` and `docker save`:
> `docker save`: Saves images (with all metadata, tags, layers).
> `docker export`: Exports a **container filesystem only** (without history, tags, or metadata).

## 📥 Loading a Docker Image

### Purpose
The docker load command restores images from a tar (`.tar`) into Docker’s local image registry.

This makes the image available for use on the system where it was imported.

### Syntax

```bash
docker load -i <file-name>.tar
```

**Example**

Load the `nginx.tar` file into Docker:

```bash
docker load -i nginx.tar
```

Verify the image is available:

```bash
docker images
```

You should see `nginx:latest` listed in your images.

## Use Cases

### Offline Use
Move images to air-gapped servers (no internet access).
- Save the image on a system with internet access.
- Copy the `.tar` file via USB or secure transfer.
- Load it on the offline system.

### Backup
Store `.tar` files of critical images as part of your backup strategy.
- Helps restore in case of accidental deletion or corruption.

### Migration
Transfer custom-built images between environments.
- Move from development → testing → production without pushing to Docker Hub or a private registry.

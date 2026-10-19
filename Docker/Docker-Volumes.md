# Docker Volume

## Overview

Docker offers three ways to keep data outside a container's writable layer: **volumes**, **bind mounts** and **tmpfs mounts**. Anything written inside a container without one of these is lost when the container is removed.

- **Volume**: storage created and managed by Docker, kept under Docker's own data directory.
- **Bind mount**: a file or directory from the host, mapped to a path in the container.
- **tmpfs mount**: temporary storage held in the host's memory, never written to disk.

## 1. Volume mounts

A volume is a directory Docker creates and manages itself; on Linux it lives at `/var/lib/docker/volumes/<name>/_data`. Containers reach it by volume name, so the host path does not matter to them. Volumes are the recommended way to persist data.

```bash
docker volume create wireguard_volume
docker run -d --name wg -v wireguard_volume:/etc/wireguard wireguard-image
```

**Anonymous volume** is created without a name (Docker assigns a random hash). It is easy to lose track of and is removed with the container if you use `docker rm -v` or `--rm`. Avoid it for important data.

```bash
docker run -d -v /etc/wireguard wireguard-image
```

### `--mount` syntax
The `--mount` syntax is more explicit than `-v` and is preferred in scripts and Compose files:

```bash
docker run -d --mount type=volume,source=wireguard_volume,target=/etc/wireguard wireguard-image
```

### Advantages of Volume mounts:

- Managed through the Docker CLI (`docker volume ls`, `inspect`, `rm`, `prune`).
- Work the same on Linux, Mac and Windows, and in Docker Desktop.
- Easier to back up, migrate and share between containers than bind mounts.
- A new empty volume is pre-filled with the image's existing content at the mount path.
- Can use volume drivers for remote or cloud storage.

### Limitations:

- The files sit in a Docker-owned directory, so editing them from the host needs root and care.
- `docker volume prune` deletes volumes not used by any container, so unattached data can be lost.

## 2. Bind mounts

A bind mount maps a specific file or directory on the host into the container. You choose the host path, and both sides see the same files live, so an edit on the host appears in the container immediately.

```bash
# -v syntax (host path must be absolute)
docker run -d -v /opt/wireguard:/etc/wireguard wireguard-image

# --mount syntax
docker run -d --mount type=bind,source=/opt/wireguard,target=/etc/wireguard wireguard-image

# read-only
docker run -d -v /opt/wireguard:/etc/wireguard:ro my-wireguard-image
```

### Advantages of Bind mounts:

- Full control over the host location, so files are easy to edit, back up or version with normal tools.
- Ideal for development: mount source code and see changes without rebuilding the image.
- Good for sharing host config files such as `/etc/localtime` or a single `nginx.conf`.

### Limitations:

- Depends on the host's directory layout, so it is less portable between machines.
- The container can change host files unless you add `:ro`, which is a security risk.
- With `-v`, a missing host path is created as an empty root-owned directory. With `--mount`, Docker returns an error instead.
- File ownership and permissions use the host's UIDs and GIDs, which can cause permission errors when the container user differs.
- A bind mount hides any content the image already has at the target path.
- Not managed by `docker volume` commands.

## 3. tmpfs mounts

A tmpfs mount keeps data in the host's memory only. Nothing is written to disk, and the data is gone when the container stops. It is available on Linux only.

```bash
docker run -d --tmpfs /app/cache app-image

docker run -d --mount type=tmpfs,target=/app/cache,tmpfs-size=64m app-image
```

Use it for sensitive data that must not reach disk (tokens, session secrets) or for fast scratch space. It cannot be shared between containers, and its contents count against host memory.

## Comparison

Use volumes for persistent application data, bind mounts when you need to work with host files directly, and tmpfs for temporary or sensitive data.

|  | Volume | Bind mount | tmpfs |
| --- | --- | --- | --- |
| Stored at | Docker area (`/var/lib/docker/volumes/`) | Any host path we choose | Host memory |
| Managed by | Docker (`docker volume`) | You | Docker |
| Survives container removal | Yes (named) | Yes | No |
| Survives container restart | Yes | Yes | No |
| Portable across hosts | High | Low | n/a |
| Pre-populated from image | Yes (empty named volume) | No | No |
| Edit from host | Possible, needs root | Easy | No |
| Shared between containers | Yes | Yes | No |
| Typical use | Databases, VPN configs, app state | Dev source code, host config files | Secrets, scratch cache |

## Copying volume

### Method 1: temporary container

This is the portable method: a throwaway Alpine container mounts both volumes and copies the data through Docker's own mounts. It works with any Docker data root, rootless Docker and Docker Desktop, and needs no `sudo` or host path.

```bash
# 1. Create the destination volume
docker volume create wireguard_volume

# 2. Copy the data from the old volume into the new one
docker run --rm \
  -v old_wireguard_volume:/from:ro \
  -v wireguard_volume:/to \
  alpine sh -c "cp -a /from/. /to/"
```

| Part | Meaning |
| --- | --- |
| `docker run --rm` | Starts a container and deletes it on exit. The volumes are kept. |
| `-v old_wireguard_volume:/from:ro` | Mounts the source volume at `/from`, read-only, so it cannot be changed by mistake. |
| `-v wireguard_volume:/to` | Mounts the destination volume at `/to`, read-write. |
| `alpine` | A tiny (about 5 MB) image that provides `sh` and `cp`. |
| `sh -c "..."` | Runs the quoted string as a shell command inside the container. |
| `cp -a` | Archive mode: copies recursively and keeps permissions, ownership, timestamps and symlinks. This matters for WireGuard keys and configs. |
| `/from/.` | The contents of `/from`, including hidden files. `/from/*` would miss dotfiles. |
| `/to/` | The destination directory. |

Order of events: Docker starts the Alpine container with both volumes attached, `cp` copies everything, the container exits and is removed, and `wireguard_volume` now holds an identical copy of `old_wireguard_volume`.

### Method 2: directly on the host

On a plain Linux host with the default Docker root, you can copy between the volume directories directly, because each named volume is a folder at `/var/lib/docker/volumes/<name>/_data`. Run it as root, and stop any container that writes to the source volume first.

```bash
# 1. Create the destination volume so Docker sets up its _data directory
docker volume create wireguard_volume

# 2. Copy with cp
sudo cp -a /var/lib/docker/volumes/old_wireguard_volume/_data/. \
           /var/lib/docker/volumes/wireguard_volume/_data/
```

Notes:

- **Stop the container first** if it is running and writing to the volume, to avoid copying a half-written state.
- **Run as root.** `/var/lib/docker` is root-owned.

### Verify the copy

```bash
sudo diff -r /var/lib/docker/volumes/old_wireguard_volume/_data \
             /var/lib/docker/volumes/wireguard_volume/_data && echo "identical"
```

## Quick reference

| Task | Command |
| --- | --- |
| List volumes | `docker volume ls` |
| Create a volume | `docker volume create <name>` |
| Show details and host path | `docker volume inspect <name>` |
| Find Docker's data root | `docker info \| grep "Docker Root Dir"` |
| Remove a volume | `docker volume rm <name>` |
| Remove unused volumes | `docker volume prune` (deletes data, check first) |
| Mount a named volume | `-v <name>:/path` or `--mount type=volume,source=<name>,target=/path` |
| Mount a host directory | `-v /host/path:/path` or `--mount type=bind,source=/host/path,target=/path` |
| Mount read-only | add `:ro` (with `-v`) or `,readonly` (with `--mount`) |
| Mount tmpfs | `--tmpfs /path` or `--mount type=tmpfs,target=/path` |
| See which containers use a volume | `docker ps -a --filter volume=<name>` |
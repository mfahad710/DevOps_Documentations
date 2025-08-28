# 📄 Secure Copy Protocol (SCP) and Rsync in Linux

## Secure Copy Protocol

**SCP** (Secure Copy Protocol) is a command-line utility used to securely copy files and directories between systems on a network. It uses SSH (**Secure Shell**) for authentication and encryption, ensuring that the data is securely transferred.

- SCP replaces the insecure `rcp` command.
- It encrypts both the file contents and authentication credentials.
- It can be used for:
  - Copying files **from local to remote**
  - Copying files **from remote to local**
  - Copying files **between two remote systems via a local system** 

### SCP Syntax
```bash
scp [options] source destination
```

### SCP Commands

Copy a file from local to remote server

```bash
scp file.txt user@remote_host:/home/user/
```
Copy with key
```bash
scp -i /path/to/key file.txt user@remote_host:/home/user/
```
Copy a directory recursively

```bash
scp -r myfolder/ user@remote_host:/home/user/
```

Use a specific port (e.g., **2222** instead of default **22**)

```bash
scp -P 2222 file.txt user@remote_host:/home/user/
```

Copy a file from **remote** to **local machine**

```bash
scp user@remote_host:/home/user/file.txt /local/directory/
```

Example
```bash
scp -i ~/Downloads/automation_key.pem ubuntu@20.253.221.139:/var/www/html/stage-cypress/ /home/fahad/Documents
```

Copy between **two remote hosts** (executed from local machine)

```bash
scp user1@remote1:/home/user1/file.txt user2@remote2:/home/user2/
```

## Rsync

rsync (**Remote Sync**) is a powerful file-copying and synchronization tool in Linux. Unlike SCP, which just copies files, rsync is optimized to copy only the differences between source and destination.

- Uses **delta-transfer algorithm:** transfers only changed parts of files.
- Can work **locally** or over **SSH** for remote transfers.
- Supports features like compression, bandwidth limits, and file synchronization.

### Rsync Syntax
```bash
rsync [options] source destination
```

### Rsync Commands

Copy file from local to remote

```bash
rsync file.txt user@remote_host:/home/user/
```

Copy directory recursively with progress

```bash
rsync -avz myfolder/ user@remote_host:/home/user/
```

- a → archive mode (preserves permissions, symbolic links, timestamps, etc.)
- v → verbose
- z → compress during transfer

Copy file from remote to local

```bash
rsync user@remote_host:/home/user/file.txt /local/directory/
```

Synchronize two directories

```bash
rsync -avz /local/dir/ user@remote_host:/home/user/dir/
```

Delete files in destination that don’t exist in source (mirror sync)

```bash
rsync -avz --delete /local/dir/ user@remote_host:/home/user/dir/
```

Limit bandwidth usage (e.g., 500 KB/s)

```bash
rsync --bwlimit=500 -avz myfolder/ user@remote_host:/home/user/
```
## Difference Between SCP and Rsync  

| Feature | **SCP** | **Rsync** |
|---------|---------|-----------|
| **Protocol** | Uses SSH for secure file transfer | Uses SSH for secure file transfer + delta algorithm |
| **Performance** | Copies entire file every time, even if unchanged | Copies only changed parts of files (faster for large files) |
| **Compression** | Not enabled by default (can use `-C`) | Built-in compression option (`-z`) |
| **Synchronization** | Simple copy tool (no sync) | Supports synchronization and mirroring |
| **Resource Usage** | Higher bandwidth usage | Efficient – uses less bandwidth and time |
| **Use Case** | Best for quick, one-time secure transfers | Best for backups, directory synchronization, incremental transfers |


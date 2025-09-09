# SSH Logs

SSH (**Secure Shell**) logs are crucial for monitoring and maintaining the security and performance of systems that use SSH for remote management. These logs are typically recorded by the **SSH daemon (sshd)**, which handles incoming SSH connections. Logs provide insights into user activity, connection attempts, authentication successes and failures, and other relevant events.

## Example SSH Log
```log
Jul 17 09:23:45 server1 sshd[1234]: Accepted publickey for user1 from 192.168.1.100 port 52413 ssh2: RSA SHA256:abcdefghijklmnopqrstuvwxyz123456789ABCDEFG
```

## Key Elements of SSH Logs

### Timestamp
- Indicates the date and time when the log entry was recorded.
- **Example:** `Jul 12 08:23:45`

### Hostname
- The name of the host machine where the SSH daemon is running.
- **Example:** `server1`

### Process Name
- The name of the process that generated the log entry (usually `sshd`).
- **Example:** `sshd`

### Process ID (PID)
- The process ID of the SSH daemon instance that generated the log entry.
- **Example:** `1234`

### Event Type
- Describes the type of event being logged.
- Common event types include:
  - `Accepted`
  - `Failed`
  - `Disconnected`
  - `session opened`
  - `session closed`

## Accessing SSH Logs

### Using `journalctl`
`journalctl` is used to view logs managed by **systemd** (common in modern Linux distros such as Ubuntu, CentOS, and Debian).

- View SSH logs:
```bash
journalctl -u ssh
```

- View logs within a specific time range:
```bash
journalctl -u ssh --since "2023-07-01" --until "2023-07-12"
```

### Accessing `/var/log/auth.log`
On systems that **do not use systemd** (e.g., older Debian/Ubuntu versions), SSH logs are stored in `/var/log/auth.log`.

- View logs in real-time:
```bash
tail -f /var/log/auth.log
```

- Search for SSH-related entries:
```bash
grep sshd /var/log/auth.log
```

## Other Useful Commands

### `cat`
```bash
cat /var/log/auth.log
```

### `less`
```bash
less /var/log/auth.log
```

### `grep`
```bash
grep sshd /var/log/auth.log
```

### `tail`
```bash
tail -f /var/log/auth.log
```

## Using `lastlog`

- View last login details for all users:
```bash
lastlog
```

- View last login of a specific user:
```bash
lastlog -u username
```

## Viewing Login and Logout with `last`
The `last` command reads from `/var/log/wtmp` and shows login/logout sessions, times, durations, and hostnames.

- View all recent logins:
```bash
last
```

- Show the last 5 login sessions:
```bash
last -5
```

- Hide hostname field in output:
```bash
last -R <username>
```

## Summary
SSH logs are an essential part of monitoring and securing systems. They provide detailed information about authentication events, user activity, and potential security threats. System administrators can access these logs using `journalctl`, `/var/log/auth.log`, and commands like `lastlog` and `last` for effective auditing.

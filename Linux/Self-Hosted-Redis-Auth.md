# Self-Hosted Redis with Authentication Enable

## Overview
When self-hosting Redis on a virtual machine (VM), the specifications you need depend on your workload (expected traffic, data size, and performance requirements).

## Steps

### 1. Create VM
Create a VM according to the requirement on any Cloud/on-prem environment.

### 2. Remote Connect
SSH to the VM:
```bash
ssh -i /key/path user@IP-Address
```

### 3. Install Redis on a Virtual Machine

For **Ubuntu/Debian**:
```bash
sudo apt update
sudo apt install redis-server -y
```

### 4. Configure Redis Authentication

#### Edit the Redis Configuration File
```bash
sudo nano /etc/redis/redis.conf
```

#### Enable Password Authentication
```bash
requirepass YourStrongPassword123!  # Set a strong password
```

#### Disable Dangerous Commands (Optional but Recommended)
```bash
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command CONFIG ""
rename-command SHUTDOWN ""
```

#### Configure IP for External Use
```bash
bind 0.0.0.0
```

#### Enable Protected Mode
```bash
protected-mode yes
```

### 5. Apply Changes & Restart Redis
```bash
sudo systemctl restart redis-server
sudo systemctl enable redis-server
```

### 6. Verify Redis is Running
```bash
sudo systemctl status redis-server
```

### 7. Verify Redis Security

#### Using redis-cli (Direct Test)
Connect to Redis:
```bash
redis-cli
```

Try running a command without authentication:
```bash
PING
```
If authentication is enabled, Redis will return:
```
(error) NOAUTH Authentication required.
```

If authentication is disabled, Redis will respond:
```
PONG
```

Now authenticate with your password and retry:
```bash
redis-cli -h <HOST> -p 6379 -a <PASSWORD>
```

Run a command:
```bash
PING
```
If successful, it will return:
```
PONG
```

### 8. Redis Logs
Monitor Redis logs:
```bash
sudo tail -f /var/log/redis/redis-server.log
```

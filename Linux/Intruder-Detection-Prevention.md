# 📄 Intruder Detection and Prevention

## Intruder
An **intruder** in computer security is someone (or something) that gains unauthorized access to a system, network, or application.

Think of it like a thief breaking into a house — except in this case, the "house" is your server, cloud VM, or computer.

## Types of Intruders:

### 1. External Intruder (Hacker/Attacker)

- Someone outside your organization trying to break in.

**Example**: A hacker scanning open ports on your Azure VM to exploit vulnerabilities.

### 2. Internal Intruder

- A person who already has some access (like an employee or contractor) but misuses it.

**Example**: An insider using admin privileges to steal data.

### 3. Automated Intruders (Bots/Malware)

- Programs/scripts designed to exploit systems automatically.

**Example**: A botnet attempting thousands of SSH login attempts (brute force) on your VM.

## Goals of Intruders:

- Steal data (credentials, financial info, intellectual property).
- Disrupt services (e.g., Denial of Service attacks).
- Install malware or backdoors for future access.
- Use your machine’s resources for illegal activities (like crypto mining or launching attacks on others).


## 1. Detecting an Intruder

To determine if an intruder is active or has tampered with, you can check logs and active sessions:

### Check Active Users and Sessions

Run the `who` or `w` command to see who is currently logged in:

``` bash
who
w
```

This shows the username, login time, IP address (if remote), and what
they're doing. If you see an unfamiliar user or IP, it could indicate an
intruder.

### Check the last login history:

``` bash
last
```

This displays a log of all recent logins, including failed attempts
(from `/var/log/auth.log`). Look for logins from unexpected IPs or
times.

### Inspect System Logs

Check the authentication log:

``` bash
sudo cat /var/log/auth.log
```

Look for successful or failed login attempts. Entries like `sshd` (SSH
daemon) will show login activity. Suspicious IPs or repeated failed
attempts could signal an intruder.

Check general system logs:

``` bash
sudo cat /var/log/syslog
```

This might reveal unusual activity, like service restarts or file
changes.

### Look for Unexpected Processes

Use `ps` to list running processes:

``` bash
ps aux
```

Check for unfamiliar processes not tied to `ubuntu`, `fahad`. An intruder might run a script or backdoor.

Use `netstat` or `ss` to check network connections:

``` bash
sudo netstat -tulnp
# or
sudo ss -tulnp
```

Look for unknown connections or listening ports that don't match your expected services.

## 2. Tracking Commands Executed by Users

### Check User Command History

Each user's command history is stored in their `~/.bash_history` file. For example, for ubuntu:

``` bash
cat /home/ubuntu/.bash_history
```

Run these as root (`sudo`) if you don't have direct access. This shows commands they've typed in the terminal, but it's not foolproof---users can clear or disable it.

### Enable Command Auditing with auditd

For a more robust solution, install and configure the **auditd** tool:

Install auditd:

``` bash
sudo apt update
sudo apt install auditd
```

Start the service:

``` bash
sudo systemctl enable auditd
sudo systemctl start auditd
```

Add a rule to log all commands:

``` bash
sudo auditctl -a exit,always -F arch=b64 -S execve
```

View logs:

``` bash
sudo ausearch -ui <USER_UID>
```

This logs every command executed, tied to the user, and is harder to
bypass than `.bash_history`.


## 3. Removing an Intruder

If you suspect an intruder:

### Kill their session:

Use the `w` command to identify their PTS (terminal session), then terminate it:

``` bash
sudo kill -9 <PID>
```

Replace `<PID>` with the process ID from `w` or `ps aux`.

### Change passwords:

Reset passwords for all users:

``` bash
sudo passwd ubuntu
```

### Disable unused accounts:

If a user shouldn't have access:

``` bash
sudo usermod -L <username>  # Locks the account
```

Check for new users:

``` bash
cat /etc/passwd
```

If you see an unfamiliar account, remove it:

``` bash
sudo userdel -r <username>
```

## 4. Preventing Future Intrusions:

### Secure SSH:

Edit `/etc/ssh/sshd_config`:

``` bash
sudo nano /etc/ssh/sshd_config
```

-   Change the default port (e.g., `Port 2222` instead of `22`)
-   Disable root login: `PermitRootLogin no`
-   Allow only specific users: `AllowUsers ubuntu fahad mehdi`

Restart SSH:

``` bash
sudo systemctl restart sshd
```

### Set up a firewall:

Use **ufw** to restrict access:

``` bash
sudo ufw allow 2222/tcp  # Replace with your SSH port
sudo ufw deny 22         # Block default SSH if changed
sudo ufw enable
```

### Use key-based authentication:

Disable password logins in `/etc/ssh/sshd_config`:

``` bash
PasswordAuthentication no
```

Restart SSH again.

### Monitor logs regularly:

Use `tail` to watch logs in real-time:

``` bash
sudo tail -f /var/log/auth.log
```

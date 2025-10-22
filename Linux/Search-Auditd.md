# 🔍 How to Trace Who Deleted a Directory
Red Hat Enterprise Linux (RHEL)

## Scenario
We created a directory `/opt/temp` and it has now disappeared.  
We want to find **which user deleted it** on a RHEL system.

## Step 1: Verify Audit Service (auditd)

Check if the Linux auditing service is active:

```bash
systemctl status auditd
```

If inactive, start and enable it (for future tracking):

```bash
systemctl start auditd
systemctl enable auditd
```

> **Note:** If auditd was not running at the time of deletion, the deletion event will not be recorded.

## Step 2: Search Audit Logs for Deletion Events

### Check for deletion of `/opt/temp` specifically:
```bash
ausearch -f /opt/temp -x rm
```

### Broader search for `/opt/temp` events:
```bash
ausearch -f /opt/temp
```

### Check for all deletions under `/opt`:
```bash
ausearch -k delete -f /opt
```

### Check generic delete-related commands:
```bash
ausearch -x rm
ausearch -x rmdir
ausearch -x unlink
```

You may see logs like:

```
type=SYSCALL msg=audit(1718786540.654:292): pid=4567 uid=1001 auid=1001 ...
```

- `uid` → user ID that executed the command  
- `auid` → original user ID who started the session

To map UID to a username:
```bash
getent passwd <uid>
```

## Step 3: Check Shell History of Users

If the deletion was manual (e.g., `rm -rf`), check users’ `.bash_history`:

```bash
grep -E "rm|rmdir" /home/*/.bash_history
grep -E "rm|rmdir" /root/.bash_history
```

To see recent commands from currently logged-in users:

```bash
history
```

Check recent user logins:
```bash
last
```

## Step 4: Review System Logs

Search general system logs for relevant entries:

```bash
grep -i "rm" /var/log/secure
grep -i "deleted" /var/log/messages
grep -i "opt" /var/log/audit/audit.log
```

These may show timestamps and process IDs related to the deletion.

## Step 5: Enable Future Auditing for `/opt`

To monitor future file or directory modifications in `/opt`, add an audit rule:

```bash
auditctl -w /opt -p wa -k opt_monitor
```

This watches for:
- `w` → write actions
- `a` → attribute changes

To make it **persistent** across reboots:

Edit the audit rules file:

```bash
vi /etc/audit/rules.d/audit.rules
```

Add:
```
-w /opt -p wa -k opt_monitor
```

Then restart the audit service:
```bash
systemctl restart auditd
```

## Optional: Automated Script to Detect Suspicious Deletions

Create a helper script `/usr/local/bin/check_deletions.sh`:

```bash
#!/bin/bash
echo "=== Searching Audit Logs for Deleted Directories Under /opt ==="
ausearch -x rm -f /opt --success yes --interpret

echo -e "\n=== Checking User Histories for rm/rmdir Commands ==="
grep -E "rm|rmdir" /home/*/.bash_history /root/.bash_history 2>/dev/null

echo -e "\n=== Checking System Logs ==="
grep -i "deleted" /var/log/messages | tail -n 20
```

Make it executable:
```bash
chmod +x /usr/local/bin/check_deletions.sh
```

Run it when needed:
```bash
check_deletions.sh
```

# Service Port & Process Monitoring Script

## Overview

This Bash script continuously monitors running services on a system and maps:
- Service Name
- Process ID (PID)
- Port Number
- Status

It focuses on:

- Frontend services managed by PM2
- Backend Java services (JAR-based)

The script refreshes every 10 seconds, providing near real-time visibility into service activity.

## Script

```bash
#!/bin/bash

while true; do
  echo "=== Service Port Mapping and Process PID ==="
  echo "Timestamp: $(date)"
  echo ""

  # ---------- Frontend Services (PM2) ----------
  echo "---- Frontend Services (PM2) ----"
  pm2 list --no-color 2>/dev/null | grep -E '^\s*│' | grep -v 'name' | while IFS='│' read -r _ id name namespace version mode pid uptime restart status cpu mem user watching _; do
      name=$(echo "$name" | xargs)
      pid=$(echo "$pid" | xargs)
      status=$(echo "$status" | xargs)

      if [[ -z "$name" || "$name" == "name" ]]; then
          continue
      fi

      port=$(ss -tunlp | grep "pid=$pid," | awk '{print $5}' | cut -d: -f2 | head -1)
      [[ -z "$port" ]] && port="N/A"

      echo "Port: $port → PID: $pid → Service: $name → Status: $status"
  done

  echo ""

  # ---------- Backend Services (JAVA) ----------
  echo "---- Backend Services (JAVA) ----"
  ss -tunlp | grep java | awk '{print $5}' | cut -d: -f2 | sort -n | while read port; do
    pid=$(ss -tunlp | grep ":$port" | grep java | awk -F'pid=' '{print $2}' | cut -d',' -f1)
    if [[ -n "$pid" ]]; then
      jar=$(ps -p "$pid" -o cmd --no-headers | grep -o '[^ ]*\.jar')
      echo "Port: $port → PID: $pid → Service: $jar"
    fi
  done

  echo ""
  sleep 10
done
```

## How It Works

The script runs in an infinite loop (while true) and performs the following steps:

- Extracts and displays frontend services from PM2
- Extracts and displays backend Java services
- Sleeps for 10 seconds
- Repeats

#### Main Loop

```bash
while true; do
```

- Ensures the script runs continuously.


### Frontend Services (PM2 Section)

Lists all processes managed by PM2
```bash
pm2 list --no-color
```

- `--no-color` ensures clean parsing.

Filtering Output
```bash
grep -E '^\s*│' | grep -v 'name'
```

- Extracts only relevant rows from PM2 table output and Removes header rows.

Parsing Columns
```bash
while IFS='│' read -r _ id name namespace version mode pid uptime restart status cpu mem user watching _;
```

- Splits each row into columns using │
- Extracts:
  - name → Service name
  - pid → Process ID
  - status → Running state

Cleanup Values
```bash
name=$(echo "$name" | xargs)
pid=$(echo "$pid" | xargs)
status=$(echo "$status" | xargs)
```

- Removes extra whitespace for clean output.

Port Detection
```bash
port=$(ss -tunlp | grep "pid=$pid," | awk '{print $5}' | cut -d: -f2 | head -1)
```

- Uses `ss` to find which port the process is listening on.
- Matches the PID to its network socket.
- Extracts the port number.

Fallback:
```bash
[[ -z "$port" ]] && port="N/A"
```

### Backend Services (Java Section)

Detect Java Processes
```bash
ss -tunlp | grep java
```

- Finds all listening ports used by Java processes.

Extract Ports
```bash
awk '{print $5}' | cut -d: -f2 | sort -n
```

- Extracts port numbers.
- Sorts them numerically.

Loop Through Ports
```bash
while read port; do
```

- Iterates over each detected Java port.

Get PID
```bash
pid=$(ss -tunlp | grep ":$port" | grep java | awk -F'pid=' '{print $2}' | cut -d',' -f1)
```

- Matches port to PID using socket info.

Extract JAR Name
```bash
jar=$(ps -p "$pid" -o cmd --no-headers | grep -o '[^ ]*\.jar')
```

- Retrieves the .jar file name from the process command.
- Identifies the backend service.


### Sleep Interval
```bash
sleep 10
```

- Waits 10 seconds before refreshing.
- Prevents excessive CPU usage.


## Use Cases

- Debugging port conflicts
- Monitoring microservices
- DevOps observability
- Troubleshooting deployments
- Live system inspection

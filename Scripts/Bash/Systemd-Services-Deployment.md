# Systemd Service Deployment Automation Script

## Overview

This Bash script automates the deployment process of Java-based services managed by systemd. It handles:

- Backup of the existing `.jar` file
- Replacement with a new `.jar` file
- Restarting the service
- Verifying successful startup via logs (Tomcat detection)

## Script
```bash
#!/bin/bash

# Function to backup and replace the jar file
backup_and_replace_jar() {
    local service_name=$1
    local jar_path=$2
    local backup_path=$3

    # Ensure the backup directory exists
    if [ ! -d "$backup_path" ]; then
        echo "Error: Backup directory $backup_path does not exist. Creating it..."
        mkdir -p "$backup_path" || { echo "Failed to create backup directory."; exit 1; }
        sleep 3
    fi

    # Backup current jar file with timestamp
    local timestamp=$(date +%d%b%Y%H%M)
    if [ -f "$jar_path" ]; then
        echo "Backing up $jar_path to $backup_path/${service_name}-${timestamp}.jar"
        mv "$jar_path" "$backup_path/${service_name}-${timestamp}.jar" || { echo "Failed to backup $jar_path."; exit 1; }
        sleep 3
    else
        echo "Error: $jar_path does not exist. Skipping backup."
        exit 1
    fi

    # Move the new jar from /tmp/systemd-jars/ to the correct location
        local jar_dir="/tmp/systemd-jars/${service_name}" # before running the script make sure this directory exists
        local expected_jar="${service_name}.jar"
        local new_jar="$jar_dir/$expected_jar"

        # Check if the expected jar exists
        if [ ! -f "$new_jar" ]; then
            # Try to find a jar file with a similar name and correct it
            found_jar=$(ls "$jar_dir"/*.jar 2>/dev/null | head -n 1)
            if [ -n "$found_jar" ]; then
                actual_jar_name=$(basename "$found_jar")
                if [ "$actual_jar_name" != "$expected_jar" ]; then
                    echo "Warning: Found jar file '$actual_jar_name' does not match expected name '$expected_jar'. Renaming it."
                    mv "$found_jar" "$new_jar" || { echo "Failed to rename $found_jar to $new_jar."; exit 1; }
                    sleep 3
                fi
            else
                echo "Error: No jar file found in $jar_dir. Please provide the new jar file."
                exit 1
            fi
        fi

        # Now move the (correctly named) jar
        if [ -f "$new_jar" ]; then
            echo "Moving $new_jar to $jar_path"
            mv "$new_jar" "$jar_path" || { echo "Failed to replace $jar_path with $new_jar."; exit 1; }
            sleep 3
        else
            echo "Error: $new_jar does not exist after correction. Please provide the new jar file."
            exit 1
        fi
}

# Function to restart the service
restart_service() {
    local service_name=$1

    echo "Checking service status for $service_name..."
    systemctl is-active --quiet "$service_name"
    if [ $? -ne 0 ]; then
        echo "$service_name is not running. Starting the service..."
        systemctl start "$service_name" || { echo "Failed to start $service_name."; exit 1; }
    else
        echo "$service_name is running. Restarting the service..."
        systemctl restart "$service_name" || { echo "Failed to restart $service_name."; exit 1; }
        sleep 3
    fi
}

# Check if the Service's Jar is Started and Listening for Connection on Tomcat Server or fails
check_service_status() {
    local service_name=$1
    local timeout=120  # 2 minutes, Max Time to Search for given String in the Service's logs

    echo "Following logs for $service_name (max ${timeout}s) to detect Tomcat startup..."

    journalctl -fu "$service_name" --no-pager |
    while read -r line; do
        if echo "$line" | grep -q "Tomcat started on port"; then
            echo "Tomcat startup detected for $service_name"
            echo "$line"
            kill $watcher_pid 2>/dev/null  # stop journalctl once found
            return 0
        fi
    done &

    # Capture PID of background job
    watcher_pid=$!

    # Wait with timeout, if timeout max then kill the journalctl Process in Bg
    SECONDS=0
    while kill -0 $watcher_pid 2>/dev/null; do
        if [ $SECONDS -ge $timeout ]; then
            echo "Tomcat did not start within ${timeout}s for $service_name"
            kill $watcher_pid 2>/dev/null
            return 1
        fi
        sleep 2
    done
}

# Function to select systemd service
select_systemd_service() {
    echo "Select the Systemd Service to deploy:"
    echo "1 - fort-api"
    echo "2 - fort-ui"
    echo "3 - fort-api-stage"
    echo "4 - fort-ui-stage"

    read -p "Enter the number: " choice

    case $choice in
        1) service_name="fort-api"; jar_path="/opt/fort/fort-api/fort-api.jar"; backup_path="/opt/fort/fort-api/backups" ;;
        2) service_name="fort-ui"; jar_path="/opt/fort/fort-ui/fort-ui.jar"; backup_path="/opt/fort/fort-ui/backups" ;;
        3) service_name="fort-api-stage"; jar_path="/opt/fort/fort-api-stage/fort-api-stage.jar"; backup_path="/opt/fort/fort-api-stage/backups" ;;
        4) service_name="fort-ui-stage"; jar_path="/opt/fort/fort-ui-stage/fort-ui-stage.jar"; backup_path="/opt/fort/fort-ui-stage/backups" ;;
        *) echo "Invalid choice, exiting."; exit 1 ;;
    esac
}

# Main execution
select_systemd_service
sleep 3

# Backup and replace jar file
backup_and_replace_jar "$service_name" "$jar_path" "$backup_path"

# Restart the service
restart_service "$service_name"

# Check Service Status by following the logs for Tomcat Startup Message
check_service_status "$service_name"

echo "Deployment completed successfully for $service_name."

```

## How It Works

- User selects a service
- Existing JAR is backed up with a timestamp
- New JAR is fetched from a temporary directory `/tmp/systemd-jars/`
- Service is restarted (or started if stopped)
- Logs are monitored to confirm successful startup

### Functions Breakdown

#### 1. select_systemd_service

Prompts the user to choose which service to deploy.

Supported services:
- fort-api
- fort-ui
- fort-api-stage
- fort-ui-stage

Based on the selection, it sets:
- service_name
- jar_path (deployment location)
- backup_path (backup directory)

#### 2. backup_and_replace_jar

Handles the core deployment logic:
- Backup Process
- Checks if backup directory exists (creates it if missing)
- Moves current `.jar` to backup directory
- Adds timestamp for versioning

New JAR Handling
- Looks for new `.jar` in:

```bash
/tmp/systemd-jars/<service_name>/
```

- Ensures correct naming (<service_name>.jar)
- If mismatched, automatically renames it

Replacement
- Moves new JAR to the target deployment path

#### 3. restart_service

Manages the systemd service lifecycle:
- Checks if service is running
- If not running → starts it
- If running → restarts it

#### 4. check_service_status

Validates successful deployment by monitoring logs:

- If message is found → deployment success ✅
- If not found within 120 seconds → failure ❌

### Directory Structure Assumption
```bash
/opt/fort/<service>/
    ├── <service>.jar
    └── backups/

/tmp/systemd-jars/<service>/
    └── new jar file (any name, auto-corrected)
```

# Rclone

Rclone is an open source, multi threaded, command line computer program to manage or migrate content on cloud and other high latency storage. Its capabilities include sync, transfer, crypt, cache, union, compress and mount. The rclone website lists supported backends including **Azure Storage Account** and **Google Drive**.

## Installation

Install rclone in server by follow the instruction  
[Installation](https://rclone.org/install/)

> Then configure Azure and Google Drive

## Azure Storage Account setup

**Make sure we have Storage Account created on Azure.**

Go to the storage account and generate **SAS URL** and **SAS token** of contianer that we want to take backup through Azure portal  
Then configure `rclone` for the **azure blob storage** by, follow the instructions,

```bash
rclone config
```
> [Setup Link](https://rclone.org/azureblob/)

> **Note: only add SAS URL and SAS token in configuration, leave rest of the field blank**


### Check the configuration by,

**List the container**

```bash
rclone lsd azure:
```

**list the content/files/directory in the container**

```bash
rclone ls azure:<container-name>
```

---

## Google Drive setup

The initial setup for the drive involves getting a token from Google drive which you need to do in your browser. 

Configure Google Drive by,

```bash
rclone config
```

> [Follow the instructions](https://rclone.org/drive/)  

If don’t have **client ID** then generate by follow the instructions

> [How to create Client_ID](https://rclone.org/drive/#making-your-own-client-id)

**Example CLient_ID and Client_Secret**
```bash
client_id: 75183380093-md7fl8gj34m1d3gphd253g55bopkqbm5.apps.googleusercontent.com

client_secret: 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
```

**Note: This client id and secret is temporary**

Check configuration by,

If Rclone is configure in server so the server don’t have web browser to verification, so select n option in web browser option, then the terminal generate the link like,

```bash
rclone authorize "drive" "eyJjbGlQyNTNnNTVi0ejJ0R2hiZHJpdmUifQ"
```

Paste this link in the personal PC terminal then verify the configuration by login the Google Account.

The personal PC terminal give you the token like

```bash
eyJ0b2tlbiI6IntcaFJxOVVraXhLS1ViUkZIQ0x3Zjl6R2doalFxY0tfSVpHSXBQJ9
```
Paste this token in the server’s terminal and verify.

If the configuration is successful then, the server terminal will show message like,
Configuration complete.

**Check the Connection by listing the documents**

**List directories in top level of your drive**

```bash
rclone lsd gdrive:
```

**List all the files in your drive**

```bash
rclone ls gdrive:
```

**Test the gdrive connection by copy the file**

```bash
rclone copy /home/fahad/Documents/Notes.txt gdrive:GreenSign
```

---

## Script

After configuring **Azure Blob Storage** and **Google Drive**, in `rclone`.  
Then make script in server that runs rclone command to make backup possible from **Azure Storage Account** to **Google Drive**

### Create files for the script and log file

```bash
touch backup_to_gdrive.sh
touch scriptlogs.log
```

### Make the script file executable

```bash
chmod +x backup_to_gdrive.sh
```

### Open file in vi editor

```bash
vi backup_to_gdrive.sh
```
 
### Script Code:

```bash
#!/bin/bash

# Variables
CURRENT_TIME=$(date "+%Y-%m-%d-%H:%M")
GDRIVE_DIR="gdrive:Prod-Backups/prod-container/$CURRENT_TIME"
AZURE_DIR="prodContainer:prod-container"
LOG_FILE="/home/ubuntu/prodContainer/backup_logs.log"
MAX_BACKUPS=7

echo "********************************************************************************" >> "$LOG_FILE"
echo "$(date "+%Y-%m-%d %H:%M:%S") - Starting backup process." >> "$LOG_FILE"

# Create a directory in Google Drive with the current date and time
if rclone mkdir "$GDRIVE_DIR"; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Directory $GDRIVE_DIR created." >> "$LOG_FILE"
else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Failed to create directory $GDRIVE_DIR." >> "$LOG_FILE"
    exit 1
fi

# Copy all files from Azure Blob Storage to Google Drive
if rclone copy "$AZURE_DIR" "$GDRIVE_DIR" --transfers=16; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Backup completed successfully." >> "$LOG_FILE"
else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Backup failed. Check rclone logs for details." >> "$LOG_FILE"
fi

# Manage the number of backups, keeping only the latest $MAX_BACKUPS
BACKUPS_COUNT=$(rclone lsd "gdrive:Prod-Backups/prod-container/" | grep -c "^ ")
if (( BACKUPS_COUNT > MAX_BACKUPS )); then
    OLDEST_BACKUP=$(rclone lsd "gdrive:Prod-Backups/prod-container/" | grep "^ " | awk '{print $5,$6}' | sort | head -n 1)
    if rclone purge "gdrive:Prod-Backups/prod-container/$OLDEST_BACKUP"; then
        echo "$(date "+%Y-%m-%d %H:%M:%S") - Deleted oldest backup: $OLDEST_BACKUP." >> "$LOG_FILE"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S") - Failed to delete oldest backup because the number of backup is less than 7." >> "$LOG_FILE"
    fi
fi
echo "********************************************************************************" >> "$LOG_FILE"
``` 

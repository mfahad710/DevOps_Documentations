# Restoration

## Steps

To restore data from `Google Drive` to `Azure Blob Storage` account using rclone in case of disaster or data corruption.  

- First we need to create new **Storage Account** with **Version enabled**
- In Storage Account create blob container
- Go to server/VM which takes the Rclone backup.
- Configure the Rclone to add a newly created **storage account with container**.
- Find configuring steps of Rclone in Azure Storage Account Setup section in the Documentation: [Setup Link](https://rclone.org/azureblob/)
- After configuring a new storage account.
- Generate SAS Token for container that are use in the rclone configuration
- Then run the restoration scripts.
- Run bash script of blob container in the server `/home/ubuntu/prodcontainer/restore_from_gdrive.sh`
- Change the `AZURE_DIR` variable according to the requirements

## Script
```bash
#!/bin/bash

# Variables
GDRIVE_DIR="gdrive:Prod-Backups/prodcontiner"
AZURE_DIR="<RCOLNE_CONFIGURATION_NAME>:<STORAGE_BLOB_CONTAINER_NAME>"
LOG_FILE="/home/ubuntu/prodcontainer/restore_logs.log"

echo "********************************************************************************" >> "$LOG_FILE"
echo "$(date "+%Y-%m-%d %H:%M:%S") - Starting restore process." >> "$LOG_FILE"

# List the available backups in Google Drive
available_backups=($(rclone lsd "$GDRIVE_DIR" | grep "^ " | awk '{print $5}'))

if [ ${#available_backups[@]} -eq 0 ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - No backups found in $GDRIVE_DIR." >> "$LOG_FILE"
    exit 1
fi

# Prompt user to choose a backup to restore
echo "Available backups:"
for i in "${!available_backups[@]}"; do
    echo "$i) ${available_backups[$i]}"
done

read -p "Enter the number of the backup you want to restore: " backup_choice
selected_backup="${available_backups[$backup_choice]}"

if [ -z "$selected_backup" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Invalid selection." >> "$LOG_FILE"
    exit 1
fi

# Confirm the selection
echo "You have selected the backup: $selected_backup"
read -p "Are you sure you want to restore this backup? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Restore process canceled." >> "$LOG_FILE"
    exit 1
fi

echo "Start restoring files from Google Drive to Azure Blob Storage"
if rclone copy "gdrive:Prod-Backups/prodcontainer/$selected_backup" "$AZURE_DIR" --transfers=64; then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Restore completed successfully." >> "$LOG_FILE"
else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Restore failed. Check rclone logs for details." >> "$LOG_FILE"
fi

echo "********************************************************************************" >> "$LOG_FILE"
```

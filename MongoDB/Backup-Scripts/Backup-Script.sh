#!/bin/bash

# MongoDB connection details for source and target clusters
SOURCE_MONGODB_URI="<CONNECTION-STRING>"
TARGET_MONGODB_URI="mongodb://localhost:27017/"

# Destination path
BACKUP_DIR="/home/ubuntu/drive/db_backups"

# Log directory path
LOG_FILE="/home/ubuntu/drive/db_backups_log/backup.log"

# Backup filename based on timestamp
TIMESTAMP=$(date +"%Y%m%d%H%M")
BACKUP_NAME="Prod_backup_${TIMESTAMP}.gz"

# Log function
log() {
    echo "[$(date)] $1" >> "$LOG_FILE"
}

# Function to take MongoDB dump
backup_mongodb() {
    log "Starting cluster dump from source cluster..."
    mongodump --uri="${SOURCE_MONGODB_URI}" \
              --gzip \
              --archive="${BACKUP_DIR}/${BACKUP_NAME}"
    if [ $? -ne 0 ]; then
        log "Cluster dump failed!"
    fi
    log "Cluster dump completed successfully: ${BACKUP_DIR}/${BACKUP_NAME}"
}

# Function to keep only the latest 3 dumps
cleanup_old_dumps() {
    log "Cleaning up old backups..."
    cd "$BACKUP_DIR" || log "Failed to access backup directory."

    DUMP_COUNT=$(ls -1 *.gz | wc -l)
    if [ "$DUMP_COUNT" -gt 3 ]; then
        OLDEST_DUMP=$(ls -1t *.gz | tail -n 1) # Sort by time and select the oldest
        sudo rm -f "$OLDEST_DUMP"
        if [ $? -ne 0 ]; then
            log "Failed to delete the oldest dump."
        fi
        log "Deleted oldest dump: $OLDEST_DUMP"
    fi
}

# Function to drop all collections in each database
drop_collections() {
    log "Dropping existing collections in target cluster..."

    databases=("fort" "fort-admin")

    for db in "${databases[@]}"; do
        mongosh "mongodb://localhost:27017/$db" \
            --eval 'db.getCollectionNames().forEach(function(collection) { db[collection].drop(); })' \
            --quiet
        if [ $? -ne 0 ]; then
            log "Failed to drop collections in $db."
        fi
        log "Dropped collections in $db."
    done
}

# Function to restore MongoDB from dump
restore_mongodb() {
    log "Starting cluster restore to target cluster..."
    mongorestore --uri="${TARGET_MONGODB_URI}" \
                 --gzip \
                 --archive="${BACKUP_DIR}/${BACKUP_NAME}"
    if [ $? -ne 0 ]; then
        log "Cluster restore failed!"
    fi
    log "Cluster restore completed successfully to target cluster."
}

# Main execution flow
backup_mongodb
cleanup_old_dumps
drop_collections
restore_mongodb

log "Cluster dump and restore process finished."
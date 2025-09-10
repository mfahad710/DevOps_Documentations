# Dump Restore and Export Queries

## Install Database Tools
The MongoDB Database Tools are a suite of command-line utilities for working with MongoDB. They are distributed separately from the main MongoDB Server.

On Ubuntu/Debian

```bash
sudo apt-get install -y mongodb-database-tools
```

On  RHEL / CentOS / Amazon Linux

```bash
sudo yum install -y mongodb-database-tools
```
---

## Backup Operations

MongoDB provides the `mongodump` utility to create binary exports of database contents. This is the recommended method for creating backups as it preserves all MongoDB-specific data types and indexes.

### Basic mongodump Syntax

```bash
mongodump --uri="mongodb+srv://<username>:<password>@cluster-hostname/database"
```

### Examples  

**Backup entire cluster:**

```bash
mongodump --uri="mongodb+srv://<username>:<password>@fort-db.ylba6.mongodb.net/"
```

**Backup with custom output directory:**

```bash
mongodump --uri="mongodb+srv://<username>:<password>@fort-db.ylba6.mongodb.net/" --out /home/muhammadfahad
```

**Backup specific database:**

```bash
mongodump --uri="mongodb+srv://<username>:<password>@fort-db.ylba6.mongodb.net/<DB_NAME>"
```
### Key Options

- `--uri`: Connection string with authentication
- `--out` or `-o`: Output directory (default: ./dump)
- `--db`: Specific database to backup
- `--collection`: Specific collection to backup
- `--gzip`: Compress output
- `--archive`: Write to archive file instead of directory

---

## Restore Operations

The `mongorestore` utility imports data from a binary database dump created by `mongodump`. This is the counterpart to the backup operation.

### Basic mongorestore Syntax

```bash
mongorestore --uri="mongodb+srv://<username>:<password>@target-cluster/" /path/to/dump
```

### Examples

**Restore to target cluster:**

```bash
mongorestore --uri="mongodb+srv://<username>:<password>@fort-admin-db-pri.etprb.mongodb.net" /home/muhammadfahad
```

**Restore to specific database:**

```bash
mongorestore --uri="mongodb+srv://<username>:<password>@fort-admin-db-pri.etprb.mongodb.net/<DB_NAME>" /home/muhammadfahad/
```

### Key Options

- `--drop`: Drop collections before restoring

---

## Export Operations

`mongoexport` exports collection data to JSON, CSV, or TSV formats. This is useful for data analysis, migration, or integration with other systems.

### Basic mongoexport Syntax

```bash
mongoexport --uri="connection-string" --collection=collectionName --out=outputFile
```

### Examples

**Export filtered data to CSV:**

```bash
mongoexport --uri "mongodb+srv://<USERNAME>:<PASSWORD>@fort-db-pri.etprb.mongodb.net/fort" --collection async_tasks --query '{"status": "completed", "type": "Send email"}' --out /home/muhammadfahad/async_tasks_filtered.csv
```

### Key Options

- `--query` or `-q`: Filter query
- `--fields`: Specific fields to export
- `--type`: Output format (json, csv, tsv)
- `--pretty`: Pretty-print JSON output

---

## Log Export Operations

Exporting system logs, particularly the profiling data, for performance analysis and debugging.

### Examples
**Export system profile data:**

```bash
mongoexport --uri="mongodb+srv://<USERNAME>:<PASSWORD>@fort-db-pri.etprb.mongodb.net/fort" --collection system.profile --type json --out querylogs.json
```

---

## Mongo Shell Operations

The MongoDB shell (mongosh) provides a JavaScript interface to interact with MongoDB instances for administration and data manipulation.

### Connection Examples

**Connect with explicit parameters:**

```bash
mongosh --host $HOSTNAME --port $PORT -u $DB_USERNAME -p $DB_PASSWORD --authenticationDatabase $AUTH_DB --eval "printjson(db.setProfilingLevel(2));" $DB_NAME
```

**Connect with connection string:**

```bash
mongosh "mongodb+srv://<USERNAME>:<PASSWORD>@fort-db-pri.etprb.mongodb.net/fort" --eval "printjson(db.setProfilingLevel(2));"
```

> **Set profiling level: `db.setProfilingLevel(2)` - enables detailed query profiling

## Environment Variables Setup
For security, consider using environment variables:

```bash
# Set credentials as environment variables
export MONGO_USERNAME="your_username"
export MONGO_PASSWORD="your_password"
export MONGO_URI="mongodb+srv://${MONGO_USERNAME}:${MONGO_PASSWORD}@cluster-hostname/"
```

### Use in commands
```bash
mongodump --uri="$MONGO_URI"
```

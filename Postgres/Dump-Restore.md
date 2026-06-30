# Postgres Dump & Restore Guide

This guide covers taking a dump of a PostgreSQL database and restoring it to a new database.

## Required Tools

The **PostgreSQL client** utilities are required: `pg_dump`, `pg_restore`, and `psql`. The full PostgreSQL server does not need to be installed, only the client package.

### Installation by Platform

- **Ubuntu/Debian**:
```bash
sudo apt update && sudo apt install postgresql-client
```

- **Ubuntu/Debian (specific version)**:
```bash
sudo apt install postgresql-client-16
```

- **Amazon Linux / RHEL / CentOS**:
```bash
sudo yum install postgresql16
```
- **macOS (Homebrew)**:
```bash
brew install libpq && brew link --force libpq
```

### Verifying Installation

```bash
pg_dump --version
pg_restore --version
psql --version
```

### Version Matching

`pg_dump` and `pg_restore` should match the major version of the new cluster, or be newer. An older client version can fail or behave unreliably against a newer server, particularly with newer data types or catalog changes.

Check the new engine version with:
```sql
SELECT version();
```

### Network & Connectivity
Network access is required from the machine running these commands to both the source and target endpoints (`port 5432`)

## Taking the Dump

For a single database
```bash
# Backup Step
pg_dump -h "<SOURCE_HOST>" \
        -U "<SOURCE_USERNAME>" \
        -d "<SOURCE_DB_NAME>" \
        -F c \
        -b \
        -v \
        -f "/home/fahad/pg_backup_restore/fort_stage_db.dump"
```

#### Useful Flags

- `-F c`: sets the output format to custom (compressed binary format). This is the format that supports parallel restore with `pg_restore -j` and selective restore of individual tables/objects, unlike plain SQL.
- `-b`: include large objects (BLOBs) in the dump. Without this flag in custom/tar/directory format, large objects are actually included by default.
- `-v`: verbose mode. Prints progress messages to stderr as the dump runs, useful for watching progress on a large database or for logging.
- `-f "/home/fahad/pg_backup_restore/fort_stage_db.dump"`: the output file path where the dump gets written.

## Restoring the Dump

Create the target database first if it doesn't already exist:

```bash
# Create Database in new cluster
psql -h "<DESTINATION_HOST>" \
     -p 5432 \
     -U "<DESTINATION_USERNAME>" \
     -d "postgres" \
     -c "CREATE DATABASE <DB_NAME>;"
```

Restore Database
```bash
# Restore Step
pg_restore -h "<DESTINATION_HOST>" \
           -U "<DESTINATION_USERNAME>" \
           -d "<DESTINATION_DB_NAME>" \
           -j 2 \
           -v \
           "/home/fahad/pg_backup_restore/fort_stage_db.dump"
```

The `-j` flag parallelizes the restore across multiple jobs, set this based on the number of CPU cores available on the target instance.
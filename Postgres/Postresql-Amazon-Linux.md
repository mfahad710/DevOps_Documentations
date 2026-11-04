# PostgreSQL 16 on Amazon Linux EC2

## Overview

This guide sets up self-hosted **PostgreSQL 16.15** server on an **Amazon Linux 2023** EC2 instance, reachable only from inside the VPC. It covers installation, the required changes to `postgresql.conf` and `pg_hba.conf`, roles, networking, backups and a hardening checklist.

## Install PostgreSQL 16

Install the server, client and contrib modules

``` bash
sudo dnf install -y postgresql16 postgresql16-server postgresql16-contrib
```

The default data dir is **/var/lib/pgsql/data**

Initialize the cluster and start the service

``` bash
sudo postgresql-setup --initdb
sudo systemctl enable --now postgresql
systemctl status postgresql
```

Check Postgresql version

``` bash
psql --version
```

Confirm the paths

``` bash
sudo -u postgres psql -c "SHOW data_directory;" -c "SHOW config_file;" -c "SHOW hba_file;"
```

## Configure postgresql.conf

The file at **/var/lib/pgsql/data/postgresql.conf** is mostly defaults after **initdb**.

The most important change is **memory**: the default **shared_buffers = 128MB** is far too small for an 8 GiB host. The values below are sized for a **t4g.large;** scale memory settings if you use another size.

Back up first, then edit existing lines in place instead of adding duplicates (the last duplicate wins, which makes the file confusing).

``` bash
sudo cp /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/data/postgresql.conf.bak
sudo vi /var/lib/pgsql/data/postgresql.conf
```

**Connections and authentication**

``` ini
listen_addresses = '*' # or the private IP only, e.g. 'localhost,10.0.1.25'
port = 5432
max_connections = 100 # 200 is possible, but 2 vCPUs rarely benefit; use PgBouncer for more
password_encryption = scram-sha-256
```

If listen_addresses is commented out, PostgreSQL listens on localhost only and remote clients are refused. Changing it requires a restart.

**Memory (8 GiB RAM)**

``` ini
shared_buffers = 2GB # ~25% of RAM
effective_cache_size = 6GB # ~75% of RAM, a planner hint only
work_mem = 8MB # per sort/hash node per connection, keep modest
maintenance_work_mem = 512MB # vacuum and index builds
```

**Logging**

``` ini
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%a.log'
log_min_duration_statement = 1000 # log queries slower than 1s
log_line_prefix = '%m [%p] %u@%d %h '
log_connections = on
log_disconnections = on
log_checkpoints = on
log_lock_waits = on
log_temp_files = 0
log_autovacuum_min_duration = 1000
```

Apply and verify

``` bash
sudo systemctl restart postgresql
sudo -u postgres psql -c "SHOW shared_buffers;" -c "SHOW max_connections;"
sudo -u postgres psql -c "SELECT name, setting FROM pg_settings WHERE pending_restart;"
```

An empty result from the last query means no setting is waiting for a restart.

## Configure pg_hba.conf

**pg_hba.conf** decides who may connect, from where, to which database, and how they authenticate. PostgreSQL reads it top to bottom and uses the first matching line, so order matters.

The default file from **initdb** allows only local connections and uses ident over TCP, which normally fails for password logins. **listen_addresses = '\*'** alone does not open remote access: a matching host rule is also required.

Back up the file.

``` bash
sudo cp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.bak
sudo vi /var/lib/pgsql/data/pg_hba.conf
```

``` text
# TYPE DATABASE USER ADDRESS METHOD

# Local socket: postgres via OS identity, others via password
local all postgres peer
local all all scram-sha-256
# Localhost TCP
host all all 127.0.0.1/32 scram-sha-256
host all all ::1/128 scram-sha-256

# VPC CIDR
host all all 10.20.0.0/16 scram-sha-256

# Replication (local only, for pg_basebackup)
local replication all peer
host replication all 127.0.0.1/32 scram-sha-256
host replication all ::1/128 scram-sha-256
```

**Validate and apply**

Changes to this file need a reload, not a restart.

``` sql
# empty result = no parse errors
sudo -u postgres psql -c "SELECT line_number, error FROM pg_hba_file_rules WHERE error IS NOT NULL;"
sudo -u postgres psql -c "SELECT pg_reload_conf();"
```

To see the active rules in evaluation order:

``` bash
sudo -u postgres psql -c "SELECT line_number, type, database, user_name, address, auth_method FROM pg_hba_file_rules;"
```

## Create Databases and Roles

Create one role and one database per application, and keep the **postgres** superuser for administration only. Open a local superuser session:

``` bash
sudo -u postgres psql
```

Set the postgres password

``` sql
ALTER USER postgres WITH PASSWORD 'postgres';
```

Create Databases

``` sql
CREATE DATABASE "dev_db";

CREATE DATABASE "stg_db";
```

### Master User

Create Master User

``` sql
-- dev Master User
CREATE ROLE "dev-master" WITH LOGIN CREATEDB CREATEROLE SUPERUSER REPLICATION BYPASSRLS PASSWORD 'strong_password';

-- stg Master User
CREATE ROLE "stg-master" WITH LOGIN CREATEDB CREATEROLE SUPERUSER REPLICATION BYPASSRLS PASSWORD 'strong_password';
-- Check role creation
SELECT rolname, rolcanlogin
FROM pg_roles
WHERE rolname IN (
'dev-master',
'stg-master'
);
```

Change Database Ownership

``` sql
ALTER DATABASE "dev_db" OWNER TO "dev-master";

ALTER DATABASE "stg_db" OWNER TO "stg-master";
```

Master User Permissions

``` sql
-- CONNECT TO dev_db database FIRST

-- Grant DB connection
GRANT CONNECT ON DATABASE "dev_db" TO "dev-master";

-- public schema
GRANT USAGE ON SCHEMA public TO "dev-master";

-- dev-master: full DML on existing tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "dev-master";
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO "dev-master";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO "dev-master";
-- Future tables in public
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "dev-master";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO "dev-master";
-- Verify
-- Check table-level grants
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('dev-master')
ORDER BY grantee, table_schema, table_name;
```

The above **dev-master** is for dev, repeat the same process for **stg-master** user

### apiuser

Create apiuser

``` sql
-- dev apiuser
CREATE ROLE "dev-apiuser" WITH LOGIN PASSWORD 'strong_password';

-- stg apiuser
CREATE ROLE "stg-apiuser" WITH LOGIN PASSWORD 'strong_password';
-- Check role creation
SELECT rolname, rolcanlogin
FROM pg_roles
WHERE rolname IN (
'dev-apiuser',
'stg-apiuser'
);
```

apiuser Permissions

``` sql
-- CONNECT TO dev_db database FIRST

-- Grant DB connection
GRANT CONNECT ON DATABASE "dev_db" TO "dev-apiuser";

-- Public schema
GRANT USAGE ON SCHEMA public TO "dev-apiuser";

-- dev-api: full DML on existing tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "dev-apiuser";
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO "dev-apiuser";
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO "dev-apiuser";
-- Future tables in public
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "dev-apiuser";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO "dev-apiuser";
-- Verify
-- Check table-level grants
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('dev-apiuser')
ORDER BY grantee, table_schema, table_name;
```

The above **dev-apiuser** is for dev, repeat the same process for **stg-apiuser.**

### Read Only User

Create dev-readonly

``` sql
-- dev-readonly
CREATE ROLE "dev-readonly" NOLOGIN;

-- stg-readonly
CREATE ROLE "stg-readonly" NOLOGIN;
-- Check role creation
SELECT rolname, rolcanlogin
FROM pg_roles
WHERE rolname IN (
'dev-readonly',
'stg-readonly'
);
```

dev-readonly Permissions

``` sql
-- CONNECT TO dev_db database FIRST

-- Grant DB connection
GRANT CONNECT ON DATABASE "dev_db" TO "dev-readonly";

-- Public schema
GRANT USAGE ON SCHEMA public TO "dev-readonly";

-- dev-readonly: read only on existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "dev-readonly";
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "dev-readonly";

-- Future tables in public
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT SELECT ON TABLES TO "dev-readonly";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
GRANT USAGE, SELECT ON SEQUENCES TO "dev-readonly";

-- Verify
-- Check table-level grants
SELECT grantee, table_schema, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('dev-readonly')
ORDER BY grantee, table_schema, table_name;
```

The above **dev-readonly** is for dev, repeat the same process for **stg-readonly.**

## PgBouncer

PgBouncer is a lightweight **connection pooler** that sits between your applications and PostgreSQL. Apps connect to PgBouncer (port **6432**), and it keeps a small, reusable set of real connections open to PostgreSQL (port **5432**).

This matters because every PostgreSQL connection is a separate backend process. On a **t4g.large** (2 vCPU, 8 GiB) with max_connections = 100, a few apps each opening many connections can exhaust the limit, and hundreds of mostly idle connections waste memory. PgBouncer lets thousands of client connections share a few dozen server connections.

| **Pool Mode** | **Server connection is held** | **Use it for**                        |
|---------------|-------------------------------|---------------------------------------|
| session       | For the whole client session  | Apps that rely on session state       |
| transaction   | Only during a transaction     | Most web apps (best pooling)          |
| statement     | Per statement                 | Rare, no multi-statement transactions |

### Step 01: Installation

Check **AL2023** repos package have **PgBouncer** or not:

``` bash
sudo dnf makecache
dnf list pgbouncer
```

If **AL2023** repos package show **PgBouncer** then installed it:

``` bash
sudo dnf install -y pgbouncer
```

If **AL2023** repos package doesn’t have **PgBouncer**

``` bash
sudo dnf install -y gcc make pkgconf-pkg-config libevent-devel openssl-devel systemd-devel tar gzip

VER=1.26.1 # or newer
cd /tmp
curl -LO https://www.pgbouncer.org/downloads/files/$VER/pgbouncer-$VER.tar.gz
# compare against the sha256 published on the release page
sha256sum pgbouncer-$VER.tar.gz

tar xf pgbouncer-$VER.tar.gz && cd pgbouncer-$VER
./configure --prefix=/usr/local --with-systemd
make -j"$(nproc)"
sudo make install
pgbouncer --version
```

### Step 02: User, Directories and Permissions

If you installed **pgbouncer** through **dnf install** command then you don’t need to create the **pgbouncer** user and **/etc/pgbouncer** directory because distro or PGDG-style RPM, the package normally handles most of this setup for you.

``` bash
# Create user if don't exist
sudo useradd -r -M -s /sbin/nologin pgbouncer
# create config directory
sudo mkdir -p /etc/pgbouncer
# change ownership of config directory
sudo chown -R pgbouncer:pgbouncer /etc/pgbouncer

# Create runtime directories if they don't exist
sudo mkdir -p /var/log/pgbouncer /var/run/pgbouncer
sudo chown -R pgbouncer:pgbouncer /var/log/pgbouncer /var/run/pgbouncer
```

### Step 03: Configure pgbouncer.ini

``` bash
sudo nano /etc/pgbouncer/pgbouncer.ini
```

Paste the following baseline setup:

``` text
[databases]
# Format: local_alias = host=YOUR_DB_HOST port=5432 dbname=YOUR_DB_NAME
dev_db = host=127.0.0.1 port=5432 dbname=dev_db
stg_db = host=127.0.0.1 port=5432 dbname=stg_db

[pgbouncer]
# Network Settings
listen_addr = 0.0.0.0
listen_port = 6432
unix_socket_dir = /run/pgbouncer

# Administrative Access
stats_users = monitoring_user
admin_users = postgres

# Authentication Settings
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt

# Pooling Mode Optimization
# Modes: 'transaction' (highly recommended for web apps/lambdas), 'session', or 'statement'
pool_mode = session

# Connection Limits
max_client_conn = 500
default_pool_size = 10
min_pool_size = 10
reserve_pool_size = 5
reserve_pool_timeout = 5
max_db_connections = 15
max_prepared_statements = 200
server_idle_timeout = 600
server_lifetime = 3600
ignore_startup_parameters = extra_float_digits

# Logging and Process tracking
logfile = /var/log/pgbouncer/pgbouncer.log
pidfile = /var/run/pgbouncer/pgbouncer.pid
```

Change Permissions

``` bash
sudo chown pgbouncer:pgbouncer /etc/pgbouncer/pgbouncer.ini
sudo chmod 640 /etc/pgbouncer/pgbouncer.ini
```

### Step 04: Configure User Authentication

PgBouncer manages incoming client authentication using a lookup file called userlist.txt. To protect your system, utilize scram-sha-256 or md5 hashes instead of plaintext passwords.

Connect directly to your target PostgreSQL database via psql to extract the existing encrypted password string:

``` sql
SELECT usename, passwd FROM pg_shadow WHERE usename = 'your_app_user';
```

Open the user list file:

``` bash
sudo nano /etc/pgbouncer/userlist.txt
```

Insert your database users along with their corresponding passwords or hashes inside quotes:

``` text
"dev-master" "SCRAM-SHA-256$4096:salt$StoredKey:ServerKey"
"stg-master" "SCRAM-SHA-256$4096:salt$StoredKey:ServerKey"
"dev-apiuser" "SCRAM-SHA-256$4096:salt$StoredKey:ServerKey"
"stg-apiuser" "SCRAM-SHA-256$4096:salt$StoredKey:ServerKey"
"dev-readonly" "SCRAM-SHA-256$4096:salt$StoredKey:ServerKey"
"stg-readonly" "SCRAM-SHA-256$4096:salt$StoredKey:ServerKey"
```

Change Permissions

``` bash
sudo chown pgbouncer:pgbouncer /etc/pgbouncer/userlist.txt
sudo chmod 640 /etc/pgbouncer/userlist.txt
```

### Step 05: Systemd service

Create Service file

``` bash
sudo nano /etc/systemd/system/pgbouncer.service
```

Add the following:

``` text
[Unit]
Description=PgBouncer connection pooler for PostgreSQL
Documentation=https://www.pgbouncer.org/
After=network-online.target postgresql.service
Wants=network-online.target

[Service]
Type=notify
User=pgbouncer
Group=pgbouncer

# Creates /run/pgbouncer and /var/log/pgbouncer with the right owner on every start
RuntimeDirectory=pgbouncer
LogsDirectory=pgbouncer

ExecStart=/usr/local/bin/pgbouncer /etc/pgbouncer/pgbouncer.ini
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
LimitNOFILE=65536
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Load and start it

``` bash
sudo systemctl daemon-reload
sudo systemctl enable --now pgbouncer
sudo systemctl status pgbouncer
```
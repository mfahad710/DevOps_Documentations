# Call Procedure

## Overview

This document explains how to run a PostgreSQL stored procedure on a schedule using the `pg_cron` extension, and how to set it up on both our self-hosted PostgreSQL servers and AWS RDS Aurora PostgreSQL.

The procedure `public.purge_pod_card_vault` was created. This guide covers the remaining part: calling that procedure automatically every day.

## Background: PROCEDURE and CALL

In PostgreSQL, a PROCEDURE is a database object that stores SQL statements to perform a task, while CALL is the command used to execute that procedure.

A procedure is a reusable block of SQL code. Instead of writing the same SQL statements repeatedly, you create a procedure once and execute it whenever needed.

### Creating Procedure

For example, suppose you have an employees table and want to insert a new employee.

```sql
CREATE PROCEDURE add_employee(
    p_name VARCHAR(100),
    p_salary NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO employees(name, salary)
    VALUES (p_name, p_salary);
END;
$$;
```

**Explanation**

- `CREATE PROCEDURE`: creates a new procedure.
- `add_employee`: the procedure name.
- `p_name`, `p_salary`: input parameters.
- `LANGUAGE plpgsql`: specifies the procedural SQL language.
- `BEGIN ... END`: contains the SQL statements to execute.

This creates the procedure but does not execute it.

### Running a procedure with CALL

The **CALL** command executes a procedure that you have already created.

For example:
```sql
CALL add_employee('Fahad', 50000);
```

This executes the `add_employee` procedure and inserts the following data into the employees table.

You can call it again with different values:
```sql
CALL add_employee('Ali', 60000);
CALL add_employee('Ahmed', 70000);
```

Each call inserts another employee.

## Implementation

### In Self-Hosted postgres

ssh into the self hosted ec2 instance,

Connect to database
```bash
psql -h localhost -p 5432 -U <username> -d <database-name>
```

Check PostgreSQL version
```sql
SHOW server_version;     -- e.g. 16.4, so the major version is 16
SHOW config_file;        -- location of postgresql.conf
exit
```

Install `pg_cron` on the server
```bash
# Ubuntu / Debian
sudo apt install postgresql-16-cron

# RHEL / CentOS / Rocky (from the PGDG repo)
sudo dnf install pg_cron_16
```

Install `pg_cron` on the **Amazon Linux 2023** server
```bash
sudo dnf install -y gcc make git
sudo dnf install -y postgresql16-server-devel


cd /tmp
git clone https://github.com/citusdata/pg_cron.git
cd pg_cron

make PG_CONFIG=/usr/bin/pg_config
sudo make PG_CONFIG=/usr/bin/pg_config install
ls -l /usr/share/pgsql/extension/pg_cron*
```

Enable it in `postgresql.conf`

In Ubuntu
```bash
nano /etc/postgresql/16/main/postgresql.conf
```

In Amazon Linux 2023
```bash
nano /var/lib/pgsql/data/postgresql.conf
```

Add the following
```bash
shared_preload_libraries = 'pg_cron'
cron.database_name = 'dev_db'
cron.timezone = 'Asia/Karachi'
cron.use_background_workers = on
max_worker_processes = 20
```

If `shared_preload_libraries` already has a value, append to it instead, for example `'pg_stat_statements,pg_cron'`

Then restart PostgreSQL
```bash
sudo systemctl restart postgresql
```

Create the **extension** and **schedule** the job

Connect to the database as a superuser and run:
```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.schedule(
    'purge_pod_card_vault',
    '0 2 * * *',                              -- every day at 02:00
    $$CALL public.purge_pod_card_vault(2, 1000, 10000, 0)$$);
```

If we want to create in specific database:
```bash
-- Create job in dev_db using dev-user
SELECT cron.schedule_in_database(
    'purge_pod_card_vault',
    '0 2 * * *',
    $$CALL neem.purge_pod_card_vault(2, 1000, 10000, 0)$$,
    'dev_db',
    'dev-user'
);


-- Craete job in stg_db using stg-user
SELECT cron.schedule_in_database(
    'purge_pod_card_vault',
    '0 2 * * *',
    $$CALL neem.purge_pod_card_vault(2, 1000, 10000, 0)$$,
    'stg_db',
    'stg-user'
)
```

Verify
```sql
-- Confirm the job exists
SELECT jobid, jobname, schedule, command, active FROM cron.job;

-- After 2 AM, check the result
SELECT start_time, end_time, status, return_message
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 5;
```

`status = 'succeeded'` means the run worked. If it says failed, `return_message` shows the error.

Things that commonly go wrong

- The job never runs: `pg_cron` connects through localhost by default, so `pg_hba.conf` must allow that connection. The simpler fix is to add `cron.use_background_workers = on` to `postgresql.conf` and restart.
- It runs at the wrong time: older `pg_cron` versions ignore `cron.timezone` and always use **GMT**. If `SHOW cron.timezone;` gives an error, use `'0 21 * * *'` instead, which is 2 AM PKT.

### In AWS RDS Aurora

Setting up `pg_cron` on AWS RDS Aurora PostgreSQL

#### Step 1: Prerequisites

- Aurora PostgreSQL engine version that supports `pg_cron` (11.x and newer on current versions). Verify with:
```sql
SELECT version();
```
- A custom parameter group attached to your cluster and instances. You can’t edit the default groups.
- A user with `rds_superuser` (your master user has it).

#### Step 2: Configure the parameter group

Edit the parameters in the DB cluster parameter group (Aurora). Check whether the instance-level parameter group also sets `shared_preload_libraries`, because an instance-level value overrides the cluster value.


| Parameter | Value | Type |
| -------- | -------- | -------- |
|shared_preload_libraries  | existing values + pg_cron | Static (reboot)  |
| cron.database_name  | the database that will hold the extension | Static (reboot)  |
| cron.use_background_workers  | on | Static (reboot)  |
| max_worker_processes  | Must be higher than the number of concurrent cron jobs , (e.g 20) | Static (reboot)  |

Keep existing entries. For example: `pg_stat_statements,pg_cron`

CLI equivalent:
```bash
aws rds modify-db-cluster-parameter-group \
  --db-cluster-parameter-group-name dev-db \
  --parameters "ParameterName=shared_preload_libraries,ParameterValue='pg_stat_statements,pg_cron',ApplyMethod=pending-reboot" \
               "ParameterName=cron.database_name,ParameterValue=dev_db,ApplyMethod=pending-reboot" \
               "ParameterName=cron.use_background_workers,ParameterValue=on,ApplyMethod=pending-reboot" \
               "ParameterName=max_worker_processes,ParameterValue=20,ApplyMethod=pending-reboot"

```

Optional parameters (dynamic, no reboot):

- `cron.max_running_jobs (default 5): how many jobs can run at once.
- `cron.log_run` and `cron.log_statement`: log job execution to the PostgreSQL log (and CloudWatch if log export is enabled).

#### Step 3: Reboot

- Confirm the instance shows pending-reboot.
- Reboot the writer instance (pg_cron only runs jobs on the writer).
- Important for failover: if the parameter is set at the instance level rather than the cluster level, apply and reboot it on every instance that could become writer. Otherwise, after a failover the new writer won’t run your jobs.

Expect a short outage on the writer. Do this in a maintenance window.

#### Step 4: Create the extension

Connect to the database you set in `cron.database_name`:
```sql
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

Check:
```sql
SELECT * FROM pg_extension WHERE extname = 'pg_cron';
SHOW shared_preload_libraries;
SHOW cron.database_name;
```

If you see `pg_cron` can only be loaded via `shared_preload_libraries`, the reboot didn’t pick up the parameter. If you see can only create extension in database X, you’re connected to the wrong database.

#### Step 5: Schedule the job

Aurora schedules are in **UTC**. 02:00 PKT (UTC+5) is 21:00 UTC of the previous day, so use 0 21 * * *
```sql
SELECT cron.schedule(
    'purge_pod_card_vault',
    '0 21 * * *',                -- every day at 21:00 UTC = 02:00 AM PKT
    $$CALL public.purge_pod_card_vault(2, 1000, 10000, 0)$$);
```

Time zone: schedules are in UTC. For example, 02:00 in Pakistan time (UTC+5) is 0 21 * * *.

Running against a different database

#### Step 6: Permissions

By default only `rds_superuser` can use `pg_cron`. To let another user schedule jobs:
```sql
GRANT USAGE ON SCHEMA cron TO app_admin;
```

Jobs run as the user who scheduled them, so that user needs EXECUTE on the procedure:
```sql
GRANT EXECUTE ON PROCEDURE my_schema.my_proc() TO app_admin;
```

#### Step 7: Monitor
```sql
-- all jobs
SELECT jobid, jobname, schedule, command, active FROM cron.job;

-- recent runs and errors
SELECT jobid, status, return_message, start_time, end_time
FROM cron.job_run_details
ORDER BY start_time DESC
LIMIT 20;
```

#### Step 8: Maintenance

Pause or remove a job:
```sql
-- pause job
SELECT cron.alter_job(jobid, active := false) FROM cron.job WHERE jobname = 'purge_pod_card_vault';

-- remove job
SELECT cron.unschedule('purge_pod_card_vault');
```

Cleanup History

Clean up the history table. `cron.job_run_details` grows forever, so schedule a cleanup job:
```sql
SELECT cron.schedule(
  'purge-cron-history',
  '0 12 * * *',
  $$DELETE FROM cron.job_run_details WHERE end_time < now() - interval '7 days'$$
);
```

# Useful commands

```sql
-- list procedures
\df my_schema.*            -- in psql (shows functions and procedures)

--list procedures
SELECT proname FROM pg_proc WHERE prokind = 'p';

-- permissions
GRANT EXECUTE ON PROCEDURE my_schema.add_employee(VARCHAR, NUMERIC) TO 'some_user';

-- drop
DROP PROCEDURE my_schema.add_employee(VARCHAR, NUMERIC);

-- List job
SELECT jobid, jobname, schedule, command, active FROM cron.job;


-- add job 
SELECT cron.schedule(
    'purge_pod_card_vault',
    '0 2 * * *',                              -- every day at 02:00
    $$CALL public.purge_pod_card_vault(2, 1000, 10000, 0)$$);

-- remove a job
SELECT cron.unschedule('purge_pod_vault');

-- run in a different database than cron.database_name
SELECT cron.schedule_in_database(
    'purge_pod_vault',
    '0 2 * * *',
    $$CALL public.purge_pod_card_vault(2, 1000, 10000, 0)$$,
    'dev_db');
```
# User Creation & Assigning Permissions


## Create Read-Write User

```sql
-- Create the login role
CREATE USER rw_user WITH PASSWORD 'strong_password_here';

-- Allow it to connect to the target database
GRANT CONNECT ON DATABASE fort_stage_db TO rw_user;

-- Make fort schema default for rw_user
ALTER ROLE rw_user SET search_path TO fort;

-- Allow usage on the schema
GRANT USAGE ON SCHEMA fort TO rw_user;

-- Grant DML on existing tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA fort TO rw_user;

-- Grant usage on sequences (needed for SERIAL/IDENTITY columns)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA fort TO rw_user;

-- Execute (call/invoke) every function that currently exists in schema
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA fort TO rw_user;

-- Make sure future tables/sequences inherit the same grants
ALTER DEFAULT PRIVILEGES IN SCHEMA fort GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO rw_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA fort GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO rw_user;
```


## Create Read-Only User

```sql
-- Create the login role
CREATE USER ro_user WITH PASSWORD 'strong_password_here';

-- Allow it to connect to the target database
GRANT CONNECT ON DATABASE fort_stage_db TO ro_user;

-- Make fort schema default for ro_user
ALTER ROLE ro_user SET search_path TO fort;

-- Allow usage on the schema
GRANT USAGE ON SCHEMA fort TO ro_user;

-- read only permission on existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA fort TO ro_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA fort TO ro_user;

-- Make sure future tables/sequences inherit the same grants
ALTER DEFAULT PRIVILEGES IN SCHEMA fort GRANT SELECT ON TABLES TO ro_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA fort GRANT USAGE, SELECT ON SEQUENCES TO ro_user;
```


## Verifying

```sql
\du                                  -- list roles and their memberships
\l                                   -- list databases
SELECT * FROM information_schema.role_table_grants WHERE grantee = 'ro_user';
```

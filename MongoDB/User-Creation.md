# User Creation

## Creating Users in MongoDB using the Mongo Shell

MongoDB provides role-based access control (RBAC) to manage users and their privileges. To create a user in MongoDB, you must connect to the `admin` database and use the `db.createUser()` method.

### Step 1: Connect to Mongo Shell
```bash
mongosh
```
or 

```bash
mongosh -u <USERNAME> -p <PASSWORD>
```

### Step 2: Switch to the `admin` Database
```javascript
use admin
```

### Step 3: Create a User
```javascript
db.createUser({
  user: "fortadmin",
  pwd: "password123",
  roles: [ { role: "root", db: "admin" } ]
})
```

> This user will have **root access** and can perform any action across all databases.

- **user**: The username of the MongoDB user.
- **pwd**: The password for the user.
- **roles**: An array of role assignments.

## Common MongoDB Roles and Their Purposes

MongoDB has predefined roles that can be assigned to users based on their responsibilities.

### Database User Roles
- **read** → Provides read-only access to a specific database.
- **readWrite** → Provides read and write access to a specific database.

### Database Administration Roles
- **dbAdmin** → Provides administrative tasks such as creating indexes, viewing stats, and modifying schemas (but no user management).
- **dbOwner** → Provides full control over a single database (read, write, and admin tasks).
- **userAdmin** → Provides ability to create, modify, and remove users in a database.

### Cluster Administration Roles
- **clusterAdmin** → Provides full control over cluster management and monitoring.
- **clusterManager** → Provides management of cluster-related operations (start/stop/reconfig).
- **clusterMonitor** → Provides read-only access to monitoring tools like `serverStatus` and `currentOp`.
- **hostManager** → Provides ability to manage servers in a cluster (restart, shutdown).

### Backup and Restore Roles
- **backup** → Allows backing up data (e.g., `mongodump`).
- **restore** → Allows restoring data (e.g., `mongorestore`).

### Superuser Roles
- **root** → Provides full control of the database and cluster. Equivalent to system administrator.

## Verification
List all users in the current database:
```javascript
show users
```

List all roles in the current database:
```javascript
show roles
```

# WordPress + MySQL Deployment using Docker Compose

This documentation explains how to deploy a WordPress application with a MySQL database using Docker Compose.

The setup includes:

- WordPress container (Web Application)
- MySQL container (Database)
- Persistent Docker volume for database storage
- Internal Docker networking between services

## Docker Compose File

```yaml
version: '3.7'

services:
  db:
    image: mysql:5.7
    volumes:
      - db_data:/var/lib/mysql
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: <MYSQL_PASSWORD>
      MYSQL_DATABASE: <MYSQL_DB_NAME>
      MYSQL_USER: <MYSQL_USERNAME>
      MYSQL_PASSWORD: <MYSQL_PASSWORD>
 
  wordpress:
    depends_on:
      - db
    image: wordpress:latest
    ports:
      - "8080:80"
    restart: always
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: <MYSQL_USERNAME>
      WORDPRESS_DB_PASSWORD: <MYSQL_PASSWORD>
      WORDPRESS_DB_NAME: <MYSQL_DB_NAME>
volumes:
  db_data:
```

## Service Configuration Details

### MySQL Service (db)
- Image Used: `mysql:5.7`
- Purpose: Stores WordPress data (posts, users, settings, etc.)
- Port: Internal `3306`
- Data Persistence: `/var/lib/mysql` mapped to Docker volume `db_data`

### WordPress Service
- Image Used: `wordpress:latest`
- Internal Port: `80`
- Exposed Port: `8080`

### Volume Configuration
- Stores MySQL data persistently
- Prevents data loss if containers are recreated
- Managed automatically by Docker

### Networking Behavior

Docker Compose automatically creates a private bridge network, Assigns DNS names based on service names and Allows inter-container communication.

WordPress connects to database using:
```bash
db:3306
```

## Deployment Instructions

**Start Containers**
```bash
docker compose up -d
```

OR

```bash
docker compose up -d --build
```

`--build` forces Docker Compose to build images before starting containers.

**Access WordPress**
```bash
http://localhost:8080
```

**Stopping the Application**
```bash
docker compose down
```

**Stop and remove volumes**
```bash
docker compose down -v
```
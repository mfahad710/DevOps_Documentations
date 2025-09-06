# Docker Compose

Docker Compose is a tool for defining and running multi-container applications. It is the key to unlocking a streamlined and efficient development and deployment experience.

Compose simplifies the control of your entire application stack, making it easy to manage services, networks, and volumes in a single YAML configuration file. Then, with a single command, you create and start all the services from your configuration file.

Compose works in all environments - production, staging, development, testing, as well as CI workflows. It also has commands for managing the whole lifecycle of your application:

- Start, stop, and rebuild services
- View the status of running services
- Stream the log output of running services
- Run a one-off command on a service

## Basic Concepts

### Compose File Structure
Docker Compose uses a YAML file (typically `docker-compose.yml`) to configure application services.

### Key Components:

- **Services**: Individual containers that make up your application
- **Networks**: Communication between containers
- **Volumes**: Persistent data storage

### Basic Commands

**Starting Services**
```bash
# Start all services in detached mode
docker-compose up -d

# Start specific services
docker-compose up -d service1 service2

# Build images before starting
docker-compose up --build
```

**Stopping Services**
```bash
# Stop running containers
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Stop without removing containers
docker-compose stop
```

**Managing Services**
```bash
# View running services
docker-compose ps

# View logs
docker-compose logs
docker-compose logs -f  # Follow logs
docker-compose logs service_name

# Execute command in running container
docker-compose exec service_name command

# Restart services
docker-compose restart
docker-compose restart service_name
```

### Compose File Reference
Version Specification
```yaml
version: '3.8'  # Recommended to use latest version
```

### Services Definition
```yaml
services:
  web:
    image: nginx:latest
    container_name: my-nginx
    ports:
      - "80:80"
    environment:
      - NGINX_HOST=localhost
      - NGINX_PORT=80
    volumes:
      - ./html:/usr/share/nginx/html
    networks:
      - app-network
    depends_on:
      - app

  app:
    build: .
    container_name: my-app
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
    networks:
      - app-network
    depends_on:
      - db

  db:
    image: postgres:13
    container_name: my-db
    environment:
      POSTGRES_DB: mydb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - app-network
```

**docker-compose.yml file Example that I used**

```yaml
services:
  organization:
    image: fort-backend:latest
    container_name: fort.backend
    working_dir: /app
    command: yarn start:debug
    restart: always
    ports:
        - hostPort:3001
    volumes:
      - ./:/app
    environment:
      OPENSSL_CONF: /app/openssl.cnf
```

### Networks Configuration
```yaml
networks:
  app-network:
    driver: bridge
    # Additional network options
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Volumes Configuration
```yaml
volumes:
  db_data:
    driver: local
    # Volume options
    driver_opts:
      type: none
      o: bind
      device: ./data
```
### Common Configuration Options

#### Build Options
```yaml
services:
  app:
    build:
      context: .  # Path to build context
      dockerfile: Dockerfile.dev  # Custom Dockerfile
      args:  # Build arguments
        - NODE_ENV=production
      target: builder  # Multi-stage build target
```

#### Port Mapping
```yaml
ports:
  - "80:80"           # Host:Container
  - "3000:3000"
  - "443:443"
  - "8080:80"         # Different host port
  - "9000-9010:9000-9010"  # Port range
```

#### Environment Variables
```yaml
environment:
  - VAR1=value1
  - VAR2=value2

# or using dictionary format
environment:
  VAR1: value1
  VAR2: value2

# or using env file
env_file:
  - .env
  - .env.production
```

#### Volume Mounts
```yaml
volumes:
  # Named volume
  - db_data:/var/lib/data
  
  # Host path
  - ./app:/app
  
  # Read-only volume
  - ./config:/etc/config:ro
  
  # Anonymous volume
  - /tmp
```

#### Health Checks
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

#### Resource Limits
```yaml
deploy:
  resources:
    limits:
      cpus: '0.50'
      memory: 512M
    reservations:
      cpus: '0.25'
      memory: 256M
```

## Best Practices

- Use specific version tags instead of latest
- Define restart policies for production
- Use environment variables for configuration
- Separate concerns with multiple services
- Use named volumes for persistent data
- Implement health checks for service dependencies
- Use `.dockerignore` to exclude unnecessary files
- Specify resource limits in production

## Troubleshooting

### Common Issues
```bash
# Check service status
docker-compose ps

# View logs for debugging
docker-compose logs

# Force rebuild
docker-compose build --no-cache

# Remove all containers and start fresh
docker-compose down && docker-compose up

# Check container networking
docker-compose exec service_name ping other_service
```

### Debug Commands
```bash
# Inspect container details
docker-compose inspect service_name

# View container processes
docker-compose top

# Check container IP addresses
docker-compose exec service_name ip addr

# Test service connectivity
docker-compose exec service_name curl http://other_service:port
```

# Containers Project

A collection of containerized services managed with Podman, designed for local development and testing.

## Project Overview

This project contains multiple self-contained services, each with its own `docker-compose.yml` or `podman-compose.yml` configuration. Services can be managed individually or collectively using the provided management scripts.

## Services

| Service | Description | Port | Access |
|---------|-------------|------|--------|
| **Portainer** | Container management UI | 24000 | http://localhost:24000 |
| **MariaDB** | MariaDB 10.11 database server | 24001 | localhost:24001 |
| **Adminer** | Database management tool (supports MariaDB & MySQL) | 24002 | http://localhost:24002 |
| **phpMyAdmin** | MySQL/MariaDB admin (supports both databases) | 24003 | http://localhost:24003 |
| **MySQL** | MySQL 8.0 database server | 24004 | localhost:24004 |
| **LAMP Stack** | Apache + PHP + MySQL + phpMyAdmin | 5050, 5051 | http://localhost:5050 |
| **Docmost** | Documentation platform with PostgreSQL + Redis | 5601 | http://localhost:5601 |

## Project Structure

```
Containers/
├── .env                          # Central environment variables
├── containers.sh                 # Main container management script
├── containers-multi.sh           # Multi-select container manager
├── mariadb/
│   ├── docker-compose.yml        # MariaDB configuration
│   └── mariadb_data/             # Database volume (persistent)
├── phpmyadmin/
│   ├── docker-compose.yml        # phpMyAdmin (supports MariaDB & MySQL)
│   └── phpmyadmin_data/          # Session data (persistent)
├── adminer/
│   ├── docker-compose.yml        # Adminer (supports MariaDB & MySQL)
│   └── adminer_data/             # Uploaded files (persistent)
├── mysql/
│   ├── docker-compose.yml        # MySQL 8.0 configuration
│   ├── README.md                 # MySQL documentation
│   └── mysql_data/               # Database volume (persistent)
├── portainer/
│   ├── docker-compose.yml        # Portainer configuration
│   └── portainer_data/           # Portainer data (persistent)
├── lamp/
│   ├── podman-compose.yml        # LAMP stack configuration
│   ├── mysql/                    # MySQL data volume (persistent)
│   └── www/                      # Apache document root
└── docmost/
    ├── podman-compose.yml        # Docmost with PostgreSQL + Redis
    ├── docmost-db/               # PostgreSQL data (persistent)
    └── docmost-redis/            # Redis data (persistent)
```

## Management Scripts

### containers.sh (Primary Script)
Full-featured container manager with status monitoring and access links.

**Usage:**
```bash
./containers.sh
```

**Features:**
- Real-time status display (UP/DOWN)
- Start/stop/restart projects with multi-selection
- View logs from any container
- Display access links for running services
- Automatic server IP detection

**Multi-selection patterns:**
- Individual: `1 3 5`
- Range: `1-3`
- All: `all`

### containers-multi.sh (Alternative)
Simplified multi-select manager for quick operations.

**Usage:**
```bash
./containers-multi.sh
```

## Environment Configuration

All environment variables are centralized in [`.env`](.env):

```bash
# MariaDB Configuration
MARIADB_ROOT_PASSWORD=Rx8#kL2@mN5$pQ9&vW4!zX6
MARIADB_DATABASE=production_db
MARIADB_USER=db_admin
MARIADB_PASSWORD=Hy7@jP3#rT8&wY5+nK2!sM4
MARIADB_PORT=24001
MARIADB_HOST=mariadb
MARIADB_INTERNAL_PORT=3306

# phpMyAdmin Configuration
PMA_PORT=24003
PMA_UPLOAD_LIMIT=256M

# Adminer Configuration
ADMINER_PORT=24002
```

**Important:** Never commit `.env` to version control (already in `.gitignore`).

## Network Architecture

Database services use a shared external network:

```yaml
networks:
  db_stack:
    external: true
```

**To create the network:**
```bash
podman network create db_stack
```

Services that connect:
- MariaDB (database server)
- phpMyAdmin (database management)
- Adminer (database management)

## Quick Start

### 1. Create the shared network (first time only)
```bash
podman network create db_stack
```

### 2. Start all services
```bash
./containers.sh
# Select option 2 (Start projects)
# Enter: all
```

### 3. Start specific services
```bash
# Using the script
./containers.sh
# Select option 2
# Enter service numbers (e.g., 1 3 5)

# Or manually
cd mariadb && podman-compose up -d
cd ../adminer && podman-compose up -d
cd ../phpmyadmin && podman-compose up -d
```

### 4. Access services
- **Portainer**: http://localhost:24000
- **MariaDB**: localhost:24001
- **Adminer** (for both MariaDB & MySQL): http://localhost:24002
- **phpMyAdmin** (for both MariaDB & MySQL): http://localhost:24003
- **MySQL**: localhost:24004
- **LAMP**: http://localhost:5050
- **phpMyAdmin (LAMP)**: http://localhost:5051
- **Docmost**: http://localhost:5601

### Using Adminer with Multiple Databases

Adminer supports connecting to both MariaDB and MySQL:

1. Open http://localhost:24002
2. For **MariaDB**:
   - System: MySQL
   - Server: `mariadb`
   - Username: `db_admin` (or `root`)
   - Password: See MariaDB credentials below
   - Database: `production_db` (optional)

3. For **MySQL**:
   - System: MySQL
   - Server: `mysql`
   - Username: `db_user` (or `root`)
   - Password: See MySQL credentials below
   - Database: `dev_db` (optional)

### Using phpMyAdmin with Multiple Databases

phpMyAdmin supports connecting to both MariaDB and MySQL:

1. Open http://localhost:24003
2. Click "New server" or use the server tab
3. For **MariaDB**:
   - Server: `mariadb`
   - Port: `3306`
   - Username: `db_admin` (or `root`)
   - Password: See MariaDB credentials below

4. For **MySQL**:
   - Server: `mysql`
   - Port: `3306`
   - Username: `db_user` (or `root`)
   - Password: See MySQL credentials below

## Individual Service Management

### MariaDB
```bash
cd mariadb
podman-compose up -d        # Start
podman-compose down         # Stop
podman-compose logs -f      # View logs
```

### Adminer
```bash
cd adminer
podman-compose up -d
podman-compose down
```

### phpMyAdmin
```bash
cd phpmyadmin
podman-compose up -d
podman-compose down
```

### Portainer
```bash
cd portainer
podman-compose up -d
podman-compose down
```

### LAMP Stack
```bash
cd lamp
podman-compose up -d
podman-compose down
```

**Access LAMP:**
- Web server: http://localhost:5050
- phpMyAdmin: http://localhost:5051
- MySQL: localhost:3306

### MySQL (with Adminer & phpMyAdmin)
```bash
cd mysql
podman-compose up -d
podman-compose down
```

**Access:**
- MySQL: localhost:3306
- phpMyAdmin: http://localhost:8080
- Adminer: http://localhost:8081

### Docmost
```bash
cd docmost
podman-compose up -d
podman-compose down
```

**Note:** First time setup requires file permissions:
```bash
sudo chmod -R 777 /home/abdulwahab/Containers/docmost/
```

### MySQL (Database Server)
```bash
cd mysql
podman-compose up -d        # Start
podman-compose down         # Stop
podman-compose logs -f      # View logs
```

**Access:** localhost:24004

**Note:** Use the shared Adminer (http://localhost:24002) or phpMyAdmin (http://localhost:24003) to manage this MySQL database.

## Data Persistence

All services use named volumes or bind mounts for persistent data:

| Service | Volume Location | Purpose |
|---------|----------------|---------|
| MariaDB | `mariadb/mariadb_data/` | Database files |
| phpMyAdmin (MariaDB) | `phpmyadmin/phpmyadmin_data/` | Session data |
| Adminer (MariaDB) | `adminer/adminer_data/` | Uploads |
| MySQL | `mysql/mysql_data/` | Database files |
| MySQL phpMyAdmin | `mysql-phpmyadmin/mysql_phpmyadmin_data/` | Session data |
| MySQL Adminer | `mysql-adminer/mysql_adminer_data/` | Uploads |
| Portainer | `portainer/portainer_data/` | Application data |
| LAMP MySQL | `lamp/mysql/` | Database files |
| LAMP Apache | `/home/abdulwahab/Containers/lamp/www` | Web files |
| Docmost DB | `docmost/docmost-db/` | PostgreSQL data |
| Docmost Redis | `docmost/docmost-redis/` | Redis data |

**Important:** All data directories are excluded from git via [`.gitignore`](.gitignore).

## Database Credentials

### MariaDB (standalone)
- **Root:** `root` / `Rx8#kL2@mN5$pQ9&vW4!zX6`
- **User:** `db_admin` / `Hy7@jP3#rT8&wY5+nK2!sM4`
- **Database:** `production_db`
- **Host:** `localhost:24001`

### MySQL (standalone with Adminer/phpMyAdmin)
- **Root:** `root` / `Rk7@mP2#nX4&qW9!vY5+zL3`
- **User:** `db_user` / `Jw6@pL8#rT3&sV4!nK2+mH9`
- **Database:** `dev_db`
- **Host:** `localhost:24004`

### Docmost PostgreSQL
- **User:** `docmost` / `yourStrongDbPassword`
- **Database:** `docmost`

## Troubleshooting

### Services can't connect to database
**Solution:** Ensure the `db_stack` network exists:
```bash
podman network ls | grep db_stack
# If not found:
podman network create db_stack
```

### Permission denied errors
**Solution:** Fix file permissions:
```bash
sudo chmod -R 777 /home/abdulwahab/Containers/
```

### Port already in use
**Solution:** Check what's using the port:
```bash
podman ps                    # Check running containers
sudo lsof -i :24001          # Check specific port
```

### Container won't start
**Solution:** Check logs:
```bash
podman logs <container-name>
# Or use the script:
./containers.sh
# Select option 5 (View logs)
```

### Service not accessible from browser
**Solution:**
1. Verify container is running: `podman ps`
2. Check port mapping: `podman port <container-name>`
3. Try accessing with server IP instead of localhost
4. Check firewall settings

## Conventions

### File Naming
- `docker-compose.yml` - Standard Docker Compose files
- `podman-compose.yml` - Podman-specific configurations (LAMP, MySQL, Docmost)

### Directory Structure
- Each service has its own directory
- Service name = directory name
- Persistent data stored in `*_data/` subdirectory

### Environment Variables
- All secrets in `.env` file
- Use `${VARIABLE_NAME}` syntax in compose files
- Provide defaults: `${VARIABLE:-default_value}`

### Network Names
- Use `db_stack` for database-related services
- Keep networks external for cross-service communication

### Volume Labels
- Use `:Z` flag for SELinux compatibility: `./data:/var/lib/mysql:Z`

## Development Workflow

### Adding a New Service

1. **Create directory:**
   ```bash
   mkdir new-service
   cd new-service
   ```

2. **Create compose file:**
   ```bash
   # docker-compose.yml or podman-compose.yml
   version: "3.8"
   services:
     app:
       image: your-image
       restart: unless-stopped
       ports:
         - "PORT:INTERNAL_PORT"
   ```

3. **Add to .env (if needed):**
   ```bash
   SERVICE_VAR=value
   ```

4. **Test:**
   ```bash
   podman-compose up -d
   ```

5. **Manage with script:**
   ```bash
   # Service will be auto-detected by containers.sh
   ./containers.sh
   ```

### Updating Services

1. **Pull latest images:**
   ```bash
   cd service-dir
   podman-compose pull
   podman-compose up -d
   ```

2. **Rebuild custom images:**
   ```bash
   podman-compose build
   podman-compose up -d
   ```

## Backup & Restore

### Backup Database
```bash
# MariaDB
podman exec mariadb-server mysqldump -u root -p"Rx8#kL2@mN5$pQ9&vW4!zX6" production_db > backup.sql

# LAMP MySQL
podman exec lamp-mysql mysqldump -u root -p"root" testdb > backup.sql
```

### Restore Database
```bash
# MariaDB
podman exec -i mariadb-server mysql -u root -p"Rx8#kL2@mN5$pQ9&vW4!zX6" production_db < backup.sql

# LAMP MySQL
podman exec -i lamp-mysql mysql -u root -p"root" testdb < backup.sql
```

### Backup Volumes
```bash
# Entire project
sudo tar -czf containers-backup-$(date +%Y%m%d).tar.gz \
  /home/abdulwahab/Desktop/Containers/ \
  --exclude='*.log' \
  --exclude='.git'
```

## Security Notes

1. **Default Credentials:** Change all default passwords in production
2. **Port Exposure:** All services currently bind to 0.0.0.0 (accessible from network)
3. **Environment File:** Never commit `.env` to version control
4. **SELinux:** Using `:Z` flag for volume mounting (relabels volumes)
5. **Root Access:** Some services run as root (consider using user namespaces)

## System Requirements

- **OS:** Linux (tested on Manjaro/Arch)
- **Container Runtime:** Podman (rootless or rootful)
- **RAM:** 4GB minimum (8GB recommended for all services)
- **Disk:** 10GB free space for databases and volumes

## Required Tools

- `podman` - Container runtime
- `podman-compose` - Multi-container orchestration
- `bash` - Script execution

**Install on Arch/Manjaro:**
```bash
sudo pacman -S podman podman-compose
```

## License

This is a personal development project. Use at your own risk.

## Contributing

This is a personal project for local development. Feel free to fork and adapt for your needs.

---

**Last Updated:** April 2026
**Maintainer:** Abdul Wahab

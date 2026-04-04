# Containers Workspace

A collection of containerized services managed with Podman for local development and testing.

## Overview

This project contains multiple self-contained services, each in its own directory with dedicated compose files. Services can be managed individually or collectively using the provided management scripts.

## Services

| Service | Description | Port | Documentation |
|---------|-------------|------|---------------|
| **Portainer** | Container management UI | 24000 | - |
| **MariaDB** | MariaDB 10.11 database | 24001 | [README](mariadb/README.md) |
| **Adminer** | Database management tool | 24002 | - |
| **phpMyAdmin** | MySQL/MariaDB admin | 24003 | - |
| **PostgreSQL** | PostgreSQL 16 database | 24005 | [README](postgresql/README.md) |
| **pgAdmin** | PostgreSQL web interface | 24006 | - |
| **CloudBeaver** | Multi-database management | 24007 | [README](cloudbeaver/README.md) |
| **Docmost** | Documentation platform | 5601 | - |
| **Apache** | PHP web server | 5050 | - |

## Quick Start

### Prerequisites

- **OS:** Linux (tested on Manjaro/Arch)
- **Runtime:** Podman (rootless or rootful)
- **Tools:** `podman`, `podman-compose`

Install on Arch/Manjaro:
```bash
sudo pacman -S podman podman-compose
```

### Initial Setup

1. **Create shared database network:**
   ```bash
   podman network create db_stack
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your credentials
   ```

3. **Start all services:**
   ```bash
   ./containers.sh
   # Select option 2 (Start projects)
   # Enter: all
   ```

### Start Individual Service

```bash
cd <service>
podman-compose up -d
```

Example:
```bash
cd mariadb
podman-compose up -d
```

## Management Scripts

### containers.sh (Primary)

Full-featured container manager with status monitoring.

**Usage:**
```bash
./containers.sh
```

**Features:**
- Real-time status display (UP/DOWN)
- Start/stop/restart services
- View logs from any container
- Display access links for running services
- Multi-selection support (e.g., `1 3 5`, `1-3`, `all`)

### containers-multi.sh (Alternative)

Simplified multi-select manager for quick operations.

**Usage:**
```bash
./containers-multi.sh
```

## Access URLs

### Management Interfaces
- **Portainer:** http://localhost:24000
- **Adminer:** http://localhost:24002
- **phpMyAdmin:** http://localhost:24003
- **pgAdmin:** http://localhost:24006
- **CloudBeaver:** http://localhost:24007

### Database Services
- **MariaDB:** localhost:24001
- **PostgreSQL:** localhost:24005

### Applications
- **Docmost:** http://localhost:5601
- **Apache:** http://localhost:5050

## Network Architecture

Database services use a shared external network `db_stack` for inter-service communication.

**Create network:**
```bash
podman network create db_stack
```

**Connected services:**
- MariaDB (database server)
- PostgreSQL (database server)
- Adminer (database management)
- phpMyAdmin (MySQL/MariaDB management)
- pgAdmin (PostgreSQL management)
- CloudBeaver (multi-database management)

## Data Persistence

All services use named volumes or bind mounts for persistent data:

| Service | Volume Location | Purpose |
|---------|----------------|---------|
| MariaDB | `mariadb/mariadb_data/` | Database files |
| MariaDB | `mariadb/backups/` | Backup files |
| PostgreSQL | `postgresql/postgresql_data/` | Database files |
| PostgreSQL | `postgresql/backups/` | Backup files |
| phpMyAdmin | `phpmyadmin/phpmyadmin_data/` | Session data |
| Adminer | `adminer/adminer_data/` | Uploads |
| pgAdmin | `pgadmin/pgadmin_data/` | Configuration |
| CloudBeaver | `cloudbeaver/cloudbeaver_data/` | Workspace |
| Portainer | `portainer/portainer_data/` | Application data |
| Apache | `apache/html/` | Web files |

**Important:** All data directories are excluded from git via [`.gitignore`](.gitignore).

## Database Tools Comparison

| Feature | CloudBeaver | Adminer | phpMyAdmin | pgAdmin |
|---------|-------------|---------|------------|---------|
| MariaDB | ✅ | ✅ | ✅ | ❌ |
| PostgreSQL | ✅ | ✅ | ❌ | ✅ |
| MySQL | ✅ | ✅ | ✅ | ❌ |
| Modern UI | ✅ | Basic | Basic | ✅ |
| SQL Editor | ✅ | ✅ | ✅ | ✅ |
| Multi-DB | ✅ | ✅ | ❌ | ❌ |

## Common Operations

### Start Services
```bash
# All services
./containers.sh

# Specific service
cd mariadb && podman-compose up -d
```

### Stop Services
```bash
# All services
./containers.sh
# Select option 3 (Stop projects)

# Specific service
cd mariadb && podman-compose down
```

### View Logs
```bash
cd <service>
podman-compose logs -f
```

### Restart Service
```bash
cd <service>
podman-compose restart
```

## Backup & Restore

### MariaDB
```bash
# Backup
podman exec mariadb-server mysqldump -u root -p production_db > backup.sql

# Restore
podman exec -i mariadb-server mysql -u root -p production_db < backup.sql
```

### PostgreSQL
```bash
# Backup
podman exec postgresql-server pg_dump -U postgres_user analytics_db > backup.sql

# Restore
podman exec -i postgresql-server psql -U postgres_user analytics_db < backup.sql
```

## Troubleshooting

### Services can't connect to database
**Solution:** Ensure the `db_stack` network exists:
```bash
podman network ls | grep db_stack
# If not found:
podman network create db_stack
```

### Port already in use
**Solution:** Check what's using the port:
```bash
podman ps
sudo lsof -i :24001
```

### Container won't start
**Solution:** Check logs:
```bash
podman logs <container-name>
cd <service> && podman-compose logs -f
```

### Permission denied errors
**Solution:** Fix file permissions:
```bash
sudo chmod -R 777 /home/abdulwahab/Desktop/Containers/<service>/
```

## Project Structure

```
Containers/
├── .env                          # Environment variables (not in git)
├── .env.example                  # Environment template
├── .gitignore                    # Git ignore rules
├── CLAUDE.md                     # Project instructions
├── README.md                     # This file
├── containers.sh                 # Main management script
├── containers-multi.sh           # Alternative manager
├── mariadb/
│   ├── docker-compose.yml
│   └── mariadb_data/
├── adminer/
│   ├── docker-compose.yml
│   └── adminer_data/
├── phpmyadmin/
│   ├── docker-compose.yml
│   └── phpmyadmin_data/
├── postgresql/
│   ├── docker-compose.yml
│   ├── README.md
│   └── postgresql_data/
├── pgadmin/
│   ├── docker-compose.yml
│   └── pgadmin_data/
├── cloudbeaver/
│   ├── docker-compose.yml
│   ├── README.md
│   └── cloudbeaver_data/
├── portainer/
│   ├── docker-compose.yml
│   └── portainer_data/
├── apache/
│   ├── podman-compose.yml
│   └── html/
└── docmost/
    ├── podman-compose.yml
    └── docmost-db/
```

## Conventions

### File Naming
- `docker-compose.yml` - Standard Docker Compose files
- `podman-compose.yml` - Podman-specific configurations

### Directory Structure
- One service per directory
- Service name = directory name
- Persistent data in `*_data/` subdirectory

### Environment Variables
- All secrets in `.env` file
- Use `${VARIABLE_NAME}` syntax in compose files
- Provide defaults: `${VARIABLE:-default_value}`

### Image Format
- Use full image paths: `docker.io/image:tag`
- Example: `docker.io/library/mariadb:10.11`

## Development Workflow

### Adding a New Service

1. **Create directory:**
   ```bash
   mkdir new-service
   cd new-service
   ```

2. **Create compose file:**
   ```yaml
   version: "3.8"
   services:
     app:
       image: docker.io/image:tag
       restart: unless-stopped
       ports:
         - "PORT:INTERNAL_PORT"
       volumes:
         - ./data:/app/data:Z
       networks:
         - db_stack
   ```

3. **Add to .gitignore:**
   ```
   new-service/data/
   ```

4. **Test:**
   ```bash
   podman-compose up -d
   ```

### Updating Services

1. **Pull latest images:**
   ```bash
   cd service-dir
   podman-compose pull
   podman-compose up -d
   ```

2. **Rebuild if needed:**
   ```bash
   podman-compose build
   podman-compose up -d
   ```

## Security Notes

1. **Default Credentials:** Change all default passwords in production
2. **Port Exposure:** All services currently bind to 0.0.0.0 (network accessible)
3. **Environment File:** Never commit `.env` to version control
4. **SELinux:** Using `:Z` flag for volume mounting
5. **Root Access:** Some services run as root (consider user namespaces)

## System Requirements

- **OS:** Linux (Manjaro/Arch tested)
- **Container Runtime:** Podman (rootless or rootful)
- **RAM:** 4GB minimum (8GB recommended for all services)
- **Disk:** 10GB free space for databases and volumes

## Contributing

This is a personal development project. Feel free to fork and adapt for your needs.

## License

This is a personal project for local development. Use at your own risk.

---

**Last Updated:** April 2026  
**Maintainer:** Abdul Wahab  
**Container Runtime:** Podman

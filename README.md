# Containers Workspace

Containerized services managed with Podman.

## Services

| Service | Port | Description |
|---------|------|-------------|
| Portainer | 24000 | Container management UI |
| MariaDB | 24001 | MariaDB 10.11 database |
| Adminer | 24002 | Database management tool |
| phpMyAdmin | 24003 | MySQL/MariaDB admin |
| PostgreSQL | 24005 | PostgreSQL 16 database |
| pgAdmin | 24006 | PostgreSQL web interface |
| CloudBeaver | 24007 | Multi-database management |
| Docmost | 5601 | Documentation platform |
| Apache | 5050 | PHP web server |

## Quick Start

```bash
# Create shared network
podman network create db_stack

# Configure environment
cp .env.example .env
# Edit .env with your credentials

# Start all services
./containers.sh
```

## Common Commands

```bash
# Start specific service
cd <service> && podman-compose up -d

# Stop specific service
cd <service> && podman-compose down

# View logs
cd <service> && podman-compose logs -f
```

## Access URLs

- **Portainer:** http://localhost:24000
- **Adminer:** http://localhost:24002
- **phpMyAdmin:** http://localhost:24003
- **pgAdmin:** http://localhost:24006
- **CloudBeaver:** http://localhost:24007
- **Docmost:** http://localhost:5601
- **Apache:** http://localhost:5050

## Database Connections

**MariaDB:**
- Host: `mariadb` or `localhost:24001`
- Database: `production_db`
- User: `db_admin` (see .env for password)

**PostgreSQL:**
- Host: `postgresql` or `localhost:24005`
- Database: `analytics_db`
- User: `postgres_user` (see .env for password)

## Project Structure

```
Containers/
├── .env.example          # Environment template
├── containers.sh         # Management script
├── mariadb/              # MariaDB service
├── adminer/              # Database manager
├── phpmyadmin/           # MySQL/MariaDB admin
├── postgresql/           # PostgreSQL service
├── pgadmin/              # PostgreSQL admin
├── cloudbeaver/          # Multi-database manager
├── portainer/            # Container manager
├── docmost/              # Documentation platform
└── apache/               # Web server
```

## Troubleshooting

**Network not found:**
```bash
podman network create db_stack
```

**Port already in use:**
```bash
podman ps
sudo lsof -i :<port>
```

**View container logs:**
```bash
podman logs <container-name>
```

## System Requirements

- **OS:** Linux (Manjaro/Arch)
- **Runtime:** Podman + podman-compose
- **RAM:** 4GB minimum
- **Disk:** 10GB free space

---

**Last Updated:** April 2026

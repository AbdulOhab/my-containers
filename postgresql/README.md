# PostgreSQL Database Server

PostgreSQL 16 database server with persistent data storage.

## Access

- **Host:** localhost:24005
- **Network IP:** 192.168.255.115:24005
- **Internal:** postgresql:5432
- **Database:** analytics_db

## Credentials

- **Configured user:** postgres_user / [See .env file]
- **Database:** analytics_db

## How to Connect

### 1. Using pgAdmin (Web Interface)

**Access:** http://192.168.255.115:24006/

**Setup Connection:**
1. Login to pgAdmin:
   - Email: `admin@example.com`
   - Password: `Pg7@hJ2#mN4&wR8!tY6+vL1`

2. Add New Server:
   - **Name:** PostgreSQL (or any name)
   - **Host:** `192.168.255.115` ← Use IP address
   - **Port:** `24005`
   - **Maintenance database:** `analytics_db`
   - **Username:** `postgres_user`
   - **Password:** [See .env file]

3. Save and connect

### 2. Using psql (Command Line)

**From host machine:**
```bash
podman exec -it postgresql-server psql -U postgres_user -d analytics_db
```

**With password:**
```bash
podman exec -it postgresql-server psql -U postgres_user -d analytics_db -W
```

**Connect as superuser:**
```bash
podman exec -it postgresql-server psql -U postgres -d postgres
```

### 3. Using Adminer

**Access:** http://192.168.255.115:24002/

**Login:**
- **System:** PostgreSQL
- **Server:** `192.168.255.115:24005` (or `postgresql:5432` from container)
- **Username:** `postgres_user`
- **Password:** [See .env file]
- **Database:** `analytics_db` (optional)

### 4. Using DBeaver (Desktop Application)

1. Create New Connection → PostgreSQL
2. Connection settings:
   - **Host:** `192.168.255.115`
   - **Port:** `24005`
   - **Database:** `analytics_db`
   - **Username:** `postgres_user`
   - **Password:** [See .env file]

### 5. Using TablePlus (Desktop Application)

1. New Connection → PostgreSQL
2. Connection settings:
   - **Name:** PostgreSQL
   - **Host:** `192.168.255.115`
   - **Port:** `24005`
   - **User:** `postgres_user`
   - **Password:** [See .env file]
   - **Database:** `analytics_db`

## Data Persistence

Database files are stored in `postgresql_data/` (excluded from git).

## Backup & Restore

```bash
# Backup database
podman exec postgresql-server pg_dump -U postgres_user analytics_db > backup.sql

# Restore database
podman exec -i postgresql-server psql -U postgres_user analytics_db < backup.sql

# Backup all databases
podman exec postgresql-server pg_dumpall -U postgres > full_backup.sql
```

## Health Check

```bash
# Check if PostgreSQL is ready
podman exec postgresql-server pg_isready -U postgres_user
```

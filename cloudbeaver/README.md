# CloudBeaver Community Edition

CloudBeaver is an open-source web-based database management tool. It provides a modern UI for managing multiple database types including MariaDB, PostgreSQL, MySQL, and more.

## Access

- **Web Interface:** http://localhost:24007
- **Network IP:** http://192.168.255.115:24007

## Features

- **Multi-database support:** MariaDB, PostgreSQL, MySQL, SQLite, and more
- **Modern web interface:** Works in any modern browser
- **Data editing:** View and edit database records
- **SQL execution:** Run SQL queries directly
- **User management:** Multiple users with secure authentication
- **Project workspace:** Save connections and queries

## Quick Start

### Start the service
```bash
cd cloudbeaver
podman-compose up -d
```

### Stop the service
```bash
podman-compose down
```

### View logs
```bash
podman-compose logs -f
```

## Configuration

### Environment Variables
- `CLOUDBEAVER_PORT`: Port mapping (default: 24007:8978)

### Volumes
- **Workspace:** `./cloudbeaver_data` - Persistent configuration and user data

### Network
- Connected to `db_stack` network for easy database access

## Connecting to Databases

### MariaDB
- **Driver:** MariaDB
- **Host:** `mariadb` (container name) or `192.168.255.115:24001` (host access)
- **Port:** 3306 (internal)
- **Database:** `production_db`
- **Username:** `db_admin` or `root`
- **Password:** See .env file

### PostgreSQL
- **Driver:** PostgreSQL
- **Host:** `postgresql` (container name) or `192.168.255.115:24005` (host access)
- **Port:** 5432 (internal)
- **Database:** `analytics_db`
- **Username:** `postgres_user`
- **Password:** See .env file

### MySQL (if available)
- **Host:** `mysql` or IP address
- **Port:** 3306
- **Credentials:** See your MySQL configuration

## First Time Setup

1. **Access the web interface:** http://localhost:24007

2. **Create admin user:**
   - First access will prompt to create an admin account
   - Choose a secure username and password

3. **Create a connection:**
   - Click "New Connection"
   - Select driver (e.g., MariaDB, PostgreSQL)
   - Enter connection details (see above)
   - Test connection
   - Save connection

4. **Start working:**
   - Browse database schema
   - Run SQL queries
   - Edit data directly
   - Export results

## Common Operations

### Create New Connection
1. Click "Create New Connection" button
2. Select database driver
3. Configure connection parameters:
   - Host: Use container name (e.g., `mariadb`) for network access
   - Port: Internal port (e.g., 3306 for MariaDB)
   - Database: Your database name
   - Authentication: Username and password
4. Click "Test Connection" to verify
5. Click "Create" to save

### Run SQL Query
1. Open connection
2. Click "SQL Editor" or press `Ctrl+E`
3. Enter SQL query
4. Click "Execute" or press `Ctrl+Enter`

### Export Data
1. Right-click on table or query result
2. Select "Export"
3. Choose format (CSV, SQL, JSON, Excel)
4. Configure export options
5. Click "Export"

## Backup & Restore

### Backup Workspace
Workspace contains connections, saved queries, and user settings:

```bash
# Backup workspace
podman exec cloudbeaver-server tar czf /tmp/workspace-backup.tar.gz /opt/cloudbeaver/workspace
podman cp cloudbeaver-server:/tmp/workspace-backup.tar.gz ./workspace-backup.tar.gz

# Restore workspace
podman cp ./workspace-backup.tar.gz cloudbeaver-server:/tmp/workspace-backup.tar.gz
podman exec cloudbeaver-server tar xzf /tmp/workspace-backup.tar.gz -C /
```

### Backup Database Data
Use the database's native backup tools (see respective database README files):
- [MariaDB README](../mariadb/README.md)
- [PostgreSQL README](../postgresql/README.md)

## Troubleshooting

### Container won't start
```bash
# Check logs
podman logs cloudbeaver-server

# Verify volume permissions
ls -la cloudbeaver_data/
```

### Cannot connect to database
1. Verify database container is running: `podman ps`
2. Check network connectivity: Both on `db_stack` network
3. Verify connection credentials
4. Check database logs for errors

### High memory usage
CloudBeaver is Java-based and may require more memory:
- Limit JVM heap size in environment variable: `CB_SERVER_JVM_OPTS=-Xmx2g`
- Add to docker-compose.yml under `environment:` section

### Performance issues
- Reduce number of simultaneous connections
- Limit result set size in preferences
- Use database indexes for better query performance

## Data Persistence

All configuration, connections, and user data are stored in `./cloudbeaver_data/`. This directory is excluded from git via `.gitignore`.

## Security Notes

1. **Default credentials:** Create a strong admin password on first setup
2. **Network exposure:** Currently accessible from network (port 24007)
3. **HTTPS:** Consider setting up reverse proxy with HTTPS for production
4. **Backup:** Regularly backup workspace directory

## Comparison with Other Tools

| Feature | CloudBeaver | Adminer | phpMyAdmin | pgAdmin |
|---------|-------------|---------|------------|---------|
| Multiple DB types | ✅ | ✅ | ❌ | ❌ |
| Modern UI | ✅ | Basic | Basic | Modern |
| SQL Editor | ✅ | ✅ | ✅ | ✅ |
| Data Editing | ✅ | ✅ | ✅ | ✅ |
| User Management | ✅ | ❌ | ❌ | ✅ |
| Export Options | ✅ | Basic | Basic | Advanced |

## Official Documentation

- [CloudBeaver Documentation](https://dbeaver.com/docs/cloudbeaver/)
- [Docker Image](https://hub.docker.com/r/dbeaver/cloudbeaver)
- [GitHub Repository](https://github.com/dbeaver/cloudbeaver)

## System Requirements

- **Memory:** 512MB minimum, 2GB recommended
- **Disk:** 100MB for application, additional for workspace
- **Network:** Access to `db_stack` network for database connectivity

## License

CloudBeaver Community Edition is licensed under Apache License 2.0.

---

**Last Updated:** April 2026
**Maintainer:** Abdul Wahab

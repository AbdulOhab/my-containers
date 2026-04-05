# Docmost use podman-compose.yml
version: '3.8'

services:
  docmost:
    image: docker.io/docmost/docmost:latest
    depends_on:
      - db
      - redis
    environment:
      APP_URL: 'http://localhost:5601'
      APP_SECRET: '183c780126bef85897b3d6e05c4e1271485dc92b4178aa360b2c420f1670855b'
      DATABASE_URL: 'postgresql://docmost:yourStrongDbPassword@db:5432/docmost?schema=public'
      REDIS_URL: 'redis://redis:6379'
      MULTI_SPACE: 'true'
    ports:
      - '5601:3000'
    restart: unless-stopped
    volumes:
      - /home/abdulwahab/Containers/docmost/:/app/data/storage:Z

  db:
    image: docker.io/library/postgres:16-alpine
    environment:
      POSTGRES_DB: docmost
      POSTGRES_USER: docmost
      POSTGRES_PASSWORD: yourStrongDbPassword
    restart: unless-stopped
    volumes:
      - /home/abdulwahab/Containers/docmost/docmost-db:/var/lib/postgresql/data:Z

  redis:
    image: docker.io/library/redis:7.2-alpine
    restart: unless-stopped
    volumes:
      - /home/abdulwahab/Containers/docmost/docmost-redis:/data:Z

# file permission
# sudo chmod -R 777 /home/abdulwahab/Containers/docmost/

# file permission
# sudo chmod -R 777 /home/abdulwahab/Containers/docmost/
# APP_SECRET: '183c780126bef85897b3d6e05c4e1271485dc92b4178aa360b2c420f1670855b'
# APP_SECRET: 'REPLACE_WITH_LONG_SECRET'
# DATABASE_URL: 'postgresql://docmost:yourStrongDbPassword@db:5432/docmost?schema=public'
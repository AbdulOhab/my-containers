# Containers Workspace

Keep this repo simple: one service per folder, managed with Podman.

## What is here

- mariadb/
- adminer/
- phpmyadmin/
- portainer/
- postgresql/
- pgadmin/
- docmost/
- apache/

## Quick rules

- Read the relevant compose file before editing.
- Make the smallest useful change.
- Do not invent services, ports, or paths.
- Keep secrets in .env, not in markdown.
- After edits, verify the file for errors if possible.

## Common actions

- Check all services: ./containers.sh
- Multi-start / multi-stop: ./containers-multi.sh
- Start one service: cd <service> && podman-compose up -d
- Stop one service: cd <service> && podman-compose down
- View logs: cd <service> && podman-compose logs -f

## Ports

- Portainer: 24000
- MariaDB: 24001
- Adminer: 24002
- phpMyAdmin: 24003
- PostgreSQL: 24005
- pgAdmin: 24006
- Docmost: 5601
- Apache: 5050

## Shared database network

Some database tools use the external network db_stack.

Create it once if needed:

podman network create db_stack

## Editing workflow

1. Inspect the target service folder.
2. Edit only what is needed.
3. Keep compose files readable.
4. If a change affects env vars or ports, mention it clearly.

## When the user asks for help

- If the task is unclear, ask the minimum question needed.
- If the task is obvious, do it directly.
- If the user asks for a "simple" or "clean" version, prefer short output.
- If the user asks to manage containers, use the compose files and scripts in this repo.

## Current project notes

- MariaDB, Adminer, phpMyAdmin, PostgreSQL, and pgAdmin are separate services.
- Docmost uses its own bundled db and redis services.
- Apache serves files from its local volume.

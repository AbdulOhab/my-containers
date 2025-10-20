#!/bin/bash

podman run -d \
  -p 7899:9000 \
  --name portainer \
  --restart=always \
  -v /run/user/1000/podman/podman.sock:/var/run/docker.sock:Z \
  -v portainer_data:/data \
  docker.io/portainer/portainer-ce:latest

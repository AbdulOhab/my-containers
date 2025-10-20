#!/bin/bash
# Interactive Podman Compose Controller
BASE_DIR="/home/abdulwahab/Containers"

# Function to show running containers with ports and links
show_running_containers() {
  echo "=============================="
  echo "🚀 Running Containers:"
  echo "=============================="
  
  running_containers=$(podman ps --format "{{.Names}}\t{{.Ports}}\t{{.Status}}")
  
  if [[ -z "$running_containers" ]]; then
    echo "⚠️  No containers running!"
  else
    while IFS=$'\t' read -r name ports status; do
      echo "📦 $name"
      echo "   Status: $status"
      
      if [[ -n "$ports" ]]; then
        echo "   Ports: $ports"
        # Extract host ports and create links
        echo "$ports" | grep -oE '0\.0\.0\.0:([0-9]+)' | cut -d: -f2 | while read -r port; do
          echo "   🔗 http://localhost:$port"
        done
      else
        echo "   No exposed ports"
      fi
      echo
    done <<< "$running_containers"
  fi
  
  echo "=============================="
  echo
}

# Function to list all container projects
list_projects() {
  find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
}

# Show running containers first
show_running_containers

# Get all project names
PROJECTS=($(list_projects))

# Show menu
echo "=============================="
echo "📦 Available Containers:"
echo "=============================="
i=1
for project in "${PROJECTS[@]}"; do
  echo "  $i) $project"
  ((i++))
done
echo "=============================="
echo "0) Exit"
echo

# Ask user to choose one
read -rp "➡️  Select a project number: " choice

if [[ "$choice" == "0" ]]; then
  echo "❎ Exiting..."
  exit 0
fi

if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#PROJECTS[@]})); then
  echo "❌ Invalid selection!"
  exit 1
fi

SELECTED_PROJECT="${PROJECTS[$((choice-1))]}"
PROJECT_PATH="$BASE_DIR/$SELECTED_PROJECT"

echo
echo "✅ Selected Project: $SELECTED_PROJECT"
echo

# Ask what to do
echo "What do you want to do?"
echo "  1) Start (up)"
echo "  2) Stop (down)"
echo "  3) Restart"
echo "  4) Status"
echo "  5) Show Ports & Links"
echo "  0) Exit"
read -rp "➡️  Choose an action: " action

case "$action" in
  1)
    echo "🚀 Starting $SELECTED_PROJECT..."
    cd "$PROJECT_PATH" && podman-compose up -d
    ;;
  2)
    echo "🛑 Stopping $SELECTED_PROJECT..."
    cd "$PROJECT_PATH" && podman-compose down
    ;;
  3)
    echo "🔄 Restarting $SELECTED_PROJECT..."
    cd "$PROJECT_PATH" && podman-compose down && podman-compose up -d
    ;;
  4)
    echo "📋 Status for $SELECTED_PROJECT:"
    podman ps --filter "label=io.podman.compose.project=$SELECTED_PROJECT"
    ;;
  5)
    echo "🌐 Ports & Links for $SELECTED_PROJECT:"
    echo "=============================="
    podman ps --filter "label=io.podman.compose.project=$SELECTED_PROJECT" --format "table {{.Names}}\t{{.Ports}}\t{{.Status}}" | while IFS= read -r line; do
      echo "$line"
      if [[ "$line" =~ 0.0.0.0:([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
        echo "   🔗 http://localhost:$port"
      fi
    done
    echo "=============================="
    echo
    echo "🔍 Detailed Port Mappings:"
    podman ps --filter "label=io.podman.compose.project=$SELECTED_PROJECT" --format "{{.Names}}: {{.Ports}}" | while IFS=: read -r name ports; do
      if [[ -n "$ports" ]]; then
        echo "📦 $name"
        echo "$ports" | grep -oE '0\.0\.0\.0:[0-9]+->([0-9]+)/(tcp|udp)' | while read -r mapping; do
          host_port=$(echo "$mapping" | grep -oE '0\.0\.0\.0:([0-9]+)' | cut -d: -f2)
          container_port=$(echo "$mapping" | grep -oE '->([0-9]+)' | cut -d'>' -f2 | cut -d'/' -f1)
          protocol=$(echo "$mapping" | grep -oE '(tcp|udp)')
          echo "   Host Port: $host_port -> Container Port: $container_port ($protocol)"
          echo "   🔗 Access: http://localhost:$host_port"
        done
        echo
      fi
    done
    ;;
  0)
    echo "❎ Exiting..."
    ;;
  *)
    echo "❌ Invalid option!"
    ;;
esac

echo
echo "✅ Done!"

#!/bin/bash
# Interactive Podman Compose Controller
BASE_DIR="/home/abdulwahab/Containers"

# Function to list all container projects
list_projects() {
  find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
}

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
  0)
    echo "❎ Exiting..."
    ;;
  *)
    echo "❌ Invalid option!"
    ;;
esac

echo
echo "✅ Done!"

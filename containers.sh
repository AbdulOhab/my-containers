#!/bin/bash
# Interactive Podman Compose Controller
BASE_DIR="/home/abdulwahab/Containers"

# Function to get all projects
list_projects() {
  find "$BASE_DIR" -maxdepth 1 -mindepth 1 -type d ! -name ".*" -exec basename {} \;
}

# Function to check if project is running
is_project_running() {
  local project=$1
  local count=$(podman ps --filter "label=io.podman.compose.project=$project" --format "{{.Names}}" | wc -l)
  [[ $count -gt 0 ]]
}

# Function to show all running containers with ports and links
show_all_running() {
  echo "=============================="
  echo "Running Containers"
  echo "=============================="
  
  running=$(podman ps --format "{{.Names}}\t{{.Ports}}\t{{.Status}}")
  
  if [[ -z "$running" ]]; then
    echo "No containers running"
  else
    while IFS=$'\t' read -r name ports status; do
      echo ""
      echo "Container: $name"
      echo "Status: $status"
      
      if [[ -n "$ports" && "$ports" != "" ]]; then
        echo "Ports: $ports"
        echo "$ports" | grep -oE '0\.0\.0\.0:([0-9]+)' | cut -d: -f2 | while read -r port; do
          echo "Link: http://localhost:$port"
        done
      else
        echo "No exposed ports"
      fi
    done <<< "$running"
  fi
  
  echo ""
  echo "=============================="
}

# Function to get running projects
get_running_projects() {
  podman ps --format "{{.Label \"io.podman.compose.project\"}}" | sort -u | grep -v "^$"
}

# Function to get stopped projects
get_stopped_projects() {
  local all_projects=($(list_projects))
  local running_projects=($(get_running_projects))
  
  for project in "${all_projects[@]}"; do
    local is_running=false
    for running in "${running_projects[@]}"; do
      if [[ "$project" == "$running" ]]; then
        is_running=true
        break
      fi
    done
    if ! $is_running; then
      echo "$project"
    fi
  done
}

# Main loop
while true; do
  clear
  echo "=============================="
  echo "Container Management System"
  echo "=============================="
  echo ""
  echo "Main Menu:"
  echo "  1) Running Status"
  echo "  2) Start (up)"
  echo "  3) Stop (down)"
  echo "  4) Restart"
  echo "  0) Exit"
  echo ""
  read -rp "Select an option: " main_choice

  case "$main_choice" in
    1)
      clear
      show_all_running
      echo ""
      read -rp "Press Enter to continue..."
      ;;
    
    2)
      clear
      echo "=============================="
      echo "Start Containers"
      echo "=============================="
      
      stopped_projects=($(get_stopped_projects))
      
      if [[ ${#stopped_projects[@]} -eq 0 ]]; then
        echo "No stopped containers available"
        echo ""
        read -rp "Press Enter to continue..."
        continue
      fi
      
      echo ""
      i=1
      for project in "${stopped_projects[@]}"; do
        echo "  $i) $project"
        ((i++))
      done
      echo "  0) Back to main menu"
      echo ""
      read -rp "Select project to start: " choice
      
      if [[ "$choice" == "0" ]]; then
        continue
      fi
      
      if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#stopped_projects[@]})); then
        echo "Invalid selection"
        read -rp "Press Enter to continue..."
        continue
      fi
      
      selected="${stopped_projects[$((choice-1))]}"
      echo ""
      echo "Starting $selected..."
      cd "$BASE_DIR/$selected" && podman-compose up -d
      sleep 2
      echo ""
      echo "=============================="
      echo "$selected containers:"
      echo "=============================="
      podman ps --filter "label=io.podman.compose.project=$selected" --format "{{.Names}}\t{{.Ports}}" | while IFS=$'\t' read -r name ports; do
        echo ""
        echo "Container: $name"
        if [[ -n "$ports" ]]; then
          echo "Ports: $ports"
          echo "$ports" | grep -oE '0\.0\.0\.0:([0-9]+)' | cut -d: -f2 | while read -r port; do
            echo "Link: http://localhost:$port"
          done
        fi
      done
      echo ""
      echo "=============================="
      read -rp "Press Enter to continue..."
      ;;
    
    3)
      clear
      echo "=============================="
      echo "Stop Containers"
      echo "=============================="
      
      running_projects=($(get_running_projects))
      
      if [[ ${#running_projects[@]} -eq 0 ]]; then
        echo "No running containers available"
        echo ""
        read -rp "Press Enter to continue..."
        continue
      fi
      
      echo ""
      i=1
      for project in "${running_projects[@]}"; do
        echo "  $i) $project"
        ((i++))
      done
      echo "  0) Back to main menu"
      echo ""
      read -rp "Select project to stop: " choice
      
      if [[ "$choice" == "0" ]]; then
        continue
      fi
      
      if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#running_projects[@]})); then
        echo "Invalid selection"
        read -rp "Press Enter to continue..."
        continue
      fi
      
      selected="${running_projects[$((choice-1))]}"
      echo ""
      echo "Stopping $selected..."
      cd "$BASE_DIR/$selected" && podman-compose down
      echo "Stopped successfully"
      echo ""
      read -rp "Press Enter to continue..."
      ;;
    
    4)
      clear
      echo "=============================="
      echo "Restart Containers"
      echo "=============================="
      
      all_projects=($(list_projects))
      
      echo ""
      i=1
      for project in "${all_projects[@]}"; do
        if is_project_running "$project"; then
          echo "  $i) $project [RUNNING]"
        else
          echo "  $i) $project [STOPPED]"
        fi
        ((i++))
      done
      echo "  0) Back to main menu"
      echo ""
      read -rp "Select project to restart: " choice
      
      if [[ "$choice" == "0" ]]; then
        continue
      fi
      
      if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#all_projects[@]})); then
        echo "Invalid selection"
        read -rp "Press Enter to continue..."
        continue
      fi
      
      selected="${all_projects[$((choice-1))]}"
      echo ""
      echo "Restarting $selected..."
      cd "$BASE_DIR/$selected" && podman-compose down && podman-compose up -d
      sleep 2
      echo ""
      echo "=============================="
      echo "$selected containers:"
      echo "=============================="
      podman ps --filter "label=io.podman.compose.project=$selected" --format "{{.Names}}\t{{.Ports}}" | while IFS=$'\t' read -r name ports; do
        echo ""
        echo "Container: $name"
        if [[ -n "$ports" ]]; then
          echo "Ports: $ports"
          echo "$ports" | grep -oE '0\.0\.0\.0:([0-9]+)' | cut -d: -f2 | while read -r port; do
            echo "Link: http://localhost:$port"
          done
        fi
      done
      echo ""
      echo "=============================="
      read -rp "Press Enter to continue..."
      ;;
    
    0)
      clear
      echo "Exiting..."
      exit 0
      ;;
    
    *)
      echo "Invalid option"
      sleep 1
      ;;
  esac
done
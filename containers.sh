#!/bin/bash
# Container Status Scanner - Detects all yml files and shows status
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Array to store all compose files
declare -a COMPOSE_FILES=()
declare -a RUNNING_PROJECTS=()

# Get all running podman compose projects
get_running_projects() {
  podman ps --format "{{.Label \"io.podman.compose.project\"}}" 2>/dev/null | sort -u | grep -v "^$"
}

# Find all yml/yaml files in current directory
find_compose_files() {
  # Enable nullglob to handle no matches case
  local shopt_save=$(shopt -p nullglob)
  shopt -s nullglob

  for file in *.yml *.yaml; do
    if [[ -f "$file" ]]; then
      COMPOSE_FILES+=("$file")
    fi
  done

  # Restore original nullglob setting
  eval "$shopt_save"

  # Also search in subdirectories (one level deep)
  local shopt_save2=$(shopt -p nullglob)
  shopt -s nullglob
  for dir in */; do
    if [[ -d "$dir" ]]; then
      for file in "$dir"*.yml "$dir"*.yaml; do
        if [[ -f "$file" ]]; then
          COMPOSE_FILES+=("$file")
        fi
      done
    fi
  done
  eval "$shopt_save2"
}

# Get project name from yml file (using directory name or COMPOSE_PROJECT_NAME if exists)
get_project_name() {
  local yml_file=$1

  # Check if COMPOSE_PROJECT_NAME is defined in the file
  if grep -q "COMPOSE_PROJECT_NAME" "$yml_file" 2>/dev/null; then
    local name=$(grep "COMPOSE_PROJECT_NAME" "$yml_file" | head -1 | cut -d= -f2)
    echo "$name"
  else
    # Use parent directory name (which is the folder name)
    local dir_name=$(basename "$(pwd)")
    # For compose files in subdirectories, use subdirectory name
    if [[ "$yml_file" == */* ]]; then
      echo "$(dirname "$yml_file")"
    else
      echo "$dir_name"
    fi
  fi
}

# Check if a specific project is running
is_project_running() {
  local project=$1
  for running in "${RUNNING_PROJECTS[@]}"; do
    if [[ "$project" == "$running" ]]; then
      return 0
    fi
  done
  return 1
}

# Display header
print_header() {
  clear
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo -e "${BOLD}${BLUE}    Container Status Scanner${NC}"
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo -e "${YELLOW}Scanning directory: ${SCRIPT_DIR}${NC}"
  echo ""
}

# Display status table
print_status() {
  echo -e "${BOLD}Detected Docker/Podman Compose Files:${NC}"
  echo ""

  if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
    echo -e "${RED}No yml/yaml files found in current directory!${NC}"
    echo ""
    return
  fi

  local running_count=0
  local stopped_count=0

  # Print header
  printf "  %-3s %-30s %-15s %-20s\n" "#" "Project/File" "Status" "Containers"
  echo -e "${BLUE}--------------------------------------------------------------------------------${NC}"

  local index=1
  for yml_file in "${COMPOSE_FILES[@]}"; do
    # Determine if this is in a subdirectory
    if [[ "$yml_file" == */* ]]; then
      project_name=$(dirname "$yml_file")
    else
      # Use the parent directory name as project name
      project_name=$(basename "$(dirname "$(readlink -f "$yml_file")")")
    fi

    if is_project_running "$project_name"; then
      status="${GREEN}● RUNNING${NC}"
      ((running_count++))

      # Get container count
      container_count=$(podman ps --filter "label=io.podman.compose.project=$project_name" --format "{{.Names}}" 2>/dev/null | wc -l)
      containers="$container_count container(s)"
    else
      status="${RED}○ STOPPED${NC}"
      ((stopped_count++))
      containers="Not running"
    fi

    printf "  %-3s %-30s %-25s %-20s\n" "$index)" "$project_name" "$status" "$containers"
    ((index++))
  done

  echo -e "${BLUE}--------------------------------------------------------------------------------${NC}"
  echo ""
  echo -e "${GREEN}Running projects: ${running_count}${NC} | ${RED}Stopped projects: ${stopped_count}${NC} | ${YELLOW}Total: ${#COMPOSE_FILES[@]}${NC}"
  echo ""
}

# Display running containers with details
show_running_details() {
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo -e "${BOLD}${BLUE}Running Containers Details${NC}"
  echo -e "${BOLD}${BLUE}============================================${NC}"
  echo ""

  running=$(podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)

  if [[ -z "$running" ]] || [[ $(echo "$running" | wc -l) -le 1 ]]; then
    echo -e "${RED}No containers are currently running${NC}"
  else
    echo "$running"
    echo ""
    echo -e "${BOLD}Access Links:${NC}"

    podman ps --format "{{.Names}}\t{{.Ports}}" 2>/dev/null | while IFS=$'\t' read -r name ports; do
      if [[ -n "$ports" ]]; then
        echo "$ports" | grep -oE '0\.0\.0\.0:([0-9]+)' | cut -d: -f2 | while read -r port; do
          echo -e "  ${GREEN}➜${NC} $name → ${BLUE}http://localhost:$port${NC}"
        done
      fi
    done
  fi
  echo ""
}

# Main execution
main() {
  # Get running projects
  mapfile -t RUNNING_PROJECTS < <(get_running_projects)

  # Find all compose files
  find_compose_files

  # Print status
  print_header
  print_status
  show_running_details

  # Menu
  echo -e "${BOLD}Options:${NC}"
  echo "  1) Refresh status"
  echo "  2) Start a stopped project"
  echo "  3) Stop a running project"
  echo "  4) Restart a project"
  echo "  5) View logs"
  echo "  0) Exit"
  echo ""
  read -rp "Select an option (or press Enter to just refresh): " choice

  case "$choice" in
    1|"")
      exec "$0"
      ;;
    2)
      # Start stopped project
      clear
      echo -e "${BOLD}${YELLOW}Start a Project${NC}"
      echo ""

      declare -a stopped_projects=()
      for yml_file in "${COMPOSE_FILES[@]}"; do
        if [[ "$yml_file" == */* ]]; then
          project_name=$(dirname "$yml_file")
          project_dir="$project_name"
        else
          project_name=$(basename "$(dirname "$(readlink -f "$yml_file")")")
          project_dir="."
        fi

        if ! is_project_running "$project_name"; then
          stopped_projects+=("$project_name:$project_dir")
        fi
      done

      if [[ ${#stopped_projects[@]} -eq 0 ]]; then
        echo -e "${YELLOW}All projects are already running!${NC}"
      else
        echo "Stopped projects:"
        echo ""
        local i=1
        for entry in "${stopped_projects[@]}"; do
          IFS=':' read -r name dir <<< "$entry"
          echo "  $i) $name"
          ((i++))
        done
        echo "  0) Cancel"
        echo ""
        read -rp "Select project to start: " start_choice

        if [[ "$start_choice" =~ ^[0-9]+$ ]] && ((start_choice >= 1 && start_choice <= ${#stopped_projects[@]})); then
          IFS=':' read -r name dir <<< "${stopped_projects[$((start_choice-1))]}"
          echo ""
          echo -e "${YELLOW}Starting $name...${NC}"
          echo "Directory: $SCRIPT_DIR/$dir"

          # Check if directory exists
          if [[ -d "$SCRIPT_DIR/$dir" ]]; then
            cd "$SCRIPT_DIR/$dir" || { echo -e "${RED}Failed to enter directory!${NC}"; read -rp "Press Enter to continue..."; exec "$0"; }
            echo "Current directory: $(pwd)"

            # List compose files in current directory
            echo "Compose files found:"
            ls -1 *.yml *.yaml 2>/dev/null || echo "  No compose files found!"

            echo ""
            echo "Running: podman-compose up -d"
            if podman-compose up -d; then
              echo -e "${GREEN}✓ Started successfully!${NC}"
            else
              echo -e "${RED}✗ Failed to start! Check the error above.${NC}"
            fi
          else
            echo -e "${RED}Error: Directory $SCRIPT_DIR/$dir does not exist!${NC}"
            echo "Available directories:"
            ls -la "$SCRIPT_DIR" | grep "^d"
          fi
        fi
      fi
      echo ""
      read -rp "Press Enter to continue..."
      exec "$0"
      ;;
    3)
      # Stop running project
      clear
      echo -e "${BOLD}${YELLOW}Stop a Project${NC}"
      echo ""

      if [[ ${#RUNNING_PROJECTS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No projects are currently running!${NC}"
      else
        echo "Running projects:"
        echo ""
        local i=1
        for project in "${RUNNING_PROJECTS[@]}"; do
          echo "  $i) $project"
          ((i++))
        done
        echo "  0) Cancel"
        echo ""
        read -rp "Select project to stop: " stop_choice

        if [[ "$stop_choice" =~ ^[0-9]+$ ]] && ((stop_choice >= 1 && stop_choice <= ${#RUNNING_PROJECTS[@]})); then
          selected="${RUNNING_PROJECTS[$((stop_choice-1))]}"
          echo ""
          echo -e "${YELLOW}Stopping $selected...${NC}"

          # Find the directory
          for yml_file in "${COMPOSE_FILES[@]}"; do
            if [[ "$yml_file" == */* ]]; then
              project_name=$(dirname "$yml_file")
              project_dir="$project_name"
            else
              project_name=$(basename "$(dirname "$(readlink -f "$yml_file")")")
              project_dir="."
            fi

            if [[ "$project_name" == "$selected" ]]; then
              cd "$SCRIPT_DIR/$project_dir" && podman-compose down
              break
            fi
          done
          echo -e "${GREEN}✓ Stopped successfully!${NC}"
        fi
      fi
      echo ""
      read -rp "Press Enter to continue..."
      exec "$0"
      ;;
    4)
      # Restart project
      clear
      echo -e "${BOLD}${YELLOW}Restart a Project${NC}"
      echo ""

      echo "Available projects:"
      echo ""
      local i=1
      declare -a all_projects=()
      for yml_file in "${COMPOSE_FILES[@]}"; do
        if [[ "$yml_file" == */* ]]; then
          project_name=$(dirname "$yml_file")
          project_dir="$project_name"
        else
          project_name=$(basename "$(dirname "$(readlink -f "$yml_file")")")
          project_dir="."
        fi

        if is_project_running "$project_name"; then
          echo "  $i) $project_name ${GREEN}[RUNNING]${NC}"
        else
          echo "  $i) $project_name ${RED}[STOPPED]${NC}"
        fi
        all_projects+=("$project_name:$project_dir")
        ((i++))
      done
      echo "  0) Cancel"
      echo ""
      read -rp "Select project to restart: " restart_choice

      if [[ "$restart_choice" =~ ^[0-9]+$ ]] && ((restart_choice >= 1 && restart_choice <= ${#all_projects[@]})); then
        IFS=':' read -r name dir <<< "${all_projects[$((restart_choice-1))]}"
        echo ""
        echo -e "${YELLOW}Restarting $name...${NC}"
        cd "$SCRIPT_DIR/$dir" && podman-compose down && podman-compose up -d
        echo -e "${GREEN}✓ Restarted successfully!${NC}"
      fi
      echo ""
      read -rp "Press Enter to continue..."
      exec "$0"
      ;;
    5)
      # View logs
      clear
      echo -e "${BOLD}${YELLOW}View Project Logs${NC}"
      echo ""

      if [[ ${#RUNNING_PROJECTS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No projects are currently running!${NC}"
      else
        echo "Running projects:"
        echo ""
        local i=1
        for project in "${RUNNING_PROJECTS[@]}"; do
          echo "  $i) $project"
          ((i++))
        done
        echo "  0) Cancel"
        echo ""
        read -rp "Select project to view logs: " log_choice

        if [[ "$log_choice" =~ ^[0-9]+$ ]] && ((log_choice >= 1 && log_choice <= ${#RUNNING_PROJECTS[@]})); then
          selected="${RUNNING_PROJECTS[$((log_choice-1))]}"
          clear
          echo -e "${BOLD}Showing logs for: $selected${NC}"
          echo -e "${YELLOW}(Press Ctrl+C to exit logs)${NC}"
          echo ""
          podman logs -f --filter "label=io.podman.compose.project=$selected" 2>/dev/null || \
          for yml_file in "${COMPOSE_FILES[@]}"; do
            if [[ "$yml_file" == */* ]]; then
              project_dir="$(dirname "$yml_file")"
            else
              project_dir="."
            fi
            cd "$SCRIPT_DIR/$project_dir" && podman-compose logs -f
          done
        fi
      fi
      echo ""
      ;;
    0)
      clear
      echo "Goodbye!"
      exit 0
      ;;
    *)
      echo ""
      read -rp "Press Enter to continue..."
      exec "$0"
      ;;
  esac
}

# Run main
main

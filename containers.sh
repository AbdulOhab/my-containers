#!/bin/bash
# Container Status Scanner - Detects all yml files and shows status
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
cd "$SCRIPT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Array to store all compose files
declare -a COMPOSE_FILES=()
declare -a RUNNING_PROJECTS=()

# Get server IP address
get_server_ip() {
  # Try to get IP from common methods
  local ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  if [[ -z "$ip" ]]; then
    ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
  fi
  if [[ -z "$ip" ]]; then
    ip=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1)
  fi
  # Fallback to localhost if no IP found
  echo "${ip:-localhost}"
}

# Get all running podman compose projects
get_running_projects() {
  local projects=()

  # Get projects by compose label
  while IFS= read -r project; do
    [[ -n "$project" ]] && projects+=("$project")
  done < <(podman ps --format "{{.Label \"io.podman.compose.project\"}}" 2>/dev/null | sort -u | grep -v "^$")

  # Also extract project names from container names (fallback)
  # For containers like "postgresql-server", "mariadb-server", "docmost_db_1", etc.
  while IFS= read -r container_name; do
    # Extract base name from various patterns
    # postgresql-server → postgresql
    # mariadb-server → mariadb
    # adminer-server → adminer
    # docmost_db_1 → docmost (from first part)
    # portainer → portainer

    # Pattern 1: Remove -server, -container suffix
    base_name=$(echo "$container_name" | sed -E 's/-(server|container)$//')

    # Pattern 2: For names like docmost_db_1, extract first part
    if [[ "$base_name" == *"_"* ]]; then
      base_name=$(echo "$base_name" | cut -d_ -f1)
    fi

    # Pattern 3: For names like postgres_report_application, extract first part
    if [[ "$base_name" == *"_"* ]] && [[ "$base_name" != *"_"*"_"* ]]; then
      base_name=$(echo "$base_name" | cut -d_ -f1)
    fi

    [[ -n "$base_name" ]] && projects+=("$base_name")
  done < <(podman ps --format "{{.Names}}" 2>/dev/null)

  # Return unique sorted list
  printf '%s\n' "${projects[@]}" | sort -u | grep -v "^$"
}

# Find all yml/yaml files in current directory and subdirectories
find_compose_files() {
  COMPOSE_FILES=()

  # Enable nullglob to handle no matches case
  local shopt_save=$(shopt -p nullglob)
  shopt -s nullglob

  # Search in root directory
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
      # Remove trailing slash
      dir="${dir%/}"
      for file in "$dir"/*.yml "$dir"/*.yaml; do
        if [[ -f "$file" ]]; then
          COMPOSE_FILES+=("$file")
        fi
      done
    fi
  done
  eval "$shopt_save2"
}

# Get project name from yml file path
get_project_name() {
  local yml_file=$1
  if [[ "$yml_file" == */* ]]; then
    # Extract directory name
    dirname "$yml_file"
  else
    # Use parent directory name
    basename "$(dirname "$(readlink -f "$yml_file")")"
  fi
}

# Get project directory from file path
get_project_dir() {
  local yml_file=$1
  if [[ "$yml_file" == */* ]]; then
    dirname "$yml_file"
  else
    "."
  fi
}

# Check if a specific project is running
is_project_running() {
  local project=$1

  # First check by compose project label
  for running in "${RUNNING_PROJECTS[@]}"; do
    if [[ "$project" == "$running" ]]; then
      return 0
    fi
  done

  # Also check by container name pattern (fallback for containers without proper labels)
  # This handles: postgresql-server, mariadb-server, adminer-server, cloudbeaver-server, etc.
  local running_containers=$(podman ps --format "{{.Names}}" 2>/dev/null)

  # Check for common naming patterns
  if echo "$running_containers" | grep -q "^${project}-server"; then
    return 0
  fi
  if echo "$running_containers" | grep -q "^${project}-container"; then
    return 0
  fi
  if echo "$running_containers" | grep -q "^${project}_[0-9]"; then
    return 0
  fi
  if echo "$running_containers" | grep -q "^${project}_"; then
    return 0
  fi

  return 1
}

# Parse selection and return array of indices
parse_selection() {
  local selection=$1
  local max_index=$2

  if [[ -z "$selection" ]] || [[ "$selection" == "0" ]]; then
    return
  fi

  if [[ "$selection" == "all" ]] || [[ "$selection" == "ALL" ]]; then
    seq 1 $max_index
    return
  fi

  # Handle ranges (e.g., 1-3)
  if [[ "$selection" =~ - ]]; then
    local start=$(echo "$selection" | cut -d- -f1)
    local end=$(echo "$selection" | cut -d- -f2)
    if [[ "$start" =~ ^[0-9]+$ ]] && [[ "$end" =~ ^[0-9]+$ ]]; then
      seq $start $end
      return
    fi
  fi

  # Handle individual numbers
  for num in $selection; do
    if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= max_index)); then
      echo "$num"
    fi
  done
}

# Display header
print_header() {
  clear
  local SERVER_IP=$(get_server_ip)
  printf "${BOLD}${CYAN}============================================${NC}\n"
  printf "${BOLD}${CYAN}    Container Status Scanner${NC}\n"
  printf "${BOLD}${CYAN}============================================${NC}\n"
  printf "${YELLOW}Directory: ${SCRIPT_DIR}${NC}\n"
  printf "${YELLOW}Server IP: ${CYAN}${SERVER_IP}${NC}\n"
  printf "\n"
}

# Display status table
print_status() {
  printf "${BOLD}Detected Docker/Podman Compose Files:${NC}\n"
  printf "\n"

  if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
    printf "${RED}No yml/yaml files found in current directory!${NC}\n"
    printf "\n"
    return
  fi

  local running_count=0
  local stopped_count=0

  # Print header
  printf "  %-3s %-30s %-15s %-20s\n" "#" "Project/File" "Status" "Containers"
  printf "${BLUE}--------------------------------------------------------------------------------${NC}\n"

  local index=1
  for yml_file in "${COMPOSE_FILES[@]}"; do
    local project_name=$(get_project_name "$yml_file")

    if is_project_running "$project_name"; then
      ((running_count++))

      # Get container count - check by both label and name pattern
      local container_count=0

      # First try by label
      container_count=$(podman ps --filter "label=io.podman.compose.project=$project_name" --format "{{.Names}}" 2>/dev/null | wc -l)

      # If no containers found by label, try by name pattern
      if [[ "$container_count" -eq 0 ]]; then
        container_count=$(podman ps --format "{{.Names}}" 2>/dev/null | grep -c "^${project_name}-" || echo "0")
      fi

      # Still zero? Try more flexible pattern
      if [[ "$container_count" -eq 0 ]]; then
        container_count=$(podman ps --format "{{.Names}}" 2>/dev/null | grep -c "^${project_name}" || echo "0")
      fi

      containers="$container_count container(s)"

      # Print with green UP status
      printf "  %-3s %-30s ${GREEN}%-25s${NC} %-20s\n" "$index)" "$project_name" "[UP]" "$containers"
    else
      ((stopped_count++))
      containers="Not running"

      # Print with red DOWN status
      printf "  %-3s %-30s ${RED}%-25s${NC} %-20s\n" "$index)" "$project_name" "[DOWN]" "$containers"
    fi
    ((index++))
  done

  printf "${BLUE}--------------------------------------------------------------------------------${NC}\n"
  printf "\n"
  printf "${GREEN}Running projects: ${running_count}${NC} | ${RED}Stopped projects: ${stopped_count}${NC} | ${YELLOW}Total: ${#COMPOSE_FILES[@]}${NC}\n"
  printf "\n"
}

# Display running containers with details
show_running_details() {
  printf "${BOLD}${BLUE}============================================${NC}\n"
  printf "${BOLD}${BLUE}Running Containers Details${NC}\n"
  printf "${BOLD}${BLUE}============================================${NC}\n"
  printf "\n"

  # Get server IP
  local SERVER_IP=$(get_server_ip)

  running=$(podman ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)

  if [[ -z "$running" ]] || [[ $(echo "$running" | wc -l) -le 1 ]]; then
    printf "${RED}No containers are currently running${NC}\n"
  else
    echo "$running"
    printf "\n"
    printf "${BOLD}Access Links (${CYAN}Server IP: $SERVER_IP${NC}):${NC}\n"

    podman ps --format "{{.Names}}\t{{.Ports}}" 2>/dev/null | while IFS=$'\t' read -r name ports; do
      if [[ -n "$ports" ]]; then
        echo "$ports" | grep -oE '0\.0\.0\.0:([0-9]+)' | cut -d: -f2 | while read -r port; do
          printf "  ${GREEN}->${NC} $name -> ${BLUE}http://$SERVER_IP:$port${NC}\n"
        done
      fi
    done
  fi
  printf "\n"
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
  printf "${BOLD}Options:${NC}\n"
  printf "  1) Refresh status\n"
  printf "  2) Start projects (multi-select)\n"
  printf "  3) Stop projects (multi-select)\n"
  printf "  4) Restart projects (multi-select)\n"
  printf "  5) View logs\n"
  printf "  0) Exit\n"
  printf "\n"
  read -rp "Select an option (or press Enter to just refresh): " choice

  case "$choice" in
    1|"")
      bash "$SCRIPT_PATH"
      exit 0
      ;;
    2)
      # Start stopped projects (multi-select)
      clear
      printf "${BOLD}${YELLOW}Start Projects${NC}\n"
      printf "\n"

      declare -a stopped_projects=()
      for yml_file in "${COMPOSE_FILES[@]}"; do
        project_name=$(get_project_name "$yml_file")
        project_dir=$(get_project_dir "$yml_file")

        if ! is_project_running "$project_name"; then
          stopped_projects+=("$project_name:$project_dir")
        fi
      done

      if [[ ${#stopped_projects[@]} -eq 0 ]]; then
        printf "${YELLOW}All projects are already running!${NC}\n"
      else
        printf "Stopped projects:\n"
        printf "\n"
        local i=1
        for entry in "${stopped_projects[@]}"; do
          IFS=':' read -r name dir <<< "$entry"
          echo "  $i) $name"
          ((i++))
        done
        echo "  0) Cancel"
        printf "\n"
        printf "${CYAN}Enter numbers (e.g., 1 3 5), range (1-3), or 'all': ${NC}"
        read -rp "Select projects to start: " start_choice

        local -a selected_indices=($(parse_selection "$start_choice" "${#stopped_projects[@]}"))

        if [[ ${#selected_indices[@]} -gt 0 ]]; then
          printf "\n"
          local success_count=0
          local fail_count=0

          for index in "${selected_indices[@]}"; do
            IFS=':' read -r name dir <<< "${stopped_projects[$((index-1))]}"
            printf "${YELLOW}[*] Starting: $name${NC}\n"

            if [[ -d "$SCRIPT_DIR/$dir" ]]; then
              cd "$SCRIPT_DIR/$dir" && {
                if podman-compose --env-file "$SCRIPT_DIR/.env" up -d 2>&1; then
                  printf "${GREEN}  [OK] Started successfully${NC}\n"
                  ((success_count++))
                else
                  printf "${RED}  [FAIL] Failed to start${NC}\n"
                  ((fail_count++))
                fi
              }
            else
              printf "${RED}  [FAIL] Directory not found${NC}\n"
              ((fail_count++))
            fi
            printf "\n"
          done

          printf "${BLUE}────────────────────────────────────────────${NC}\n"
          printf "${GREEN}[OK] Started: $success_count${NC} | ${RED}[FAIL] Failed: $fail_count${NC}\n"
        fi
      fi
      printf "\n"
      read -rp "Press Enter to continue..."
      bash "$SCRIPT_PATH"
      exit 0
      ;;
    3)
      # Stop running projects (multi-select)
      clear
      printf "${BOLD}${YELLOW}Stop Projects${NC}\n"
      printf "\n"

      if [[ ${#RUNNING_PROJECTS[@]} -eq 0 ]]; then
        printf "${YELLOW}No projects are currently running!${NC}\n"
      else
        printf "Running projects:\n"
        printf "\n"
        local i=1
        for project in "${RUNNING_PROJECTS[@]}"; do
          echo "  $i) $project"
          ((i++))
        done
        echo "  0) Cancel"
        printf "\n"
        printf "${CYAN}Enter numbers (e.g., 1 3 5), range (1-3), or 'all': ${NC}"
        read -rp "Select projects to stop: " stop_choice

        local -a selected_indices=($(parse_selection "$stop_choice" "${#RUNNING_PROJECTS[@]}"))

        if [[ ${#selected_indices[@]} -gt 0 ]]; then
          printf "\n"
          local success_count=0
          local fail_count=0
          local skip_count=0

          for index in "${selected_indices[@]}"; do
            selected="${RUNNING_PROJECTS[$((index-1))]}"
            printf "${YELLOW}[*] Stopping: $selected${NC}\n"

            # Check if still running
            if ! is_project_running "$selected"; then
              printf "${YELLOW}  [SKIP] Already stopped${NC}\n"
              ((skip_count++))
            else
              # Find the directory
              for yml_file in "${COMPOSE_FILES[@]}"; do
                project_name=$(get_project_name "$yml_file")
                project_dir=$(get_project_dir "$yml_file")

                if [[ "$project_name" == "$selected" ]]; then
                  if [[ -d "$SCRIPT_DIR/$project_dir" ]]; then
                    cd "$SCRIPT_DIR/$project_dir" && {
                      if podman-compose --env-file "$SCRIPT_DIR/.env" down 2>&1; then
                        printf "${GREEN}  [OK] Stopped successfully${NC}\n"
                        ((success_count++))
                      else
                        printf "${RED}  [FAIL] Failed to stop${NC}\n"
                        ((fail_count++))
                      fi
                    }
                  else
                    printf "${RED}  [FAIL] Directory not found${NC}\n"
                    ((fail_count++))
                  fi
                  break
                fi
              done
            fi
            printf "\n"
          done

          printf "${BLUE}────────────────────────────────────────────${NC}\n"
          printf "${GREEN}[OK] Stopped: $success_count${NC} | ${YELLOW}[SKIP] Skipped: $skip_count${NC} | ${RED}[FAIL] Failed: $fail_count${NC}\n"
        fi
      fi
      printf "\n"
      read -rp "Press Enter to continue..."
      bash "$SCRIPT_PATH"
      exit 0
      ;;
    4)
      # Restart projects (multi-select)
      clear
      printf "${BOLD}${YELLOW}Restart Projects${NC}\n"
      printf "\n"

      echo "Available projects:"
      printf "\n"
      local i=1
      declare -a all_projects=()
      for yml_file in "${COMPOSE_FILES[@]}"; do
        project_name=$(get_project_name "$yml_file")
        project_dir=$(get_project_dir "$yml_file")

        if is_project_running "$project_name"; then
          echo "  $i) $project_name ${GREEN}[UP]${NC}"
        else
          echo "  $i) $project_name ${RED}[DOWN]${NC}"
        fi
        all_projects+=("$project_name:$project_dir")
        ((i++))
      done
      echo "  0) Cancel"
      printf "\n"
      printf "${CYAN}Enter numbers (e.g., 1 3 5), range (1-3), or 'all': ${NC}"
      read -rp "Select projects to restart: " restart_choice

      local -a selected_indices=($(parse_selection "$restart_choice" "${#all_projects[@]}"))

      if [[ ${#selected_indices[@]} -gt 0 ]]; then
        printf "\n"
        local success_count=0
        local fail_count=0

        for index in "${selected_indices[@]}"; do
          IFS=':' read -r name dir <<< "${all_projects[$((index-1))]}"
          printf "${YELLOW}[*] Restarting: $name${NC}\n"

          if [[ -d "$SCRIPT_DIR/$dir" ]]; then
            cd "$SCRIPT_DIR/$dir" && {
              if podman-compose --env-file "$SCRIPT_DIR/.env" down && podman-compose --env-file "$SCRIPT_DIR/.env" up -d 2>&1; then
                printf "${GREEN}  [OK] Restarted successfully${NC}\n"
                ((success_count++))
              else
                printf "${RED}  [FAIL] Failed to restart${NC}\n"
                ((fail_count++))
              fi
            }
          else
            printf "${RED}  [FAIL] Directory not found${NC}\n"
            ((fail_count++))
          fi
          printf "\n"
        done

        printf "${BLUE}────────────────────────────────────────────${NC}\n"
        printf "${GREEN}[OK] Restarted: $success_count${NC} | ${RED}[FAIL] Failed: $fail_count${NC}\n"
      fi
      printf "\n"
      read -rp "Press Enter to continue..."
      bash "$SCRIPT_PATH"
      exit 0
      ;;
    5)
      # View logs
      clear
      printf "${BOLD}${YELLOW}View Project Logs${NC}\n"
      printf "\n"

      # Get all running containers
      local -a all_containers=()
      while IFS= read -r line; do
        [[ -n "$line" ]] && all_containers+=("$line")
      done < <(podman ps --format "{{.Names}}" 2>/dev/null)

      if [[ ${#all_containers[@]} -eq 0 ]]; then
        printf "${YELLOW}No containers are currently running!${NC}\n"
      else
        printf "Running containers:\n"
        printf "\n"
        local i=1
        for container in "${all_containers[@]}"; do
          echo "  $i) $container"
          ((i++))
        done
        echo "  0) Cancel"
        printf "\n"
        read -rp "Select container to view logs: " log_choice

        if [[ "$log_choice" =~ ^[0-9]+$ ]] && ((log_choice >= 1 && log_choice <= ${#all_containers[@]})); then
          selected="${all_containers[$((log_choice-1))]}"
          clear
          printf "${BOLD}Showing logs for: $selected${NC}\n"
          printf "${YELLOW}(Press Ctrl+C to exit logs)${NC}\n"
          printf "\n"
          printf "${BLUE}============================================${NC}\n"
          podman logs -f "$selected" 2>/dev/null
        fi
      fi
      printf "\n"
      ;;
    0)
      clear
      printf "${GREEN}Goodbye!${NC}\n"
      exit 0
      ;;
    *)
      printf "\n"
      read -rp "Press Enter to continue..."
      bash "$SCRIPT_PATH"
      exit 0
      ;;
  esac
}

# Run main
main

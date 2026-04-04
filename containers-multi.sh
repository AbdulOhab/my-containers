#!/bin/bash
# Multi-Select Container Manager - Select multiple projects to up/down
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Arrays
declare -a COMPOSE_FILES=()
declare -a RUNNING_PROJECTS=()

# Get running projects
get_running_projects() {
  podman ps --format "{{.Label \"io.podman.compose.project\"}}" 2>/dev/null | sort -u | grep -v "^$"
}

# Find all compose files
find_compose_files() {
  local shopt_save=$(shopt -p nullglob)
  shopt -s nullglob

  for file in *.yml *.yaml; do
    if [[ -f "$file" ]]; then
      COMPOSE_FILES+=("$file")
    fi
  done

  eval "$shopt_save"

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

# Get project name from file path
get_project_name() {
  local yml_file=$1
  if [[ "$yml_file" == */* ]]; then
    dirname "$yml_file"
  else
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

# Check if project is running
is_project_running() {
  local project=$1
  for running in "${RUNNING_PROJECTS[@]}"; do
    [[ "$project" == "$running" ]] && return 0
  done
  return 1
}

# Display header
print_header() {
  clear
  printf "${BOLD}${CYAN}============================================\n${NC}"
  printf "${BOLD}${CYAN}    Multi-Select Container Manager\n${NC}"
  printf "${BOLD}${CYAN}============================================\n${NC}"
  printf "${YELLOW}Directory: ${SCRIPT_DIR}${NC}\n"
  printf "\n"
}

# Display all projects with status
display_projects() {
  printf "${BOLD}Available Projects:${NC}\n"
  printf "\n"

  if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
    printf "${RED}No compose files found!${NC}\n"
    return 1
  fi

  printf "  %-3s %-25s %-15s\n" "#" "Project" "Status"
  printf "${BLUE}────────────────────────────────────────────${NC}\n"

  local index=1
  for yml_file in "${COMPOSE_FILES[@]}"; do
    local project_name=$(get_project_name "$yml_file")
    local project_dir=$(get_project_dir "$yml_file")

    if is_project_running "$project_name"; then
      local status="${GREEN}[UP]${NC}"
    else
      local status="${RED}[DOWN]${NC}"
    fi

    printf "  %-3s %-25s %-15s\n" "$index)" "$project_name" "$status"
    ((index++))
  done

  printf "\n"
  printf "${CYAN}Instructions:${NC}\n"
  printf "  * Enter numbers separated by spaces (e.g., 1 3 5)\n"
  printf "  * Enter range (e.g., 1-3 for projects 1,2,3)\n"
  printf "  * Enter 'all' to select all projects\n"
  printf "  * Enter 0 or leave empty to cancel\n"
  printf "\n"
  return 0
}

# Parse selection and return array of indices
parse_selection() {
  local selection=$1
  local max_index=$2
  local -a selected_indices=()

  if [[ -z "$selection" ]] || [[ "$selection" == "0" ]]; then
    echo ""
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

# Up selected projects
up_projects() {
  print_header
  display_projects || return

  read -rp "Enter projects to UP: " selection
  echo ""

  local -a selected_indices=($(parse_selection "$selection" "${#COMPOSE_FILES[@]}"))

  if [[ ${#selected_indices[@]} -eq 0 ]]; then
    printf "${YELLOW}No projects selected.${NC}\n"
    read -rp "Press Enter to continue..."
    return
  fi

  printf "${BOLD}${YELLOW}Starting selected projects...${NC}\n"
  printf "${BLUE}────────────────────────────────────────────${NC}\n"
  printf "\n"

  local success_count=0
  local fail_count=0

  for index in "${selected_indices[@]}"; do
    local yml_file="${COMPOSE_FILES[$((index-1))]}"
    local project_name=$(get_project_name "$yml_file")
    local project_dir=$(get_project_dir "$yml_file")

    printf "${CYAN}[*] Starting: $project_name${NC}\n"

    if [[ -d "$SCRIPT_DIR/$project_dir" ]]; then
      if (cd "$SCRIPT_DIR/$project_dir" && podman-compose up -d 2>&1); then
        printf "${GREEN}  [OK] Started successfully${NC}\n"
        ((success_count++))
      else
        printf "${RED}  [FAIL] Failed to start${NC}\n"
        ((fail_count++))
      fi
    else
      printf "${RED}  [FAIL] Directory not found: $SCRIPT_DIR/$project_dir${NC}\n"
      ((fail_count++))
    fi
    printf "\n"
  done

  printf "${BLUE}────────────────────────────────────────────${NC}\n"
  printf "${GREEN}[OK] Started: $success_count${NC} | ${RED}[FAIL] Failed: $fail_count${NC}\n"
  printf "\n"
  read -rp "Press Enter to continue..."
}

# Down selected projects
down_projects() {
  print_header

  # Get running projects first
  mapfile -t RUNNING_PROJECTS < <(get_running_projects)

  display_projects || return

  read -rp "Enter projects to DOWN: " selection
  echo ""

  local -a selected_indices=($(parse_selection "$selection" "${#COMPOSE_FILES[@]}"))

  if [[ ${#selected_indices[@]} -eq 0 ]]; then
    printf "${YELLOW}No projects selected.${NC}\n"
    read -rp "Press Enter to continue..."
    return
  fi

  printf "${BOLD}${YELLOW}Stopping selected projects...${NC}\n"
  printf "${BLUE}────────────────────────────────────────────${NC}\n"
  printf "\n"

  local success_count=0
  local fail_count=0
  local skip_count=0

  for index in "${selected_indices[@]}"; do
    local yml_file="${COMPOSE_FILES[$((index-1))]}"
    local project_name=$(get_project_name "$yml_file")
    local project_dir=$(get_project_dir "$yml_file")

    printf "${CYAN}[*] Stopping: $project_name${NC}\n"

    if ! is_project_running "$project_name"; then
      printf "${YELLOW}  [SKIP] Already stopped${NC}\n"
      ((skip_count++))
    else
      if [[ -d "$SCRIPT_DIR/$project_dir" ]]; then
        if (cd "$SCRIPT_DIR/$project_dir" && podman-compose down 2>&1); then
          printf "${GREEN}  [OK] Stopped successfully${NC}\n"
          ((success_count++))
        else
          printf "${RED}  [FAIL] Failed to stop${NC}\n"
          ((fail_count++))
        fi
      else
        printf "${RED}  [FAIL] Directory not found: $SCRIPT_DIR/$project_dir${NC}\n"
        ((fail_count++))
      fi
    fi
    printf "\n"
  done

  printf "${BLUE}────────────────────────────────────────────${NC}\n"
  printf "${GREEN}[OK] Stopped: $success_count${NC} | ${YELLOW}[SKIP] Skipped: $skip_count${NC} | ${RED}[FAIL] Failed: $fail_count${NC}\n"
  printf "\n"
  read -rp "Press Enter to continue..."
}

# Show status
show_status() {
  print_header
  mapfile -t RUNNING_PROJECTS < <(get_running_projects)

  printf "${BOLD}Current Status:${NC}\n"
  printf "\n"

  local running_count=0
  local stopped_count=0

  if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
    printf "${RED}No compose files found!${NC}\n"
    printf "\n"
    read -rp "Press Enter to continue..."
    return
  fi

  printf "  %-3s %-25s %-15s %-20s\n" "#" "Project" "Status" "Containers"
  printf "${BLUE}────────────────────────────────────────────────────────${NC}\n"

  local index=1
  for yml_file in "${COMPOSE_FILES[@]}"; do
    local project_name=$(get_project_name "$yml_file")

    if is_project_running "$project_name"; then
      local status="${GREEN}[UP]${NC}"
      ((running_count++))
      local container_count=$(podman ps --filter "label=io.podman.compose.project=$project_name" --format "{{.Names}}" 2>/dev/null | wc -l)
      local containers="$container_count container(s)"
    else
      local status="${RED}[DOWN]${NC}"
      ((stopped_count++))
      local containers="Not running"
    fi

    printf "  %-3s %-25s %-25s %-20s\n" "$index)" "$project_name" "$status" "$containers"
    ((index++))
  done

  printf "${BLUE}────────────────────────────────────────────────────────${NC}\n"
  printf "\n"
  printf "${GREEN}UP: $running_count${NC} | ${RED}DOWN: $stopped_count${NC} | ${YELLOW}Total: ${#COMPOSE_FILES[@]}${NC}\n"
  printf "\n"

  # Show access links
  if [[ $running_count -gt 0 ]]; then
    printf "${BOLD}Access Links:${NC}\n"
    podman ps --format "{{.Names}}\t{{.Ports}}" 2>/dev/null | while IFS=$'\t' read -r name ports; do
      if [[ -n "$ports" ]]; then
        echo "$ports" | grep -oE '0\.0\.0\.0:([0-9]+)' | cut -d: -f2 | while read -r port; do
          printf "  ${GREEN}->${NC} $name -> ${BLUE}http://localhost:$port${NC}\n"
        done
      fi
    done
    printf "\n"
  fi

  read -rp "Press Enter to continue..."
}

# Restart selected projects
restart_projects() {
  print_header
  mapfile -t RUNNING_PROJECTS < <(get_running_projects)

  display_projects || return

  read -rp "Enter projects to RESTART: " selection
  echo ""

  local -a selected_indices=($(parse_selection "$selection" "${#COMPOSE_FILES[@]}"))

  if [[ ${#selected_indices[@]} -eq 0 ]]; then
    printf "${YELLOW}No projects selected.${NC}\n"
    read -rp "Press Enter to continue..."
    return
  fi

  printf "${BOLD}${YELLOW}Restarting selected projects...${NC}\n"
  printf "${BLUE}────────────────────────────────────────────${NC}\n"
  printf "\n"

  local success_count=0
  local fail_count=0

  for index in "${selected_indices[@]}"; do
    local yml_file="${COMPOSE_FILES[$((index-1))]}"
    local project_name=$(get_project_name "$yml_file")
    local project_dir=$(get_project_dir "$yml_file")

    printf "${CYAN}[*] Restarting: $project_name${NC}\n"

    if [[ -d "$SCRIPT_DIR/$project_dir" ]]; then
      if (cd "$SCRIPT_DIR/$project_dir" && podman-compose down && podman-compose up -d 2>&1); then
        printf "${GREEN}  [OK] Restarted successfully${NC}\n"
        ((success_count++))
      else
        printf "${RED}  [FAIL] Failed to restart${NC}\n"
        ((fail_count++))
      fi
    else
      printf "${RED}  [FAIL] Directory not found: $SCRIPT_DIR/$project_dir${NC}\n"
      ((fail_count++))
    fi
    printf "\n"
  done

  printf "${BLUE}────────────────────────────────────────────${NC}\n"
  printf "${GREEN}[OK] Restarted: $success_count${NC} | ${RED}[FAIL] Failed: $fail_count${NC}\n"
  printf "\n"
  read -rp "Press Enter to continue..."
}

# Main menu
main_menu() {
  while true; do
    print_header
    mapfile -t RUNNING_PROJECTS < <(get_running_projects)
    find_compose_files

    printf "${BOLD}${CYAN}Main Menu:${NC}\n"
    printf "\n"
    printf "  ${GREEN}1${NC}) UP      - Start selected projects\n"
    printf "  ${RED}2${NC}) DOWN    - Stop selected projects\n"
    printf "  ${BLUE}3${NC}) RESTART - Restart selected projects\n"
    printf "  ${YELLOW}4${NC}) STATUS  - Show all status\n"
    printf "  ${CYAN}0${NC}) EXIT\n"
    printf "\n"
    printf "${CYAN}Tip: You can enter multiple options (e.g., '1 2' for UP then DOWN)${NC}\n"
    printf "\n"

    read -rp "Select option: " choices

    # Process multiple choices
    for choice in $choices; do
      case "$choice" in
        1)
          up_projects
          ;;
        2)
          down_projects
          ;;
        3)
          restart_projects
          ;;
        4)
          show_status
          ;;
        0)
          clear
          printf "${GREEN}Goodbye!${NC}\n"
          exit 0
          ;;
        *)
          printf "${RED}Invalid option: $choice${NC}\n"
          sleep 1
          ;;
      esac
    done
  done
}

# Run main menu
main_menu

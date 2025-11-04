#!/bin/bash

# This script removes the sudoers configuration files created by setup_sudoers.sh
# for a specific project and user.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Logging Functions & Colors ---
# Define colors for log messages
readonly COLOR_RESET="\033[0m"
readonly COLOR_INFO="\033[0;34m"
readonly COLOR_SUCCESS="\033[0;32m"
readonly COLOR_WARN="\033[0;33m"
readonly COLOR_ERROR="\033[0;31m"

# Function to log messages with a specific color and emoji
log() {
  local color="$1"
  local emoji="$2"
  local message="$3"
  echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] ${emoji} ${message}${COLOR_RESET}"
}

log_info() { log "${COLOR_INFO}" "ℹ️" "$1"; }
log_success() { log "${COLOR_SUCCESS}" "✅" "$1"; }
log_warn() { log "${COLOR_WARN}" "⚠️" "$1"; }
log_error() { log "${COLOR_ERROR}" "❌" "$1"; }
log_output() { log "${COLOR_RESET}" "" "$1"; }
# ------------------------------------

if [ "$EUID" -ne 0 ]; then
  log_error "This script must be run as root or with sudo."
  exit 1
fi

log_output "Which user's sudoers files do you want to remove?"
log_output "1. Current user"
log_output "2. Devops user"
read -rp "Enter your choice [1-2]: " USER_CHOICE

case "$USER_CHOICE" in
  1)
    RUNNER_USER=${SUDO_USER:-$(whoami)}
    log_info "Targeting sudoers files for the current user: '$RUNNER_USER'"
    ;;
  2)
    RUNNER_USER="devops"
    log_info "Targeting sudoers files for the 'devops' user."
    ;;
  *)
    log_error "Invalid choice. Please enter 1 or 2."
    exit 1
    ;;
esac

# Determine the repository root to get the SERVICE_NAME
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PATH_TO_ROOT_REPOSITORY=$(sudo -u "${SUDO_USER:-$(whoami)}" git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
if [ -z "$PATH_TO_ROOT_REPOSITORY" ]; then
    log_error "Could not determine the root of the git repository. Make sure you are running this script from within the repository."
    exit 1
fi
SERVICE_NAME=$(basename "$PATH_TO_ROOT_REPOSITORY")

log_info "Cleaning up sudoers files for project '$SERVICE_NAME' and user '$RUNNER_USER'..."

# Construct the list of sudoers files created by the setup script
SUDOERS_FILES_TO_REMOVE=(
  "/etc/sudoers.d/90-chown-for-${SERVICE_NAME}-to-${RUNNER_USER}"
  "/etc/sudoers.d/90-setup-dev-scripts-for-${SERVICE_NAME}-to-${RUNNER_USER}"
  "/etc/sudoers.d/90-git-for-${SERVICE_NAME}-to-${RUNNER_USER}"
  "/etc/sudoers.d/90-update-script-for-${SERVICE_NAME}-to-${RUNNER_USER}"
  "/etc/sudoers.d/90-docker-for-${SERVICE_NAME}-to-${RUNNER_USER}"
)

for file_path in "${SUDOERS_FILES_TO_REMOVE[@]}"; do
  if [ -f "$file_path" ]; then
    log_warn "Removing file: $file_path"
    rm -f "$file_path"
    log_success "Successfully removed $file_path."
  else
    log_info "File not found, skipping: $file_path"
  fi
done

log_success "Sudoers cleanup complete for project '$SERVICE_NAME' and user '$RUNNER_USER'."

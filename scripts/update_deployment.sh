#!/bin/bash

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
# ------------------------------------

# Function to handle errors and exit
handle_error() {
  log_error "$1"
  log_error "Update script failed."
  exit 1
}

function main() {
  CURRENT_DIR=$(dirname "$(readlink -f "$0")")
  CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
  PATH_TO_ROOT_REPOSITORY=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)
  SERVICE_NAME=$(basename "$PATH_TO_ROOT_REPOSITORY")
  REPOSITORY_OWNER=$(stat -c '%U' "$PATH_TO_ROOT_REPOSITORY")

  log_info "Starting application update process..."

  local ENV_FILE_PATH="$PATH_TO_ROOT_REPOSITORY/.env"

  if [ -f "$ENV_FILE_PATH" ]; then
    set -a # automatically export all variables
    # shellcheck source=/dev/null
    source "$ENV_FILE_PATH"
    set +a # Stop automatically exporting variables
    log_success "Loaded environment variables from .env file."
  else
    handle_error ".env file not found! Cannot proceed."
  fi

  if [ -z "$APP_NAME" ] || [ "$APP_NAME" == "enter_your_app_name" ]; then
    handle_error "APP_NAME is not set or is a placeholder in .env. Please set it to your application's directory name."
  fi
  log_info "Application name: $APP_NAME"

  local APP_DIR="$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME"

  if [ ! -d "$APP_DIR/.git" ]; then
    handle_error "Not a git repository: $APP_DIR. Cannot pull updates."
  fi

  if [ "$DEPLOYMENT_MODE" == "development" ]; then
    log_info "Development mode detected. Updating directory ownership..."
    sudo chown -R "${REPOSITORY_OWNER}:${REPOSITORY_OWNER}" "$APP_DIR" && {
      log_success "Application directory ownership updated for development."
    } || handle_error "Failed to change ownership of $APP_DIR."
  fi

  log_info "Fetching latest changes for $APP_NAME..."
  sudo -u "$REPOSITORY_OWNER" git -C "$APP_DIR" fetch || handle_error "Failed to fetch from git repository in $APP_DIR."

  log_info "Pulling latest changes for $APP_NAME..."
  sudo -u "$REPOSITORY_OWNER" git -C "$APP_DIR" pull || handle_error "Failed to pull from git repository in $APP_DIR."
  log_success "Application source code is up to date."

  if [ "$DEPLOYMENT_MODE" == "development" ]; then
    sudo chown -R "${HOST_USER_ID}:${HOST_GROUP_ID}" "$APP_DIR" && {
      log_success "Application directory ownership updated for development."
    } || handle_error "Failed to change ownership of $APP_DIR to $deployment_user"
  fi

  log_info "Running setup script (./install.sh)..."
  "$PATH_TO_ROOT_REPOSITORY"/install.sh || handle_error "install.sh script failed."
  log_success "Setup script completed successfully."

  log_info "Rebuilding and restarting services with Docker Compose..."
  sudo -u "$REPOSITORY_OWNER" docker compose -f "$PATH_TO_ROOT_REPOSITORY"/docker-compose.yml up -d --build || handle_error "Docker Compose command failed."
  log_success "Application has been updated and restarted successfully!"
}

main "$@"

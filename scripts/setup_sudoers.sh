#!/bin/bash

# This script configures sudoers to allow the current user to run 'chown'
# on the application directory without a password. This is useful for
# development and deployment scripts that need to adjust file ownership.

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
# ------------------------------------

if [ "$EUID" -ne 0 ]; then
  log_error "This script must be run as root or with sudo."
  exit 1
fi

PATH_TO_ROOT_REPOSITORY=$(git rev-parse --show-toplevel)
if [ -z "$PATH_TO_ROOT_REPOSITORY" ]; then
    log_error "Could not determine the root of the git repository. Make sure you are running this script from within the repository."
    exit 1
fi

ENV_FILE_PATH="$PATH_TO_ROOT_REPOSITORY/.env"
if [ ! -f "$ENV_FILE_PATH" ]; then
    log_error ".env file not found at $ENV_FILE_PATH"
    exit 1
fi

# Source .env file to get APP_NAME
set -a
# shellcheck source=/dev/null
source "$ENV_FILE_PATH"
set +a

if [ -z "$APP_NAME" ] || [ "$APP_NAME" == "enter_your_app_name" ]; then
    log_error "APP_NAME is not set or has a default value in your .env file. Please configure it."
    exit 1
fi

RUNNER_USER=${SUDO_USER:-$(whoami)}
APP_DIR="$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME"
CHOWN_PATH=$(which chown)
SUDOERS_FILENAME="90-chown-for-${APP_NAME}"
SUDOERS_FILEPATH="/etc/sudoers.d/${SUDOERS_FILENAME}"

log_info "Configuring sudoers for user '$RUNNER_USER' on directory '$APP_DIR'..."

# The rule allows chown on the app directory and its contents.
# Using '*' for user/group is more flexible than hardcoding HOST_USER_ID from .env
SUDOERS_RULE="$RUNNER_USER ALL=(ALL) NOPASSWD: $CHOWN_PATH -R *:* $APP_DIR"

log_info "Adding the following rule to $SUDOERS_FILEPATH:"
log_info "  $SUDOERS_RULE"

echo "$SUDOERS_RULE" > "$SUDOERS_FILEPATH"
chmod 0440 "$SUDOERS_FILEPATH"

log_success "Sudoers configuration complete. User '$RUNNER_USER' can now run chown on the app directory without a password."

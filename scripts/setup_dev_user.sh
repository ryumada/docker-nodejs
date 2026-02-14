#!/usr/bin/env bash
set -e
# Category: Utility
# Description: Script to create/configure a development user with specific UID/GID in the container environment.
# Usage: sudo ./scripts/setup_dev_user.sh <env_file_path>
# Dependencies: groupadd, useradd, id, getent

# Detect Repository Owner to run non-root commands as that user
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
PATH_TO_ROOT_REPOSITORY=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)
SERVICE_NAME=$(basename "$PATH_TO_ROOT_REPOSITORY")
REPOSITORY_OWNER=$(stat -c '%U' "$PATH_TO_ROOT_REPOSITORY")

# Configuration
ENV_FILE=".env"
UPDATE_SCRIPT="./scripts/update_env_file.sh"
MAX_BACKUPS=3

# --- Logging Functions & Colors ---
# Define colors for log messages
readonly COLOR_RESET="\033[0m"
readonly COLOR_INFO="\033[0;34m"
readonly COLOR_SUCCESS="\033[0;32m"
readonly COLOR_WARN="\033[1;33m"
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
  echo "Please run this script with sudo."
  exit 1
fi

ENV_FILE_PATH="$1"

if [ ! -f "$ENV_FILE_PATH" ]; then
    log_error ".env file not found at $ENV_FILE_PATH"
    exit 1
fi

source "$ENV_FILE_PATH"

log_info "Setting up development user with UID=${HOST_USER_ID} and GID=${HOST_GROUP_ID}..."

# Create group if it doesn't exist
if ! getent group "${HOST_GROUP_ID}" > /dev/null 2>&1; then
    groupadd -g "${HOST_GROUP_ID}" node && {
        log_success "Group 'node' with GID ${HOST_GROUP_ID} created."
    } || {
        log_error "Failed to create group 'node' with GID ${HOST_GROUP_ID}."
        log_warn "If you want to change the UID and GID of the user and group, please remove the user first using 'sudo userdel node'"
    }
fi

# Create user if it doesn't exist
if ! id -u "${HOST_USER_ID}" > /dev/null 2>&1; then
    useradd --shell /bin/bash -u "${HOST_USER_ID}" -g "${HOST_GROUP_ID}" -m node && {
        log_success "User 'node' with UID ${HOST_USER_ID} created."
    } || {
        log_error "Failed to create group 'node' with GID ${HOST_GROUP_ID}."
        log_warn "If you want to change the UID and GID of the user and group, please remove the user first using 'sudo userdel node'"
    }
fi

log_success "Development user setup is complete."

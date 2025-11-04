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
log_output() { log "${COLOR_RESET}" "" "$1"; }
# ------------------------------------

if [ "$EUID" -ne 0 ]; then
  log_error "This script must be run as root or with sudo."
  exit 1
fi

log_output "Do you want to create sudoers for current use or for devops user?"
log_output "1. Current user"
log_output "2. Devops user"
read -rp "Enter your choice [1-2]: " USER_CHOICE

case "$USER_CHOICE" in
  1)
    RUNNER_USER=${SUDO_USER:-$(whoami)}
    log_info "Configuring sudoers for the current user: '$RUNNER_USER'"
    ;;
  2)
    RUNNER_USER="devops"
    log_info "Configuring sudoers for the 'devops' user."
    ;;
  *)
    log_error "Invalid choice. Please enter 1 or 2."
    exit 1
    ;;
esac

# When run with sudo, the context of the original user is needed to find the git repo.
# We determine the script's own directory, then ask git for the repo root from there,
# running the command as the original user.
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PATH_TO_ROOT_REPOSITORY=$(sudo -u "${SUDO_USER:-$(whoami)}" git -C "$SCRIPT_DIR" rev-parse --show-toplevel)
if [ -z "$PATH_TO_ROOT_REPOSITORY" ]; then
    log_error "Could not determine the root of the git repository. Make sure you are running this script from within the repository."
    exit 1
fi
log_info "Repository root found at: $PATH_TO_ROOT_REPOSITORY"
SERVICE_NAME=$(basename "$PATH_TO_ROOT_REPOSITORY")
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

APP_DIR="$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME"
BASH_PATH=$(which bash)
GIT_PATH=$(which git)
CHOWN_PATH=$(which chown)
REPOSITORY_OWNER=$(stat -c '%U' "$PATH_TO_ROOT_REPOSITORY")

CHOWN_SUDOERS_FILENAME="90-chown-for-${SERVICE_NAME}-to-${RUNNER_USER}"
CHOWN_SUDOERS_FILEPATH="/etc/sudoers.d/${CHOWN_SUDOERS_FILENAME}"
log_info "Configuring sudoers for 'chown' on directory '$APP_DIR'..."

# The rule allows chown on the app directory and its contents.
# Using '*' for user/group is more flexible than hardcoding HOST_USER_ID from .env
CHOWN_SUDOERS_RULE="$RUNNER_USER ALL=(ALL) NOPASSWD: $CHOWN_PATH -R *\\:* $APP_DIR/*, $CHOWN_PATH -R *\\:* $APP_DIR"

if [ -f "$CHOWN_SUDOERS_FILEPATH" ] && grep -qF -- "$CHOWN_SUDOERS_RULE" "$CHOWN_SUDOERS_FILEPATH"; then
    log_info "Sudoers 'chown' rule already exists. No changes needed."
else
    log_info "Adding 'chown' rule to $CHOWN_SUDOERS_FILEPATH:"
    log_info "  $CHOWN_SUDOERS_RULE"
    echo "$CHOWN_SUDOERS_RULE" > "$CHOWN_SUDOERS_FILEPATH"
    chmod 0440 "$CHOWN_SUDOERS_FILEPATH"
    log_success "Sudoers 'chown' configuration complete."
fi

# Use a generic filename for the scripts rule, as it's not project-specific.
SCRIPTS_SUDOERS_FILENAME="90-setup-dev-scripts-for-${SERVICE_NAME}-to-${RUNNER_USER}"
SCRIPTS_SUDOERS_FILEPATH="/etc/sudoers.d/${SCRIPTS_SUDOERS_FILENAME}"
log_info "Configuring sudoers for setup scripts..."

# The rules allow running the setup scripts via bash.
# Using a wildcard '*/scripts/...' makes the rule generic across multiple projects.
SCRIPTS_SUDOERS_RULES=(
  "$RUNNER_USER ALL=(ALL) NOPASSWD: $BASH_PATH $PATH_TO_ROOT_REPOSITORY/scripts/setup_sudoers.sh"
  "$RUNNER_USER ALL=(ALL) NOPASSWD: $BASH_PATH $PATH_TO_ROOT_REPOSITORY/scripts/setup_dev_user.sh *"
)

log_info "Adding script rules to $SCRIPTS_SUDOERS_FILEPATH:"
# Clear the file to ensure old/absolute paths are removed before adding new generic ones.
> "$SCRIPTS_SUDOERS_FILEPATH"
for rule in "${SCRIPTS_SUDOERS_RULES[@]}"; do
  log_info "  $rule"
  # Add rule to file if it doesn't exist
  echo "$rule" >> "$SCRIPTS_SUDOERS_FILEPATH"
done

chmod 0440 "$SCRIPTS_SUDOERS_FILEPATH"
log_success "Sudoers script configuration complete."

GIT_SUDOERS_FILENAME="90-git-for-${SERVICE_NAME}-to-${RUNNER_USER}"
GIT_SUDOERS_FILEPATH="/etc/sudoers.d/${GIT_SUDOERS_FILENAME}"
log_info "Configuring sudoers for 'git' commands..."

GIT_SUDOERS_RULES=(
  "$RUNNER_USER ALL=($REPOSITORY_OWNER) NOPASSWD: $GIT_PATH -C $APP_DIR fetch"
  "$RUNNER_USER ALL=($REPOSITORY_OWNER) NOPASSWD: $GIT_PATH -C $APP_DIR pull"
)

log_info "Adding git rules to $GIT_SUDOERS_FILEPATH:"
> "$GIT_SUDOERS_FILEPATH" # Clear the file first
for rule in "${GIT_SUDOERS_RULES[@]}"; do
  log_info "  $rule"
  echo "$rule" >> "$GIT_SUDOERS_FILEPATH"
done

chmod 0440 "$GIT_SUDOERS_FILEPATH"
log_success "Sudoers git configuration complete."

UPDATE_SCRIPT_SUDOERS_FILENAME="90-update-script-for-${SERVICE_NAME}-to-${RUNNER_USER}"
UPDATE_SCRIPT_SUDOERS_FILEPATH="/etc/sudoers.d/${UPDATE_SCRIPT_SUDOERS_FILENAME}"
log_info "Configuring sudoers for 'update_deployment.sh' script..."

UPDATE_SCRIPT_PATH="$PATH_TO_ROOT_REPOSITORY/scripts/update_deployment.sh"
TARGET_UPDATE_USER="devopsadmin"

UPDATE_SCRIPT_SUDOERS_RULE="$RUNNER_USER ALL=($TARGET_UPDATE_USER) NOPASSWD: $UPDATE_SCRIPT_PATH"

log_info "Adding update script rule to $UPDATE_SCRIPT_SUDOERS_FILEPATH:"
log_info "  $UPDATE_SCRIPT_SUDOERS_RULE"
echo "$UPDATE_SCRIPT_SUDOERS_RULE" > "$UPDATE_SCRIPT_SUDOERS_FILEPATH"
chmod 0440 "$UPDATE_SCRIPT_SUDOERS_FILEPATH"
log_success "Sudoers update script configuration complete."

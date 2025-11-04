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

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
PATH_TO_ROOT_REPOSITORY=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)
SERVICE_NAME=$(basename "$PATH_TO_ROOT_REPOSITORY")
REPOSITORY_OWNER=$(stat -c '%U' "$PATH_TO_ROOT_REPOSITORY")

if [ -f "$PATH_TO_ROOT_REPOSITORY/.env" ]; then
  # Source .env file to load its variables into the current shell
  # This makes complex variable substitutions possible
  set -a # automatically export all variables
  # shellcheck source=/dev/null
  source "$PATH_TO_ROOT_REPOSITORY/.env"
  set +a # Stop automatically exporting variables
fi

function update_docker_compose_build_args() {
  # Read the .env file, filter for NEXT_PUBLIC_ variables,
  #    extract just the variable names, and join them with commas.
  #
  #    - `grep -E '^NEXT_PUBLIC_[A-Za-z0-9_]+='`: Filters lines that start with
  #      "NEXT_PUBLIC_" followed by alphanumeric characters/underscores and an equals sign.
  #    - `cut -d '=' -f 1`: Splits each line by '=', and takes the first field (the variable name).
  #    - `paste -sd ',' -`: Joins all the extracted variable names into a single string,
  #      separated by commas.
  LIST_BUILDER_ENV=$(grep -E '^NEXT_PUBLIC_[A-Za-z0-9_]+=' "$ENV_FILE_PATH" | cut -d '=' -f 1 | paste -sd ',' -)
  local ENV_FILE_PATH="$1"

  log_info "Variables to pass as build args: $LIST_BUILDER_ENV"

  local BUILD_ARGS_YAML_FOR_AWK
  BUILD_ARGS_YAML_FOR_AWK=$(echo "$LIST_BUILDER_ENV" | tr ',' '\n' | \
    sed -e 's/.*/        &: ${&}/' | \
    paste -sd'\n' - | \
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\n/\\n/g')

  local FULL_BUILD_BLOCK_FOR_AWK
  FULL_BUILD_BLOCK_FOR_AWK=$(printf "    build:\\n      context: .\\n      args:\\n%s" "${BUILD_ARGS_YAML_FOR_AWK}")

  awk -v block="${FULL_BUILD_BLOCK_FOR_AWK}" '
    BEGIN { flag=0 }
    /^[[:space:]]*build: \.$/ && flag == 0 {
        print block
        flag=1
        next
    }
    { print }
  ' "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml" > "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml.tmp"

  filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml.tmp" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"
  rm "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml.tmp"
  log_success "Successfully added environment variables to docker-compose file: $PATH_TO_ROOT_REPOSITORY/docker-compose.yml"
}

function update_dockerfile_build_args() {
  local DOCKERFILE_ARGS_ENV_BLOCK=""

  IFS=',' read -ra VAR_NAMES <<< "$LIST_BUILDER_ENV"

  for VAR_NAME in "${VAR_NAMES[@]}"; do
    VAR_NAME=$(echo "$VAR_NAME" | xargs)
    if [[ -n "$VAR_NAME" ]]; then
      DOCKERFILE_ARGS_ENV_BLOCK+="ARG ${VAR_NAME}\n"
      DOCKERFILE_ARGS_ENV_BLOCK+="ENV ${VAR_NAME}=\$${VAR_NAME}\n"
    fi
  done

  ESCAPED_DOCKERFILE_BLOCK=$(echo -e "$DOCKERFILE_ARGS_ENV_BLOCK" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\n/\\n/g')

  awk -v block="${ESCAPED_DOCKERFILE_BLOCK}" '
    BEGIN { flag=0 }
    /^FROM / && flag == 0 {
        print # Print the FROM line
        print block # Print the new ARG/ENV block
        flag=1 # Set flag to prevent further insertions
        next # Skip to next line of input
    }
    { print } # Print all other lines as is
  ' "$PATH_TO_ROOT_REPOSITORY/dockerfile" > "$PATH_TO_ROOT_REPOSITORY/dockerfile.tmp"

  rsync -qavzc "$PATH_TO_ROOT_REPOSITORY/dockerfile.tmp" "$PATH_TO_ROOT_REPOSITORY/dockerfile"
  rm "$PATH_TO_ROOT_REPOSITORY/dockerfile.tmp"
  log_success "Successfully added environment variables to dockerfile: $PATH_TO_ROOT_REPOSITORY/dockerfile"
}

function filesubstitution() {
  local env_file_path=$1
  local template_file=$2
  local result_file=$3

  log_info "Reading variables from ${env_file_path} to prepare for substitution..."
  # Create a string of 'sed' expressions. Example: s|\${VAR1}|val1|g;s|\${VAR2}|val2|g;
  local SED_EXPRESSIONS=""
  local sed_args=()

  # Read variables again for simple replacement
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    # Ignore blank lines and comments
    if [[ -n "$key" && ! "$key" =~ ^# ]]; then
      # Escape characters that are special to sed's replacement string
      # This handles characters like /, &, etc. safely.
      value_escaped=$(printf '%s\n' "$value" | sed -e 's/[&\\/]/\\&/g')

      # Add a complete '-e' argument to our array for each variable
      sed_args+=(-e "s|\${${key}}|${value_escaped}|g")
    fi
  done < "$env_file_path"

  # --- Step 3: Find and process compose files ---
  # log_info "Finding and processing all 'docker-compose.yml' files..."
  # find "$PATH_TO_ROOT_REPOSITORY" -type f -name "docker-compose.yml.example" | while read -r template_file; do
    # local DIR
    # DIR=$(dirname "$template_file")

    log_info "Processing -> ${template_file}"

    # Execute sed with the array of expressions. The shell will expand the array safely.
    sed "${sed_args[@]}" "$template_file" > "$result_file"
    chown "$REPOSITORY_OWNER": "$result_file"

    log_success "  └─ Created deployable file: ${result_file}"
  # done
}

function main() {
  ENV_FILE_PATH="$PATH_TO_ROOT_REPOSITORY/.env"

  # Merge .env.example files from app directory and current directory
  cat "$PATH_TO_ROOT_REPOSITORY/.env.example" > "$PATH_TO_ROOT_REPOSITORY/.env.example.merge"
  echo "" >> "$PATH_TO_ROOT_REPOSITORY/.env.example.merge"
  if [ -n "$APP_NAME" ] && [ "$APP_NAME" != "enter_your_app_name" ]; then
    cat "$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME/.env.example" >> "$PATH_TO_ROOT_REPOSITORY/.env.example.merge"
    echo "" >> "$PATH_TO_ROOT_REPOSITORY/.env.example.merge"
  else
    log_error "Please setup APP_NAME variable in your .env file. Then, re-run this script."
  fi

  log_info "Update env file."
  "$PATH_TO_ROOT_REPOSITORY/scripts/update_env_file.sh" "$PATH_TO_ROOT_REPOSITORY/.env.example.merge"
  log_success "Update env file completed"

  log_info "Validate .env file content"
  if grep -q "enter_" "$ENV_FILE_PATH"; then
    log_error "Your .env file still contains default placeholder values."
    grep "enter_" "$ENV_FILE_PATH" | while read -r line ; do
      log_error "  - Please configure: ${line}"
    done
    log_error "Exiting. Please update the .env file and re-run the script again."
    exit 1
  fi
  log_success "Validate .env file content completed"

  if [ "$DEPLOYMENT_MODE" == "development" ]; then
    log_info "Setting up for DEVELOPMENT mode..."

    if [[ "${RUN_SUDOERS_SETUP}" == "Y" || "${RUN_SUDOERS_SETUP}" == "y" ]]; then
      log_warn "RUN_SUDOERS_SETUP is set to 'Y'. Running privileged setup scripts. This may ask for your password."

      sudo bash "$PATH_TO_ROOT_REPOSITORY/scripts/setup_sudoers.sh"
      log_success "Sudoers setup complete."

      sudo bash "$PATH_TO_ROOT_REPOSITORY/scripts/setup_dev_user.sh" "$ENV_FILE_PATH"
      log_success "Dev user setup complete."
    fi

    log_info "Changing ownership of app directory to dev user..."
    sudo chown -R "${HOST_USER_ID}:${HOST_GROUP_ID}" "$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME"
    log_success "App directory ownership updated."

    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/dockerfile.dev.example" "$PATH_TO_ROOT_REPOSITORY/dockerfile"
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml.example" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/dockerfile.lockfile-generator.example" "$PATH_TO_ROOT_REPOSITORY/dockerfile.lockfile-generator"

    # Add volume mount for development
    # The second volume for /usr/src/app/node_modules is an anonymous volume.
    # It prevents the host's empty node_modules from overwriting the container's node_modules.
    sed -i '/build:/a \    volumes:\n      - ./app/${APP_NAME}:/usr/src/app\n      - /usr/src/app/node_modules' "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"
    sed -i 's/command: npm start/command: npm run dev/' "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"

    log_success "Development setup: Added volume mount and updated command in docker-compose.yml."

    update_docker_compose_build_args "$ENV_FILE_PATH"
    update_dockerfile_build_args

  else
    log_info "Setting up for PRODUCTION mode (standard build)..."
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/dockerfile.example" "$PATH_TO_ROOT_REPOSITORY/dockerfile"
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml.example" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/dockerfile.lockfile-generator.example" "$PATH_TO_ROOT_REPOSITORY/dockerfile.lockfile-generator"

    update_docker_compose_build_args "$ENV_FILE_PATH"
    update_dockerfile_build_args
  fi

  echo ""
  log_success "Setup finished."
}

main "$@"

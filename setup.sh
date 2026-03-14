#!/usr/bin/env bash
# Category: Entrypoint
# Description: Main setup script to configure environments (dev/prod/init) and manage container configs.
# Usage: ./setup.sh
# Dependencies: git, docker, rsync, awk, ./scripts/utility/update_env_file.sh, ./scripts/generate_map.sh

# Detect Repository Owner to run non-root commands as that user
set -e
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
# Only use sudo if the current user differs from the file owner
if [ "$(whoami)" = "$CURRENT_DIR_USER" ]; then
  PATH_TO_ROOT_REPOSITORY=$(git -C "$CURRENT_DIR" rev-parse --show-toplevel)
else
  PATH_TO_ROOT_REPOSITORY=$(sudo -u "$CURRENT_DIR_USER" git -C "$CURRENT_DIR" rev-parse --show-toplevel)
fi
SERVICE_NAME=$(basename "$PATH_TO_ROOT_REPOSITORY")
REPOSITORY_OWNER=$(stat -c '%U' "$PATH_TO_ROOT_REPOSITORY")

# Configuration
ENV_FILE=".env"
UPDATE_SCRIPT="./scripts/utility/update_env_file.sh"
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
  # Use awk to format the build args block. This avoids non-portable sed escaping of newlines.
  BUILD_ARGS_YAML_FOR_AWK=$(echo "$LIST_BUILDER_ENV" | tr ',' '\n' | awk '
    {
      line = "        " $0 ": ${" $0 "}"
      gsub(/\\/, "\\\\", line)
      gsub(/"/, "\\\"", line)
      if (NR > 1) { printf "\\n" }
      printf "%s", line
    }')

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

  # Escape backslashes and quotes, and convert actual newlines to \n characters for awk variable injection.
  ESCAPED_DOCKERFILE_BLOCK=$(printf "%b" "$DOCKERFILE_ARGS_ENV_BLOCK" | awk '
    {
      gsub(/\\/, "\\\\")
      gsub(/"/, "\\\"")
      if (NR > 1) { printf "\\n" }
      printf "%s", $0
    }')

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

function configure_proxy_mode() {
  local compose_file="$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"

  if [[ "$PROXY_MODE" == "traefik" ]]; then
    log_info "Configuring Traefik proxy mode..."

    # Define the Traefik labels block using a Heredoc.
    # We allow the shell to expand the variables here so they are hardcoded 
    # in the final compose file, matching the repository's substitution pattern.
    export LABELS_BLOCK
    LABELS_BLOCK=$(cat <<EOF
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${APP_NAME}.rule=Host(\`${DOMAIN}\`)"
      - "traefik.http.routers.${APP_NAME}.entrypoints=websecure"
      - "traefik.http.routers.${APP_NAME}.tls.certresolver=${TRAEFIK_CERTRESOLVER}"
      - "traefik.http.services.${APP_NAME}.loadbalancer.server.port=${PORT}"
EOF
)
    export PROXY_NETWORK_LINE="      - ${PROXY_NETWORK}"

    # Use awk to inject the block and the network placeholder.
    # Accessing variables via ENVIRON is the most robust cross-platform approach.
    awk '
      {
        if ($0 ~ /# PROXY_LABELS_PLACEHOLDER/) {
          print ENVIRON["LABELS_BLOCK"]
        } else if ($0 ~ /# PROXY_NETWORK_PLACEHOLDER/) {
          print ENVIRON["PROXY_NETWORK_LINE"]
        } else {
          print $0
        }
      }
    ' "$compose_file" > "${compose_file}.tmp"
    mv "${compose_file}.tmp" "$compose_file"

    # Append the external proxy network definition to the bottom.
    printf "\n  ${PROXY_NETWORK}:\n    external: true\n" >> "$compose_file"

    log_success "Traefik configuration injected successfully."
  else
    # Clean up the placeholders if PROXY_MODE is not 'traefik'
    awk '!/# PROXY_LABELS_PLACEHOLDER/ && !/# PROXY_NETWORK_PLACEHOLDER/' "$compose_file" > "${compose_file}.tmp"
    mv "${compose_file}.tmp" "$compose_file"
  fi
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
    if [ -d "$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME" ] && [ -f "$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME/.env.example" ]; then
      cat "$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME/.env.example" >> "$PATH_TO_ROOT_REPOSITORY/.env.example.merge"
      echo "" >> "$PATH_TO_ROOT_REPOSITORY/.env.example.merge"
    else
        log_warn "App directory or .env.example not found. Skipping merge of app .env.example."
    fi
  else
    log_error "Please setup APP_NAME variable in your .env file. Then, re-run this script."
  fi

  log_info "Update env file."
  "$PATH_TO_ROOT_REPOSITORY/scripts/utility/update_env_file.sh" "$PATH_TO_ROOT_REPOSITORY/.env.example.merge"
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

    # Add volume mount for development.
    # We use awk to handle the multi-line injection and command update portably.
    local volumes_block="    volumes:
      - ./app/\${APP_NAME}:/usr/src/app
      - /usr/src/app/node_modules"

    awk -v block="$volumes_block" '
      {
        print $0
        if ($0 ~ /^[[:space:]]*build: \.$/) {
          print block
        }
      }
    ' "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml" | \
    sed "s/command: npm start/command: npm run dev/" > "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml.tmp"

    mv "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml.tmp" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"

    log_success "Development setup: Added volume mount and updated command in docker-compose.yml."

    update_docker_compose_build_args "$ENV_FILE_PATH"
    update_dockerfile_build_args

  elif [ "$DEPLOYMENT_MODE" == "initialization" ]; then
    log_info "Setting up for INITIALIZATION mode..."

    # In initialization mode, we check if the app folder exists, if not we create it
    if [ ! -d "$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME" ]; then
        log_info "App directory 'app/$APP_NAME' not found. Creating it..."
        mkdir -p "$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME"
        # Ensure ownership is correct immediately
        chown "$HOST_USER_ID:$HOST_GROUP_ID" "$PATH_TO_ROOT_REPOSITORY/app/$APP_NAME"
        log_success "Created directory: app/$APP_NAME"
    fi

    # In initialization mode, we might not have the app folder yet, so we just setup the container
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/dockerfile.init.example" "$PATH_TO_ROOT_REPOSITORY/dockerfile"
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/docker-compose.init.yml.example" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"

    update_dockerfile_build_args
    # typically no build args needed for init, but good to keep consistent if we added any

  else
    log_info "Setting up for PRODUCTION mode (standard build)..."
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/dockerfile.example" "$PATH_TO_ROOT_REPOSITORY/dockerfile"
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml.example" "$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"
    filesubstitution "$ENV_FILE_PATH" "$PATH_TO_ROOT_REPOSITORY/dockerfile.lockfile-generator.example" "$PATH_TO_ROOT_REPOSITORY/dockerfile.lockfile-generator"

    update_docker_compose_build_args "$ENV_FILE_PATH"
    update_dockerfile_build_args
  fi

  configure_proxy_mode

  echo ""
  log_success "Setup finished."
}

main "$@"

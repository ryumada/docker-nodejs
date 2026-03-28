#!/usr/bin/env bash
# Category: Entrypoint
# Description: Helper script to run commands inside the 'app' service container.
# Usage: ./scripts/bootstraping/run.sh <command>
# Dependencies: docker, git

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

# Fallback if git fails (e.g. if we are in a subdirectory but not a git repo, which is unlikely)
if [ -z "$PATH_TO_ROOT_REPOSITORY" ]; then
    # Try to go up two levels from scripts/bootstraping
    PATH_TO_ROOT_REPOSITORY=$(readlink -f "$SCRIPT_DIR/../..")
fi

DOCKER_COMPOSE_FILE="$PATH_TO_ROOT_REPOSITORY/docker-compose.yml"

if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo "Error: docker-compose.yml not found at $DOCKER_COMPOSE_FILE"
    exit 1
fi

# Service name is 'app' based on our templates.
# If you need to make this dynamic, you could grep it or pass it as an arg.
SERVICE_NAME="app"

# Check if arguments were provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <command>"
    echo "Example: $0 npm install"
    exit 1
fi

# Execute the command inside the running container
# Always use -T to prevent hanging in non-interactive contexts (e.g., AI agent execution)

echo "Running in container '$SERVICE_NAME': $*"
# shellcheck disable=SC2086
docker compose -f "$DOCKER_COMPOSE_FILE" exec -T "$SERVICE_NAME" "$@"

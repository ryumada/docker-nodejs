#!/bin/bash

# --- Helper Script for Running Commands inside Docker ---
# This script finds the root of the repository, locates the docker-compose.yml file,
# and executes the provided command inside the 'app' service.

# Get the directory where this script is located
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Find the repository root (assuming git is initialized)
# If git is not present or we are not in a git repo, we might need a fallback.
# For now, relying on git rev-parse is standard in this project's setup.sh.
PATH_TO_ROOT_REPOSITORY=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)

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
# -T disables pseudo-tty allocation (useful for some automation, but for interactive usage we might want basic exec)
# But standard 'exec' is interactive if you don't redirect stdin.
# Let's just use simple arguments forwarding.

echo "Running in container '$SERVICE_NAME': $*"
docker compose -f "$DOCKER_COMPOSE_FILE" exec "$SERVICE_NAME" "$@"

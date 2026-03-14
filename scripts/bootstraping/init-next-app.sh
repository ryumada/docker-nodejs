#!/usr/bin/env bash
# Category: Utility
# Description: Helper script to initialize a Next.js app in a Docker volume root.
# Usage: ./scripts/bootstraping/init-next-app.sh [args...]
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

RUN_SCRIPT="$CURRENT_DIR/run.sh"

if [ ! -f "$RUN_SCRIPT" ]; then
    echo "Error: run.sh not found at $RUN_SCRIPT"
    exit 1
fi

echo "Initializing Next.js app..."
echo "Note: Using temporary directory strategy to bypass Docker volume permission checks."

# Default arguments if none provided, but allow user override
if [ $# -eq 0 ]; then
    # Default: Create Next.js app in temp dir with standard flags
    "$RUN_SCRIPT" npx create-next-app@latest temp --typescript --tailwind --eslint --src-dir --app --import-alias "@/*"
else
    # User provided arguments (must still create in 'temp' for the move step to work)
    "$RUN_SCRIPT" "$@"
fi

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "Error: Failed to create app in temp directory."
    exit $EXIT_CODE
fi

# 2. Move files to root (.) and clean up 'temp'
echo "Moving files to application root..."
"$RUN_SCRIPT" sh -c "cp -a temp/. . && rm -rf temp"

echo "Next.js app initialized successfully!"

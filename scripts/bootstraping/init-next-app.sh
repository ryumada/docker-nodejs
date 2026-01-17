#!/bin/bash

# --- Helper to initialize Next.js app in Docker ---
# Usage: ./scripts/bootstraping/init-next-app.sh [args...]
#
# WHY THIS SCRIPT EXISTS:
# Running 'create-next-app' directly in the root of a Docker volume mount (e.g., 'npx create-next-app .')
# often fails with a "The application path is not writable" error, even if the user has correct permissions.
# This is a known issue with how the tool checks permissions on volume roots.
#
# Workaround:
# 1. Create the app in a temporary subdirectory (where the check succeeds).
# 2. Move the files to the root directory.
# 3. Clean up.

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
RUN_SCRIPT="$SCRIPT_DIR/run.sh"

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

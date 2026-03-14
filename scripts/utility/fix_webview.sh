#!/usr/bin/env bash
# Category: Utility
# Description: Clears Antigravity/VS Code webview and Service Worker caches to resolve registration errors.
# Usage: ./scripts/utility/fix_webview.sh
# Dependencies: sudo, rm, killall

# Detect Repository Owner to run non-root commands as that user
set -e
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
PATH_TO_ODOO=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)
SERVICE_NAME=$(basename "$PATH_TO_ODOO")
REPOSITORY_OWNER=$(stat -c '%U' "$PATH_TO_ODOO")

# Configuration
# Path to Antigravity configuration directory
ANTIGRAVITY_CONFIG_DIR="$HOME/.config/Antigravity"
CODE_CONFIG_DIR="$HOME/.config/Code"

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

log_info "Starting Antigravity Webview fix process..."

# 1. Close Antigravity/Code if running
if pgrep -Ei "antigravity|code" > /dev/null; then
  log_warn "Antigravity/Code processes detected. Please close the IDE to ensure cache clearing is effective."
  log_info "You might need to run: pkill -9 antigravity"
fi

# 2. Identify and clear cache directories
clear_cache() {
  local dir="$1"
  local name="$2"

  if [ -d "$dir" ]; then
    log_info "Clearing cache for $name in $dir..."

    # Common Electron cache directories
    local sub_dirs=("Cache" "CachedData" "GPUCache" "Service Worker/CacheStorage" "Service Worker/ScriptCache" "Webview")

    for sub in "${sub_dirs[@]}"; do
      if [ -d "$dir/$sub" ]; then
        log_info "Removing $dir/$sub..."
        rm -rf "$dir/$sub"
      fi
    done
    log_success "$name cache directories processed."
  else
    log_warn "$name config directory not found at $dir."
  fi
}

clear_cache "$ANTIGRAVITY_CONFIG_DIR" "Antigravity"
clear_cache "$CODE_CONFIG_DIR" "VS Code"

log_success "Cache clearing completed."

log_info "Recommendation:"
log_info "1. Close Antigravity completely if it's still open."
log_info "2. Restart Antigravity."
log_info "3. If the error persists, try launching with no-sandbox: antigravity --no-sandbox"

exit 0

#!/usr/bin/env bash
set -e
# Category: Config
# Description: Sets up Nginx security and performance configuration for Node.js / Next.js.
# Usage: ./nginx-configurations/setup_nginx_security_conf.sh
# Dependencies: sudo, cat, git, stat

# Detect Repository Owner to run non-root commands as that user
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
PATH_TO_ROOT_REPOSITORY=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)
SERVICE_NAME=$(basename "$PATH_TO_ROOT_REPOSITORY")
REPOSITORY_OWNER=$(stat -c '%U' "$PATH_TO_ROOT_REPOSITORY")

# Configuration
ENV_FILE=".env"
MAX_BACKUPS=3

# --- Logging Functions & Colors ---
readonly COLOR_RESET="\033[0m"
readonly COLOR_INFO="\033[0;34m"
readonly COLOR_SUCCESS="\033[0;32m"
readonly COLOR_WARN="\033[1;33m"
readonly COLOR_ERROR="\033[0;31m"

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

error_handler() {
  local exit_code=$1
  local line_no=$2
  local command_name=$3
  log_error "An error occurred on line $line_no."
  log_error "Exit Code: $exit_code"
  log_error "Command: $command_name"
  exit "$exit_code"
}

trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR

# Self-elevate to root if not already
if [ "$(id -u)" -ne 0 ]; then
  log_info "Elevating permissions to root..."
  # shellcheck disable=SC2093
  exec sudo "$0" "$@"
  log_error "Failed to elevate to root. Please run with sudo."
  exit 1
fi

log_info "Creating Nginx security configuration for Node.js / Next.js..."

TEMP_CONF=$(mktemp)

cleanup() {
  if [ -n "$TEMP_CONF" ] && [ -f "$TEMP_CONF" ]; then
    rm -f "$TEMP_CONF"
  fi
}
trap cleanup EXIT

cat << 'EOF' > "$TEMP_CONF"
##
# Security & Performance Settings for Node.js / Next.js
##

# General API rate-limiting zones
limit_req_zone $binary_remote_addr zone=api_limit:20m rate=10r/s;
limit_conn_zone $binary_remote_addr zone=addr_limit:25m;

# Client buffer sizes optimized for Node.js workloads
client_body_buffer_size         4096k;
client_header_buffer_size       16k;
large_client_header_buffers     8 128k;

# Save large request bodies to temp path if needed
client_body_in_file_only off;
client_body_temp_path /var/tmp/nginx;

# Maximum payload size for file uploads
client_max_body_size            500M;

keepalive_timeout               3600s;
tcp_nodelay                     on;

# DNS resolvers for OCSP / upstream lookups
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Clickjacking protection
add_header X-Frame-Options "SAMEORIGIN";

# Prevent browser from accepting insecure SSL certificates (HSTS)
add_header Strict-Transport-Security "max-age=31536000; includeSubdomains; preload" always;

# Prevent MIME type sniffing
add_header X-Content-Type-Options "nosniff";

# Referrer Policy
add_header Referrer-Policy "strict-origin-when-cross-origin";

EOF

DEST_FILE="/etc/nginx/conf.d/01-sudo-nginx-security.conf"
DEST_DIR="$(dirname "$DEST_FILE")"

if [ ! -d "$DEST_DIR" ]; then
  log_info "Creating Nginx configuration directory: $DEST_DIR..."
  mkdir -p "$DEST_DIR"
fi

log_info "Installing configuration to $DEST_FILE"
mv "$TEMP_CONF" "$DEST_FILE"
chown root:root "$DEST_FILE"
chmod 644 "$DEST_FILE"

log_success "Nginx security configuration installed successfully."
log_info "You may need to reload nginx for changes to take effect: sudo systemctl reload nginx"

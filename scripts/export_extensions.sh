#!/bin/bash

# Detect Repository Owner to run non-root commands as that user
set -e
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
if [ "$(whoami)" = "$CURRENT_DIR_USER" ]; then
  PATH_TO_ROOT_REPOSITORY=$(git -C "$CURRENT_DIR" rev-parse --show-toplevel)
else
  PATH_TO_ROOT_REPOSITORY=$(sudo -u "$CURRENT_DIR_USER" git -C "$CURRENT_DIR" rev-parse --show-toplevel)
fi

# Configuration
EXPORT_DIR="${PATH_TO_ROOT_REPOSITORY}/exports/extensions"
LIST_FILE="${PATH_TO_ROOT_REPOSITORY}/exports/extensions_list.txt"
mkdir -p "$EXPORT_DIR"

# --- Logging Functions & Colors ---
readonly COLOR_RESET="\033[0m"
readonly COLOR_INFO="\033[0;34m"
readonly COLOR_SUCCESS="\033[0;32m"
readonly COLOR_WARN="\033[1;33m"
readonly COLOR_ERROR="\033[0;31m"

log() { local color="$1"; local emoji="$2"; local message="$3"; echo -e "${color}[$(date +"%Y-%m-%d %H:%M:%S")] ${emoji} ${message}${COLOR_RESET}"; }
log_info() { log "${COLOR_INFO}" "ℹ️" "$1"; }
log_success() { log "${COLOR_SUCCESS}" "✅" "$1"; }
log_warn() { log "${COLOR_WARN}" "⚠️" "$1"; }
log_error() { log "${COLOR_ERROR}" "❌" "$1"; }
# ------------------------------------

log_info "Starting extension export process..."

if [[ ! -f "$LIST_FILE" ]]; then
  log_error "List file not found: $LIST_FILE"
  exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  # Format: publisher.extension@version
  if [[ $line =~ ^([^.]+)\.([^@]+)@(.+)$ ]]; then
    PUBLISHER="${BASH_REMATCH[1]}"
    EXTENSION="${BASH_REMATCH[2]}"
    VERSION="${BASH_REMATCH[3]}"
    ID="${PUBLISHER}.${EXTENSION}"
    FILE_NAME="${ID}-${VERSION}.vsix"
    TARGET_PATH="${EXPORT_DIR}/${FILE_NAME}"

    log_info "Processing ${ID}@${VERSION}..."

    # Method 1: Download from Marketplace
    URL="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${PUBLISHER}/vsextensions/${EXTENSION}/${VERSION}/vspackage"
    
    log_info "Attempting to download from Marketplace..."
    if curl -sL -f -o "$TARGET_PATH" "$URL"; then
      log_success "Successfully exported ${FILE_NAME} (Marketplace)"
    else
      log_warn "Marketplace download failed for ${ID}. Checking local installation..."
      
      # Method 2: Check local installation (approximate folder name)
      LOCAL_EXT_DIR=$(find ~/.vscode/extensions/ -maxdepth 1 -name "${PUBLISHER}.${EXTENSION}-${VERSION}*" | head -n 1)
      
      if [[ -d "$LOCAL_EXT_DIR" ]]; then
        log_info "Found local extension folder: $(basename "$LOCAL_EXT_DIR"). Attempting to package..."
        # Note: Packaging locally requires 'vsce'. We use npx.
        if npx -y @vscode/vsce package --out "$TARGET_PATH" -C "$LOCAL_EXT_DIR" &>/dev/null; then
          log_success "Successfully exported ${FILE_NAME} (Local Package)"
        else
          log_error "Failed to export ${ID} both via Marketplace and local packaging."
          rm -f "$TARGET_PATH" # Cleanup failed download/package
        fi
      else
        log_error "Extension ${ID}@${VERSION} not found in Marketplace or local extensions folder."
      fi
    fi
  else
    log_warn "Skipping invalid line: $line"
  fi
done < "$LIST_FILE"

log_success "Extension export process completed."
log_info "Results are available in: ${EXPORT_DIR}"

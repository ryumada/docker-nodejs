#!/usr/bin/env bash
set -e

# ==============================================================================
# ENVIRONMENT & PATH RESOLUTION
# ==============================================================================

# Resolve the directory where the script is located
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")

# Resolve the Project Root (One level up from scripts/)
PROJECT_ROOT=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)

# Define Output File
OUTPUT_FILE="${PROJECT_ROOT}/REPO_MAP.md"

# ==============================================================================
# LOGGING UTILITIES (User Provided)
# ==============================================================================

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

# Required for executeCommand to print raw output without timestamps/colors
log_output() {
    echo "$1"
}

# ==============================================================================
# CORE EXECUTION FUNCTION
# ==============================================================================

executeCommand() {
    local description="$1"
    local command_to_run="$2"
    local success_message="$3"
    local failure_message="$4"

    log_info "Starting: ${description}..."

    local output
    local exit_code=0

    # Execute command, capture both stdout and stderr
    # redirect stderr to stdout to capture everything in variable 'output'
    if ! output=$(eval "$command_to_run" 2>&1); then
        exit_code=1
    fi

    if [ $exit_code -eq 0 ]; then
        log_success "${success_message}"
    else
        log_error "${failure_message}"
        log_output "${output}"
        # Strict error handling: exit immediately on failure
        exit 1
    fi
}

# ==============================================================================
# MAIN SCRIPT
# ==============================================================================

# Directories to always include even if in .gitignore (e.g., "app" "docs")
FORCE_INCLUDE=("app")

# 1. Check for Prerequisites & Compatibility
# ------------------------------------------------------------------------------
command_check="command -v tree >/dev/null 2>&1 && command -v git >/dev/null 2>&1"
executeCommand \
    "Checking for 'tree' and 'git' utilities" \
    "$command_check" \
    "Prerequisites found." \
    "Missing dependencies. Please install 'tree' and ensure 'git' is available."

# 2. Identify and Filter Files
# ------------------------------------------------------------------------------
log_info "Identifying files to map (Forced Inclusion: ${FORCE_INCLUDE[*]})..."

FILE_LIST_RAW=$(mktemp)
FILE_LIST_FILTERED=$(mktemp)
# Ensure temporary files are cleaned up
trap 'rm -f "$FILE_LIST_RAW" "$FILE_LIST_FILTERED"' EXIT

# Collect tracked files
git -C "${PROJECT_ROOT}" ls-files > "$FILE_LIST_RAW"

# Collect files from forced directories
for dir in "${FORCE_INCLUDE[@]}"; do
    if [ -d "${PROJECT_ROOT}/$dir" ]; then
        # find relative to PROJECT_ROOT, excluding node_modules and .git
        (cd "${PROJECT_ROOT}" && find "$dir" -type f ! -path '*/.*' ! -path '*/node_modules/*' ! -path '*/.next/*') >> "$FILE_LIST_RAW"
    fi
done

# Filter out duplicates, non-files, and binary files
sort -u "$FILE_LIST_RAW" | while read -r file; do
    full_path="${PROJECT_ROOT}/$file"
    if [ -f "$full_path" ] && grep -qI . "$full_path" 2>/dev/null; then
        echo "$file" >> "$FILE_LIST_FILTERED"
    fi
done

log_success "Total files identified for mapping: $(wc -l < "$FILE_LIST_FILTERED")"

# 3. Initialize Output File & TOC
# ------------------------------------------------------------------------------
log_info "Initializing ${OUTPUT_FILE}..."

cat <<EOF > "${OUTPUT_FILE}"
# Repository Map

Generated at: $(date)

## Table of Contents
1. [Directory Structure](#directory-structure)
2. [File Signatures](#file-signatures)

## Directory Structure
\`\`\`
EOF

# Append Tree Structure using the filtered file list
# --fromfile reads paths from stdin and builds a tree
# We do NOT use -C here to avoid ANSI escape sequences
(cd "${PROJECT_ROOT}" && tree --fromfile . < "$FILE_LIST_FILTERED") >> "${OUTPUT_FILE}"

echo -e "\`\`\`\n" >> "${OUTPUT_FILE}"

# 4. Extract File Signatures (Content Context)
# ------------------------------------------------------------------------------
log_info "Extracting file signatures..."

echo "## File Signatures" >> "${OUTPUT_FILE}"

while read -r file; do
    full_path="${PROJECT_ROOT}/$file"
    
    # Append signature section
    echo "### $file" >> "${OUTPUT_FILE}"
    echo '```' >> "${OUTPUT_FILE}"
    
    # Get file info
    filesize=$(du -h "$full_path" | cut -f1)
    echo "// Size: $filesize" >> "${OUTPUT_FILE}"
    
    # Extract first 5 lines
    head -n 5 "$full_path" >> "${OUTPUT_FILE}"
    echo -e '\`\`\`\n' >> "${OUTPUT_FILE}"
done < "$FILE_LIST_FILTERED"

log_success "File signatures extracted and appended."

# 5. Final Verification
# ------------------------------------------------------------------------------
finalize_cmd="ls -lh \"${OUTPUT_FILE}\""
executeCommand \
    "Verifying output file" \
    "$finalize_cmd" \
    "Repository Map successfully created at: ${OUTPUT_FILE}" \
    "Output file verification failed."

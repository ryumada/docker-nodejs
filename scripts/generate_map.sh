#!/usr/bin/env bash
set -e
# Description: Generates a REPO_MAP.md file representing the project structure and file signatures.
# Usage: ./scripts/generate_map.sh
# Dependencies: tree, git, grep, sed, awk

# ==============================================================================

# Resolve the directory where the script is located
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")

# Resolve the Project Root (One level up from scripts/)
PROJECT_ROOT=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)

# Define Output File
OUTPUT_FILE="${PROJECT_ROOT}/REPO_MAP.md"

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Directories to always include even if in .gitignore (e.g., "app" "docs")
FORCE_INCLUDE=("app")

# Files or Patterns to ALWAYS exclude from the map, regardless of source.
# Uses standard bash glob patterns.
FORCE_EXCLUDE=(
    ".agent"
    ".vscode"
    "node_modules"
    ".next"
    ".cache"
    ".git"
    "*.tsbuildinfo"
    "package-lock.json"
    "yarn.lock"
    "pnpm-lock.yaml"
    "*.log"
    "*.map"
    "*.lock"
    "__pycache__"
)

# Files or Patterns to exclude ONLY from the signature extraction phase.
# Use this for large assets, images, or files where the signature isn't helpful.
FORCE_EXCLUDE_SIGNATURE=(
    "*.png"
    "*.svg"
    "*.ico"
    "*.jpg"
    "*.jpeg"
    "*.webp"
    "*.woff"
    "*.woff2"
    "*.ttf"
    "*.otf"
)

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

# 1. Check for Prerequisites
# ------------------------------------------------------------------------------
command_check="command -v tree >/dev/null 2>&1 && command -v git >/dev/null 2>&1"
executeCommand \
    "Checking for 'tree' and 'git' utilities" \
    "$command_check" \
    "Prerequisites found." \
    "Missing dependencies. Please install 'tree' and ensure 'git' is available."

# 2. Identify and Filter Files
# ------------------------------------------------------------------------------
log_info "Identifying files to map..."
log_info "Force Include: ${FORCE_INCLUDE[*]}"
log_info "Force Exclude: ${FORCE_EXCLUDE[*]}"

FILE_LIST_RAW=$(mktemp)
FILE_LIST_FILTERED=$(mktemp)
# Ensure temporary files are cleaned up
trap 'rm -f "$FILE_LIST_RAW" "$FILE_LIST_FILTERED"' EXIT

# A. Collect files from the Root Project (Respects Root .gitignore)
git -C "${PROJECT_ROOT}" ls-files > "$FILE_LIST_RAW"

# B. Collect files from Forced Directories (Smart Handling)
for dir in "${FORCE_INCLUDE[@]}"; do
    full_dir_path="${PROJECT_ROOT}/${dir}"

    if [ -d "$full_dir_path" ]; then
        if [ -d "$full_dir_path/.git" ]; then
            log_info "Detected nested git repository in: ${dir}"
            # List files using the NESTED git, prepending the directory name
            git -C "$full_dir_path" ls-files | awk -v prefix="$dir/" '{print prefix $0}' >> "$FILE_LIST_RAW"
        else
            # Build find exclusion arguments dynamically from FORCE_EXCLUDE
            FIND_EXCLUDE_ARGS=()
            for pattern in "${FORCE_EXCLUDE[@]}"; do
                if [[ "$pattern" == *"*"* ]]; then
                    FIND_EXCLUDE_ARGS+=("-not" "-name" "$pattern" "-not" "-path" "*/$pattern")
                else
                    FIND_EXCLUDE_ARGS+=("-not" "-path" "*/$pattern/*" "-not" "-name" "$pattern")
                fi
            done

            # Manual find for non-git folders (Includes hidden files, excludes patterns in FORCE_EXCLUDE)
            (cd "${PROJECT_ROOT}" && find "$dir" -type f "${FIND_EXCLUDE_ARGS[@]}") >> "$FILE_LIST_RAW"
        fi
    fi
done

# C. Clean, Filter, and Sort
# We iterate over the raw list and apply the FORCE_EXCLUDE logic here.
# This ensures that exclusions apply to BOTH git-tracked files and forced files.
sort -u "$FILE_LIST_RAW" | while read -r file; do
    full_path="${PROJECT_ROOT}/$file"
    filename=$(basename "$file")

    # 1. Check Exclusions (The "Gatekeeper")
    should_exclude=0
    for pattern in "${FORCE_EXCLUDE[@]}"; do
        if [[ "$pattern" == *"*"* ]]; then
             # Glob pattern (e.g., *.log): match against filename or full path
             if [[ "$filename" == $pattern ]] || [[ "$file" == $pattern ]]; then
                 should_exclude=1
                 break
             fi
        else
             # Exact match or Directory (e.g., node_modules): match against filename or anywhere in path
             if [[ "$filename" == "$pattern" ]] || [[ "$file" == *"/$pattern/"* ]] || [[ "$file" == "$pattern/"* ]] || [[ "$file" == *"/$pattern" ]]; then
                 should_exclude=1
                 break
             fi
        fi
    done

    if [ $should_exclude -eq 1 ]; then
        continue
    fi

    # 2. Check Validity
    if [ -f "$full_path" ]; then
        echo "$file" >> "$FILE_LIST_FILTERED"
    fi
done

log_success "Total files identified for mapping: $(wc -l < "$FILE_LIST_FILTERED")"

# 3. Initialize Output File & TOC
# ------------------------------------------------------------------------------
log_info "Initializing ${OUTPUT_FILE}..."

cat <<EOF > "${OUTPUT_FILE}"
---
title: Repository Map
description: Auto-generated project structure and file signatures map.
context: Project Root
---

## Table of Contents
EOF

cat <<EOF >> "${OUTPUT_FILE}"
1. [Directory Structure](#directory-structure)
2. [File Signatures](#file-signatures)

## Directory Structure
\`\`\`
EOF

# Append Tree Structure using the filtered file list
(cd "${PROJECT_ROOT}" && tree --fromfile . < "$FILE_LIST_FILTERED") >> "${OUTPUT_FILE}"

echo -e "\`\`\`\n" >> "${OUTPUT_FILE}"

# 4. Extract File Signatures (Content Context)
# ------------------------------------------------------------------------------
log_info "Extracting file signatures..."

echo "## File Signatures" >> "${OUTPUT_FILE}"

while read -r file; do
    full_path="${PROJECT_ROOT}/$file"
    filename=$(basename "$file")

    # 1. Check Signature Exclusions
    should_exclude_signature=0
    for pattern in "${FORCE_EXCLUDE_SIGNATURE[@]}"; do
        if [[ "$filename" == $pattern ]] || [[ "$file" == $pattern ]]; then
            should_exclude_signature=1
            break
        fi
    done

    if [ $should_exclude_signature -eq 1 ]; then
        continue
    fi

    # Append signature section
    echo "### $file" >> "${OUTPUT_FILE}"
    echo '```' >> "${OUTPUT_FILE}"

    # Get file info
    filesize=$(du -h "$full_path" | cut -f1)
    echo "// Size: $filesize" >> "${OUTPUT_FILE}"

    # Extract first 5 lines
    head -n 5 "$full_path" >> "${OUTPUT_FILE}"
    echo "\`\`\`" >> "${OUTPUT_FILE}"
    echo "" >> "${OUTPUT_FILE}"
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

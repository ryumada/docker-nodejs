#!/usr/bin/env bash
set -e
# Category: Entrypoint
# Description: Linting script to verify that project files adhere to the mandatory 5-line signature header protocol.
# Usage: ./scripts/check_compliance.sh [--exclude-app]
# Dependencies: git, grep, wc

# Detect Repository Owner to run non-root commands as that user
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
PROJECT_ROOT=$(sudo -u "$CURRENT_DIR_USER" git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)

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

# ------------------------------------

# --- Configuration for Exclusions ---
# Extensions that do not require a signature header
EXCLUDED_EXTENSIONS=("json" "lock" "md" "svg" "png" "jpg" "ico" "webp" "tsbuildinfo")
# Specific filenames that do not require a signature header
EXCLUDED_FILES=("LICENSE" ".gitignore" ".env.example" "next-env.d.ts")

# Function to check if a file is excluded
is_excluded() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    local extension="${file_name##*.}"

    # Check specific files
    for excl in "${EXCLUDED_FILES[@]}"; do
        if [[ "$file_name" == "$excl" ]]; then
            return 0
        fi
    done

    # Check extensions
    for ext in "${EXCLUDED_EXTENSIONS[@]}"; do
        if [[ "$extension" == "$ext" ]]; then
            return 0
        fi
    done

    return 1
}
# ------------------------------------

EXCLUDE_APP=0
if [[ "$1" == "--exclude-app" ]]; then
    EXCLUDE_APP=1
fi

log_info "Starting Compliance Audit..."

log_info "Collecting files from REPO_MAP.md..."

REPO_MAP="${PROJECT_ROOT}/REPO_MAP.md"

if [ ! -f "$REPO_MAP" ]; then
    log_error "REPO_MAP.md not found at project root. Please run scripts/generate_map.sh first."
    exit 1
fi

TOTAL_FILES=0
NON_COMPLIANT_FILES=0
FAILED_LIST=()

# Extract list of files from REPO_MAP.md signature sections (Lines starting with ###)
FILES=$(grep "^### " "$REPO_MAP" | sed 's/^### //')

# 3. Process files
for rel_file in $FILES; do
    # Ensure path is relative to PROJECT_ROOT
    rel_file=${rel_file#$PROJECT_ROOT/}
    # Remove leading slash if it exists
    rel_file=${rel_file#/}

    # Skip specific exclusions
    if is_excluded "$rel_file"; then
         continue
    fi

    if [ ! -f "$rel_file" ]; then
        log_warn "File listed in REPO_MAP but not found on disk: $rel_file"
        continue
    fi

    # Apply Exclusions
    if [[ $EXCLUDE_APP -eq 1 ]] && [[ "$rel_file" == app/* ]]; then
        continue
    fi

    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Check first 10 lines for "Category", "category", or "@category"
    if ! head -n 10 "$rel_file" | grep -Ei "(@category|category:|Category:|category\"|Category\")" > /dev/null; then
        NON_COMPLIANT_FILES=$((NON_COMPLIANT_FILES + 1))
        FAILED_LIST+=("$rel_file")
    fi
done

if [[ $NON_COMPLIANT_FILES -eq 0 ]]; then
    log_success "All $TOTAL_FILES files are compliant with the signature protocol!"
    exit 0
else
    log_error "Found $NON_COMPLIANT_FILES non-compliant files out of $TOTAL_FILES."
    for f in "${FAILED_LIST[@]}"; do
        echo "  - $f"
    done

    COMPLIANCE_SCORE=$(awk "BEGIN {print (($TOTAL_FILES - $NON_COMPLIANT_FILES) / $TOTAL_FILES) * 100}")
    log_warn "Compliance Score: ${COMPLIANCE_SCORE}%"
    exit 1
fi

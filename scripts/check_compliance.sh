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

EXCLUDE_APP=0
if [[ "$1" == "--exclude-app" ]]; then
    EXCLUDE_APP=1
fi

log_info "Starting Compliance Audit..."

TOTAL_FILES=0
NON_COMPLIANT_FILES=0
FAILED_LIST=()

# Get list of git-tracked files
cd "$PROJECT_ROOT"
FILES=$(git ls-files)

for file in $FILES; do
    # Skip binary files
    if grep -qI . "$file"; then
        filename=$(basename "$file")
        
        # Apply Exclusions
        if [[ $EXCLUDE_APP -eq 1 ]] && [[ "$file" == app/* ]]; then
            continue
        fi

        # Skip specific exclusions (e.g., this script itself)
        # Actually protocol says "Enforcement Logic: If creating a file: You must insert this header immediately."
        # So even this script should have it.

        TOTAL_FILES=$((TOTAL_FILES + 1))
        
        # Check first 10 lines for "Category", "category", or "@category"
        if ! head -n 10 "$file" | grep -Ei "(@category|category:|Category:|category\"|Category\")" > /dev/null; then
            NON_COMPLIANT_FILES=$((NON_COMPLIANT_FILES + 1))
            FAILED_LIST+=("$file")
        fi
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

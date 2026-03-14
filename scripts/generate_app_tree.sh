#!/usr/bin/env bash
# Category: Entrypoint
# Description: Generates logical dependency trees for key entry points.
# Usage: ./scripts/generate_app_tree.sh
# Dependencies: python3, scripts/utility/generate_tree.py

# ==============================================================================
# 🚀 MAIN SCRIPT LOGIC
# ==============================================================================
# Detect Repository Owner to run non-root commands as that user
set -e
CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
PROJECT_ROOT="$(sudo -u "$CURRENT_DIR_USER" git -C "$CURRENT_DIR" rev-parse --show-toplevel)"
APP_PATH=$(find "${PROJECT_ROOT}/app" -maxdepth 2 -name src -type d | head -n 1)
APP_NAME=$(basename "$(dirname "$APP_PATH")")
GEN_SCRIPT="${CURRENT_DIR}/utility/generate_tree.py"
APP_ARCH="${PROJECT_ROOT}/REPO_MAP_APP_ARCHITECTURE.md"
INFRA_ARCH="${PROJECT_ROOT}/REPO_MAP_ARCHITECTURE.md"

# Ensure we are in the project root for consistent path resolution
cd "$PROJECT_ROOT"

REPO_MAP="${PROJECT_ROOT}/REPO_MAP.md"
REACHED_FILES=$(mktemp)

if [ ! -f "$REPO_MAP" ]; then
    echo "❌ Error: REPO_MAP.md not found at $REPO_MAP"
    exit 1
fi

# ==============================================================================
# 🚀 CONFIGURATION
# ==============================================================================

# Categories to use as entry points for Infrastructure tree
INFRA_ENTRY_CATEGORIES=("Entrypoint")
# Categories to use as entry points for Application tree
APP_ENTRY_CATEGORIES=("Page" "Layout" "APIRoute" "Component")

# ==============================================================================
# 🚀 HELP FUNCTION
# ==============================================================================

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generates logical dependency trees for key entry points (Pages, Layouts, etc.)
and orchestration scripts, identifying orphaned components and reporting
ignored categories.

Options:
  --scope PATTERN   Filter entry points by a pattern (e.g., --scope admin).
                    Only trees matching the pattern will be generated.
  --list-scopes     Discover and list all valid entry points and suggested scope patterns.
  -h, --help        Show this help message and exit.

Outputs:
  - $(basename "$APP_ARCH")
  - $(basename "$INFRA_ARCH")

EOF
}

list_scopes() {
    echo "🔍 Discovering Valid Scopes from $REPO_MAP..."
    echo -e "\n--- [ Infrastructure Entry Points ] ---"
    local INFRA_PATTERN=$(printf "|%s" "${INFRA_ENTRY_CATEGORIES[@]}")
    INFRA_PATTERN=${INFRA_PATTERN:1}
    grep -E -B 5 "Category: ($INFRA_PATTERN)" "$REPO_MAP" | grep "###" | sed 's/### //' | sort -u

    echo -e "\n--- [ Application Entry Points ] ---"
    local APP_PATTERN=$(printf "|@category %s" "${APP_ENTRY_CATEGORIES[@]}")
    APP_PATTERN=${APP_PATTERN:1}
    grep -E -B 20 "($APP_PATTERN)" "$REPO_MAP" | grep "###" | sed 's/### //' | sort -u

    echo -e "\n--- [ Suggested Patterns ] ---"
    echo "You can use any string that matches the paths above. Common patterns:"
    echo "$CATEGORIZED_FILES" | awk -F'/' '{
        # Suggest physical path segments only
        path = $1
        if (path != "") {
            print path
            for (i=2; i<=NF; i++) {
                path = path "/" $i
                print path
            }
        }
    }' | grep -v "^\s*$" | sort -u | sed 's/^/- /'
    echo ""
}

# 0. Discovery and Categorization
# Total categorized files for orphan detection
CATEGORIZED_FILES=$(grep "### " "$REPO_MAP" | sed 's/### //' | sort -u)

# ==============================================================================
# 🚀 ARGUMENT PARSING
# ==============================================================================

SCOPE=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help; exit 0 ;;
        --list-scopes) list_scopes; exit 0 ;;
        --scope) SCOPE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; show_help; exit 1 ;;
    esac
    shift
done

SCOPE_DESC="Full Project"
if [ -n "$SCOPE" ]; then
    SCOPE_DESC="Scope: $SCOPE"
fi

# 0. Discovery and Categorization
echo "🔍 Discovering System Entrypoints (Mode: $SCOPE_DESC)..."
# Total categorized files for orphan detection
CATEGORIZED_FILES=$(grep "### " "$REPO_MAP" | sed 's/### //' | sort -u)

# Helper function to get category for a file from REPO_MAP.md
get_category() {
    local target="$1"
    # Find the line after the file header and extract Category/@category
    grep -A 10 "### $target" "$REPO_MAP" | grep -Ei "(@category|Category:|category:)" | head -n 1 | sed -E 's/.*(@category|Category:|category:)[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/[^a-zA-Z0-9_]//g'
}

# Helper function to check if a category is in an entry list
is_entry_category() {
    local cat="$1"
    shift
    local entries=("$@")
    for entry in "${entries[@]}"; do
        if [[ "$cat" == "$entry" ]]; then
            return 0
        fi
    done
    return 1
}

# 1. Infrastructure Architecture
echo "ℹ️ Generating Infrastructure Trees..."
# Build grep pattern for categories
INFRA_PATTERN=$(printf "|%s" "${INFRA_ENTRY_CATEGORIES[@]}")
INFRA_PATTERN=${INFRA_PATTERN:1}
INFRA_TARGETS=$(grep -E -B 5 "Category: ($INFRA_PATTERN)" "$REPO_MAP" | grep "###" | sed 's/### //' | sort -u)

# Apply Scope Filter to Infra Targets
if [ -n "$SCOPE" ]; then
    INFRA_TARGETS=$(echo "$INFRA_TARGETS" | grep "$SCOPE" || true)
fi

{
    echo '---'
    echo "title: Infrastructure Architecture ($SCOPE_DESC)"
    echo 'category: Architecture'
    echo 'description: Logical dependency tree for project orchestration and setup scripts.'
    echo "scope: ${SCOPE:-all}"
    echo '---'
    echo ''
    echo "# Infrastructure Dependency Tree ($SCOPE_DESC)"

    if [ -z "$INFRA_TARGETS" ]; then
        echo -e "\nNo infrastructure entry points match the current scope."
    else
        # Get unique categories for infra targets
        INFRA_CATEGORIES=$(for t in $INFRA_TARGETS; do get_category "$t"; done | sort -u)

        for cat in $INFRA_CATEGORIES; do
            echo -e "\n## Category: ${cat:-Uncategorized}"
            for target in $INFRA_TARGETS; do
                if [ ! -f "$target" ]; then continue; fi
                t_cat=$(get_category "$target")
                if [ "$t_cat" == "$cat" ]; then
                    echo ""
                    echo "### Tree: $target"
                    echo '```text'
                    python3 "$GEN_SCRIPT" "$target" --save-seen "$REACHED_FILES"
                    echo '```'
                fi
            done
        done
    fi
} > "$INFRA_ARCH"

# 2. Application Architecture
echo "ℹ️ Generating Application Trees..."
# Build grep pattern for categories
APP_PATTERN=$(printf "|@category %s" "${APP_ENTRY_CATEGORIES[@]}")
APP_PATTERN=${APP_PATTERN:1}
APP_TARGETS=$(grep -E -B 20 "($APP_PATTERN)" "$REPO_MAP" | grep "###" | sed 's/### //' | sort -u)

# Always include root layout if not found and no scope or scope matches layout
if [ -z "$SCOPE" ] || [[ "app/${APP_NAME}/src/app/layout.tsx" == *"$SCOPE"* ]]; then
    if [[ ! "$APP_TARGETS" =~ "app/${APP_NAME}/src/app/layout.tsx" ]] && [ -f "app/${APP_NAME}/src/app/layout.tsx" ]; then
        APP_TARGETS="${APP_TARGETS} app/${APP_NAME}/src/app/layout.tsx"
    fi
fi

# Apply Scope Filter to App Targets
if [ -n "$SCOPE" ]; then
    APP_TARGETS=$(echo "$APP_TARGETS" | grep "$SCOPE" || true)
fi

{
    echo '---'
    echo "title: Application Architecture ($SCOPE_DESC)"
    echo 'category: Architecture'
    echo 'description: Logical dependency tree for the Next.js application layer.'
    echo "scope: ${SCOPE:-all}"
    echo '---'
    echo ''
    echo "# Application Dependency Tree ($SCOPE_DESC)"

    if [ -z "$APP_TARGETS" ]; then
        echo -e "\nNo application entry points match the current scope."
    else
        # Get unique categories
        CATEGORIES=$(for t in $APP_TARGETS; do get_category "$t"; done | sort -u)

        for cat in $CATEGORIES; do
            echo -e "\n## Category: $cat"
            for target in $APP_TARGETS; do
                if [ ! -f "$target" ]; then continue; fi
                t_cat=$(get_category "$target")
                if [ "$t_cat" == "$cat" ]; then
                    echo ""
                    echo "### Tree: $target"
                    echo '```text'
                    python3 "$GEN_SCRIPT" "$target" --save-seen "$REACHED_FILES"
                    echo '```'
                fi
            done
        done
    fi
} > "$APP_ARCH"

# 3. Orphan Detection & Ignored Categories
echo "🔍 Identifying Orphans and Ignored Categories..."
# Ensure REACHED_FILES exists and has content to avoid grep errors
touch "$REACHED_FILES"
UNIQ_REACHED=$(sort -u "$REACHED_FILES")

# Identify all unique categories in REPO_MAP
ALL_CATEGORIES=$(grep -Ei "(@category|Category:|category:)" "$REPO_MAP" | sed -E 's/.*(@category|Category:|category:)[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/[^a-zA-Z0-9_]//g' | sort -u)

IGNORED_CATEGORIES=""
for cat in $ALL_CATEGORIES; do
    if ! is_entry_category "$cat" "${INFRA_ENTRY_CATEGORIES[@]}" && ! is_entry_category "$cat" "${APP_ENTRY_CATEGORIES[@]}"; then
        IGNORED_CATEGORIES="${IGNORED_CATEGORIES}- $cat\n"
    fi
done

for arch_file in "$APP_ARCH" "$INFRA_ARCH"; do
    {
        echo ""
        if [ "$arch_file" == "$APP_ARCH" ]; then
            echo "# Orphaned Components"
            echo "The following categorized components are not referenced by any identified entry point or page."
            echo ""

            ORPHAN_FOUND=false
            for file in $CATEGORIZED_FILES; do
                # Only consider app/${APP_NAME}/src files for app orphans
                if [[ "$file" == app/${APP_NAME}/src* ]]; then
                    if ! echo "$UNIQ_REACHED" | grep -qx "$file"; then
                        echo "- $file"
                        ORPHAN_FOUND=true
                    fi
                fi
            done

            if [ "$ORPHAN_FOUND" = false ]; then
                echo "✅ No orphaned components detected in the application layer."
            fi
        fi

        echo -e "\n# Ignored Categories"
        echo "The following categories were discovered in REPO_MAP but were not used as entry points for tree generation."
        echo ""
        if [ -n "$IGNORED_CATEGORIES" ]; then
            echo -e "$IGNORED_CATEGORIES"
        else
            echo "✅ All discovered categories were used as entry points."
        fi
    } >> "$arch_file"
done

rm -f "$REACHED_FILES"

echo "✅ Architecture documentation updated with orphan and category coverage detection."

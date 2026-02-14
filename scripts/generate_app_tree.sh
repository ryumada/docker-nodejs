#!/usr/bin/env bash
set -e
# Category: Entrypoint
# Description: Generates logical dependency trees for key entry points.
# Usage: ./scripts/generate_app_tree.sh
# Dependencies: python3, scripts/utility/generate_tree.py

# ==============================================================================
# 🚀 MAIN SCRIPT LOGIC
# ==============================================================================

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
CURRENT_DIR_USER=$(stat -c '%U' "$CURRENT_DIR")
PROJECT_ROOT="$(sudo -u "$CURRENT_DIR_USER" git -C "$CURRENT_DIR" rev-parse --show-toplevel)"
GEN_SCRIPT="${CURRENT_DIR}/utility/generate_tree.py"
APP_ARCH="${PROJECT_ROOT}/APP_ARCHITECTURE.md"
INFRA_ARCH="${PROJECT_ROOT}/ARCHITECTURE.md"

echo "ℹ️ Generating Logical Architecture Trees..."

# Ensure we are in the project root for consistent path resolution
cd "$PROJECT_ROOT"

REPO_MAP="${PROJECT_ROOT}/REPO_MAP.md"
REACHED_FILES=$(mktemp)

if [ ! -f "$REPO_MAP" ]; then
    echo "❌ Error: REPO_MAP.md not found at $REPO_MAP"
    exit 1
fi

# 0. Discovery and Categorization (Selective Entrypoints)
echo "🔍 Discovering System Entrypoints..."
# Total categorized files for orphan detection
CATEGORIZED_FILES=$(grep "### " "$REPO_MAP" | sed 's/### //' | sort -u)

# Selective targets for full recursive trees (Fast & Token Efficient)
INFRA_TARGETS=$(grep -B 5 "Category: Entrypoint" "$REPO_MAP" | grep "###" | sed 's/### //' | sort -u)
APP_TARGETS=$(grep -B 20 "@category Page" "$REPO_MAP" | grep "###" | sed 's/### //' | sort -u)

# Always include root layout as it's the ultimate entry point
if [[ ! "$APP_TARGETS" =~ "app/essentia/src/app/layout.tsx" ]]; then
    APP_TARGETS="${APP_TARGETS} app/essentia/src/app/layout.tsx"
fi

# 1. Infrastructure Architecture
echo "ℹ️ Generating Infrastructure Trees..."
{
    echo '---'
    echo 'title: Infrastructure Architecture'
    echo 'category: Architecture'
    echo 'description: Logical dependency tree for project orchestration and setup scripts.'
    echo '---'
    echo ''
    echo '# Infrastructure Dependency Tree'

    for target in $INFRA_TARGETS; do
        if [ ! -f "$target" ]; then continue; fi
        echo ""
        echo "## Tree: $target"
        echo '```text'
        python3 "$GEN_SCRIPT" "$target" --save-seen "$REACHED_FILES"
        echo '```'
    done
} > "$INFRA_ARCH"

# 2. Application Architecture
echo "ℹ️ Generating Application Trees..."
{
    echo '---'
    echo 'title: Application Architecture'
    echo 'category: Architecture'
    echo 'description: Logical dependency tree for the Next.js application layer.'
    echo '---'
    echo ''
    echo '# Application Dependency Tree'

    for target in $APP_TARGETS; do
        if [ ! -f "$target" ]; then continue; fi
        echo ""
        echo "## Tree: $target"
        echo '```text'
        python3 "$GEN_SCRIPT" "$target" --save-seen "$REACHED_FILES"
        echo '```'
    done
} > "$APP_ARCH"

# 3. Orphan Detection
echo "🔍 Identifying Orphaned Components..."
# Ensure REACHED_FILES exists and has content to avoid grep errors
touch "$REACHED_FILES"
UNIQ_REACHED=$(sort -u "$REACHED_FILES")

{
    echo ""
    echo "# Orphaned Components"
    echo "The following categorized components are not referenced by any identified entry point or page."
    echo ""

    ORPHAN_FOUND=false
    for file in $CATEGORIZED_FILES; do
        # Only consider app/essentia/src files for app orphans
        if [[ "$file" == app/essentia/src* ]]; then
            if ! echo "$UNIQ_REACHED" | grep -qx "$file"; then
                echo "- $file"
                ORPHAN_FOUND=true
            fi
        fi
    done

    if [ "$ORPHAN_FOUND" = false ]; then
        echo "✅ No orphaned components detected in the application layer."
    fi
} >> "$APP_ARCH"

rm -f "$REACHED_FILES"

echo "✅ Architecture documentation updated with orphan detection."

#!/usr/bin/env bash
set -e
# Category: Utility
# Description: Parses REPO_MAP.md to generate a clustered Mermaid dependency graph of the project.
# Usage: ./scripts/generate_graph.sh
# Dependencies: grep, sed, awk

# ==============================================================================
# 🚀 MAIN SCRIPT LOGIC
# ==============================================================================

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
PROJECT_ROOT="${CURRENT_DIR}/.."
REPO_MAP="${PROJECT_ROOT}/REPO_MAP.md"
OUTPUT_FILE="${PROJECT_ROOT}/ARCHITECTURE.md"

if [ ! -f "$REPO_MAP" ]; then
    echo "❌ Error: REPO_MAP.md not found. Please run ./scripts/generate_map.sh first."
    exit 1
fi

echo "ℹ️ Generating Clustered Dependency Graph..."

# Initialize the architecture file
echo '---' > "$OUTPUT_FILE"
echo 'title: Project Dependency Graph' >> "$OUTPUT_FILE"
echo 'category: Architecture' >> "$OUTPUT_FILE"
echo 'description: Visualizes logical dependencies between modules, clustered by directory.' >> "$OUTPUT_FILE"
echo '---' >> "$OUTPUT_FILE"
echo '' >> "$OUTPUT_FILE"
echo '# Project Dependency Graph' >> "$OUTPUT_FILE"
echo '' >> "$OUTPUT_FILE"
echo '```mermaid' >> "$OUTPUT_FILE"
echo 'graph TD' >> "$OUTPUT_FILE"

# Parse REPO_MAP.md and generate Mermaid syntax using awk
awk '
BEGIN {
    FS = " "
}

# --- STEP 1: Capture File Nodes ---
/^### / {
    full_path = $2

    # Create a safe ID (app_src_utils_ts)
    node_id = full_path
    gsub(/[^a-zA-Z0-9]/, "_", node_id)

    # Extract filename for the label
    n = split(full_path, parts, "/")
    filename = parts[n]
    dir_path = ""
    for(i=1; i<n; i++) {
        dir_path = (dir_path == "" ? "" : dir_path "/") parts[i]
    }
    if (dir_path == "") dir_path = "Root"

    if (!seen_node[node_id]) {
        nodes_by_dir[dir_path] = nodes_by_dir[dir_path] " " node_id
        node_labels[node_id] = filename
        current_node = node_id
        seen_node[node_id] = 1
    }
}

# --- STEP 2: Capture Dependencies ---
/^# Dependencies:/ || /^ \* @requires/ {
    gsub(/^# Dependencies: /, "")
    gsub(/^ \* @requires /, "")
    gsub(/["'\''\[\],]/, " ")

    for (i = 1; i <= NF; i++) {
        dep = $i
        if (dep != "" && current_node != "") {
            if (index(dep, "/") > 0 || index(dep, ".") > 0) {
                gsub(/^\.\//, "", dep)
                target_id = dep
                gsub(/[^a-zA-Z0-9]/, "_", target_id)
                edges[current_node "->" target_id] = current_node " --> " target_id
            }
        }
    }
}

# --- STEP 3: Print the Graph ---
END {
    for (dir in nodes_by_dir) {
        clean_dir = dir
        gsub(/[^a-zA-Z0-9]/, "_", clean_dir)

        # Added escaped quotes around the directory name for Mermaid safety
        print "    subgraph " clean_dir " [\"" dir "\"]"
        print "      direction TB"

        split(nodes_by_dir[dir], nodes, " ")
        for (i in nodes) {
            nid = nodes[i]
            if (nid != "") {
                print "      " nid "[\"" node_labels[nid] "\"]"
            }
        }
        print "    end"
    }

    for (key in edges) {
        split(key, parts, "->")
        source = parts[1]
        target = parts[2]
        if (seen_node[source] && seen_node[target]) {
            print "    " edges[key]
        }
    }

    print "    classDef cluster fill:#f9f9f9,stroke:#333,stroke-width:1px;"
}
' "$REPO_MAP" >> "$OUTPUT_FILE"

echo '```' >> "$OUTPUT_FILE"

echo "✅ Dependency graph generated at $OUTPUT_FILE"

#!/usr/bin/env bash
set -e
# Category: Maintenance
# Description: Generates Russian-doll nested Graphify knowledge graphs for root deployment tools and app repository.
# Usage: ./scripts/generate_graph.sh [all|root|app] [app_directory]
# Dependencies: python3, graphifyy, git

# ==============================================================================
# RESOLVE ROOTS
# ==============================================================================

CURRENT_DIR=$(dirname "$(readlink -f "$0")")
ROOT_DIR=$(git -C "$CURRENT_DIR" rev-parse --show-toplevel 2>/dev/null || readlink -f "$CURRENT_DIR/..")
MODE="${1:-all}"
SPECIFIED_APP_DIR="$2"

# ==============================================================================
# RESOLVE GRAPHIFY PYTHON INTERPRETER
# ==============================================================================

resolve_python() {
    local target_dir="$1"
    local out_dir="${target_dir}/graphify-out"
    mkdir -p "$out_dir"
    
    local python_bin=""
    local graphify_bin
    graphify_bin=$(which graphify 2>/dev/null || true)
    
    if [ -z "$python_bin" ] && command -v uv >/dev/null 2>&1; then
        local uv_py
        uv_py=$(uv tool run --from graphifyy python -c "import sys; print(sys.executable)" 2>/dev/null || true)
        if [ -n "$uv_py" ]; then python_bin="$uv_py"; fi
    fi
    
    if [ -z "$python_bin" ] && [ -n "$graphify_bin" ]; then
        local shebang
        shebang=$(head -1 "$graphify_bin" | tr -d '#!')
        case "$shebang" in
            *[!a-zA-Z0-9/_.@-]*) ;;
            *) if "$shebang" -c "import graphify" 2>/dev/null; then python_bin="$shebang"; fi ;;
        esac
    fi
    
    if [ -z "$python_bin" ]; then python_bin="python3"; fi
    
    if ! "$python_bin" -c "import graphify" 2>/dev/null; then
        if command -v uv >/dev/null 2>&1; then
            uv tool install --upgrade graphifyy -q 2>&1 | tail -3
            local uv_py
            uv_py=$(uv tool run --from graphifyy python -c "import sys; print(sys.executable)" 2>/dev/null || true)
            if [ -n "$uv_py" ]; then python_bin="$uv_py"; fi
        else
            "$python_bin" -m pip install graphifyy -q 2>/dev/null || "$python_bin" -m pip install graphifyy -q --break-system-packages 2>&1 | tail -3
        fi
    fi
    
    echo "$python_bin" > "${out_dir}/.graphify_python"
    echo "$(cd "$target_dir" && pwd)" > "${out_dir}/.graphify_root"
    echo "$python_bin"
}

# ==============================================================================
# RUN GRAPHIFY ON DIRECTORY
# ==============================================================================

build_graph_for_dir() {
    local target_dir="$1"
    local label_prefix="$2"
    local abs_target
    abs_target=$(readlink -f "$target_dir")
    local out_dir="${abs_target}/graphify-out"
    
    echo "======================================================================"
    echo "Generating Graphify Knowledge Graph: ${abs_target}"
    echo "Output: ${out_dir}"
    echo "======================================================================"
    
    local py_bin
    py_bin=$(resolve_python "$abs_target")
    
    "$py_bin" -c "
import sys, json
from pathlib import Path
from collections import Counter
from graphify.detect import detect
from graphify.extract import collect_files, extract
from graphify.build import build_from_json
from graphify.cluster import cluster, score_all
from graphify.analyze import god_nodes, surprising_connections, suggest_questions
from graphify.report import generate
from graphify.export import to_json, to_html
from graphify.cli import _stamped_manifest_files
from graphify.detect import save_manifest

target = Path('$abs_target')
out_dir = Path('$out_dir')
out_dir.mkdir(parents=True, exist_ok=True)

# 1. Detect
detect_res = detect(target)
code_files = []
for f in detect_res.get('files', {}).get('code', []):
    p = Path(f)
    code_files.extend(collect_files(p) if p.is_dir() else [p])

print(f'Detected {detect_res.get(\"total_files\", 0)} files ({len(code_files)} code files)')

# 2. Extract AST
if code_files:
    ast_res = extract(code_files, cache_root=target)
else:
    ast_res = {'nodes': [], 'edges': [], 'input_tokens': 0, 'output_tokens': 0}

print(f'AST extracted: {len(ast_res.get(\"nodes\", []))} nodes, {len(ast_res.get(\"edges\", []))} edges')

# 3. Build Graph
G = build_from_json(ast_res, root=str(target), directed=False)
if G.number_of_nodes() == 0:
    print('No nodes to graph - skipping.')
    import shutil
    shutil.rmtree(out_dir, ignore_errors=True)
    sys.exit(0)

# 4. Cluster & Analyze
communities = cluster(G)
cohesion = score_all(G, communities)
gods = god_nodes(G)
surprises = surprising_connections(G, communities)

# Labeling
labels = {}
for cid, nodes in communities.items():
    words = []
    for n in nodes:
        clean = n.replace('src_', '').replace('components_', '').replace('lib_', '').replace('app_', '').replace('scripts_', '')
        parts = [p for p in clean.split('_') if p not in {'props', 'constructor', 'page', 'client', 'server', 'hook', 'hooks', 'test', 'mock', 'type', 'types'} and len(p) > 2]
        words.extend(parts)
    if words:
        top_words = [w.capitalize() for w, _ in Counter(words).most_common(3)]
        labels[cid] = ' '.join(top_words)
    else:
        labels[cid] = f'${label_prefix} {cid}'

questions = suggest_questions(G, communities, labels)

# 5. Export JSON, HTML, and Markdown report
to_json(G, communities, str(out_dir / 'graph.json'), community_labels=labels, force=True)
to_html(G, communities, str(out_dir / 'graph.html'), community_labels=labels)

report = generate(G, communities, cohesion, labels, gods, surprises, detect_res, {'input': 0, 'output': 0}, str(target), suggested_questions=questions)
(out_dir / 'GRAPH_REPORT.md').write_text(report, encoding='utf-8')

# 6. Save manifest
corpus = detect_res.get('all_files') or detect_res['files']
manifest_files = _stamped_manifest_files(corpus, ast_res, target)
save_manifest(manifest_files, root=str(target), scan_corpus={f for fl in corpus.values() for f in fl})

print(f'Graph complete: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges, {len(communities)} communities')
"
    echo "Outputs saved to ${out_dir}"
    echo ""
}

# ==============================================================================
# EXECUTION ROUTING
# ==============================================================================

if [ "$MODE" = "root" ] || [ "$MODE" = "all" ]; then
    build_graph_for_dir "$ROOT_DIR" "Root Infrastructure"
fi

if [ "$MODE" = "app" ] || [ "$MODE" = "all" ]; then
    if [ -n "$SPECIFIED_APP_DIR" ] && [ -d "$SPECIFIED_APP_DIR" ]; then
        build_graph_for_dir "$SPECIFIED_APP_DIR" "App"
    else
        # Find subdirectories in app/
        if [ -d "${ROOT_DIR}/app" ]; then
            for app_subdir in "${ROOT_DIR}/app"/*; do
                if [ -d "$app_subdir" ] && [ "$(basename "$app_subdir")" != "graphify-out" ]; then
                    build_graph_for_dir "$app_subdir" "App"
                fi
            done
        fi
    fi
fi

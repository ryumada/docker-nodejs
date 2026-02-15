#!/usr/bin/env python3
# Category: Utility
# Description: Generates a text-based logical dependency tree by tracing signatures. Don't run this script directly, use generate_app_tree.sh instead.
# Usage: python3 scripts/generate_tree.py [entrypoint] [max_depth]
# Dependencies: python3

import os
import re
import sys

def get_dependencies(file_path):
    """Extracts dependencies from the 5-line signature header."""
    if not os.path.exists(file_path):
        return []

    deps = []
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()[:20] # Scan first 20 lines
            for line in lines:
                # Match # Dependencies: or * @requires
                match = re.search(r'(?:# Dependencies:|@requires)\s+(.*)', line)
                if match:
                    raw_deps = match.group(1)
                    # Clean up quotes, brackets, and commas
                    cleaned = re.sub(r'["\'\[\],]', ' ', raw_deps)
                    for d in cleaned.split():
                        d = d.strip()
                        if d: deps.append(d)
    except Exception:
        pass
    return list(set(deps))

def resolve_path(current_file, dep, project_root):
    """Tries to resolve a dependency string to a physical file path."""
    # Special case for internal shell scripts in the same dir
    if dep.endswith('.sh') and not dep.startswith(('/', '.', '@')):
        candidate = os.path.join(os.path.dirname(current_file), dep)
        if os.path.exists(candidate):
            return os.path.relpath(candidate, project_root)

    # Handle @/ paths (Next.js alias)
    if dep.startswith('@/'):
        # Dynamically detect app name if not provided (defaulting to 'essentia')
        # We look for a directory under 'app/' that has 'src'
        app_name = 'essentia'
        app_root = os.path.join(project_root, 'app')
        if os.path.isdir(app_root):
            for d in os.listdir(app_root):
                if os.path.isdir(os.path.join(app_root, d, 'src')):
                    app_name = d
                    break
        
        base = os.path.join(project_root, f'app/{app_name}/src', dep[2:])
        # Check direct file or directory/index
        for ext in ['', '.tsx', '.ts', '.js']:
            if os.path.exists(base + ext) and not os.path.isdir(base + ext):
                return os.path.relpath(base + ext, project_root)

        # Check directory/index
        if os.path.isdir(base):
            for iext in ['/index.tsx', '/index.ts', '/index.js']:
                if os.path.exists(base + iext):
                    return os.path.relpath(base + iext, project_root)

    # Handle relative paths
    if dep.startswith(('./', '../')):
        base = os.path.normpath(os.path.join(os.path.dirname(current_file), dep))
        for ext in ['', '.tsx', '.ts', '.js']:
            if os.path.exists(base + ext) and not os.path.isdir(base + ext):
                return os.path.relpath(base + ext, project_root)

        # Check directory/index
        if os.path.isdir(base):
            for iext in ['/index.tsx', '/index.ts', '/index.js']:
                if os.path.exists(base + iext):
                    return os.path.relpath(base + iext, project_root)

    # Handle other semi-absolute paths or project-root relative paths
    candidate = os.path.join(project_root, dep)
    if os.path.exists(candidate) and not os.path.isdir(candidate):
        return os.path.relpath(candidate, project_root)

    return None

def print_tree(file_rel_path, project_root, visited=None, tracked_files=None, indent="", is_last=True, depth=0, max_depth=8):
    if visited is None: visited = set()
    if tracked_files is not None: tracked_files.add(file_rel_path)

    # Use the relative path for display to avoid "profile.ts" ambiguity
    display_name = file_rel_path

    marker = "└── " if is_last else "├── "
    prefix = indent + marker

    # Use the relative path from root as the unique ID for recursion guard
    if file_rel_path in visited:
        print(f"{prefix}{display_name} (circular)")
        return

    print(f"{prefix}{display_name}")

    if depth >= max_depth:
        return

    visited.add(file_rel_path)

    full_path = os.path.join(project_root, file_rel_path)
    deps = get_dependencies(full_path)

    # Resolve deps to project-internal paths
    resolved_deps = []
    for d in deps:
        res = resolve_path(full_path, d, project_root)
        if res:
            resolved_deps.append(res)
        else:
            # External dependencies or unresolvable
            resolved_deps.append(f"EXT:{d}")

    # Deduplicate while preserving order
    unique_deps = []
    for d in resolved_deps:
        if d not in unique_deps: unique_deps.append(d)

    new_indent = indent + ("    " if is_last else "│   ")
    for i, dep in enumerate(unique_deps):
        last_child = (i == len(unique_deps) - 1)
        if dep.startswith("EXT:"):
            ext_name = dep[4:]
            marker_child = "└── " if last_child else "├── "
            print(f"{new_indent}{marker_child}{ext_name} [External]")
        else:
            # Recurse with a copy of visited (per-path guard) but shared tracked_files
            print_tree(dep, project_root, visited.copy(), tracked_files, new_indent, last_child, depth + 1, max_depth)

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Generate logical dependency trees.")
    parser.add_argument("entrypoint", help="Entrypoint file path")
    parser.add_argument("--save-seen", help="File path to save the set of all encountered internal files")
    args = parser.parse_args()

    entrypoint = args.entrypoint
    project_root = os.getcwd()

    if not os.path.exists(os.path.join(project_root, entrypoint)):
        print(f"Error: Entrypoint {entrypoint} not found.")
        return

    print(f"Dependency Tree for {entrypoint}:")
    tracked = set()
    print_tree(entrypoint, project_root, visited=None, tracked_files=tracked)

    if args.save_seen:
        with open(args.save_seen, 'a') as f:
            for s in tracked:
                f.write(s + '\n')

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
# Category: Utility
# Description: Automatically injects or updates mandatory JSDoc signature headers in TypeScript/React files.
# Usage: python3 scripts/inject_signatures.py [directory]
# Dependencies: python3

import os
import re
import sys

def get_category(path):
    """Infers category based on file path."""
    if 'src/app' in path:
        if 'page.tsx' in path: return 'Page'
        if 'layout.tsx' in path: return 'Layout'
        if 'route.ts' in path: return 'APIRoute'
        return 'Component'
    if 'src/components/ui' in path: return 'UI_Component'
    if 'src/components' in path: return 'Component'
    if 'src/hooks' in path: return 'Hook'
    if 'src/lib' in path: return 'Utility'
    if 'src/data' in path: return 'Data'
    if 'src/schemas' in path: return 'Schema'
    return 'Component'

def extract_requires(content):
    """Extracts internal and key external dependencies from import statements."""
    imports = re.findall(r"from\s+['\"]([^'\"]+)['\"]", content)
    # Filter for project-specific imports or key libraries
    requires = []
    for imp in imports:
        if imp.startswith('@/') or '/' in imp or imp in ['next', 'react', 'lucide-react', 'appwrite']:
            requires.append(f"'{imp}'")
    return ", ".join(sorted(list(set(requires))))

def inject_signature(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    content = "".join(lines)
    rel_path = os.path.relpath(file_path, os.getcwd())
    filename = os.path.basename(file_path)
    category = get_category(rel_path)
    requires = extract_requires(content)

    # Check if signature already exists
    has_signature = False
    start_idx = -1
    end_idx = -1

    for i, line in enumerate(lines[:15]):
        if '/**' in line:
            start_idx = i
        if '*/' in line and start_idx != -1:
            end_idx = i
            if any('@category' in lines[j] for j in range(start_idx, end_idx + 1)):
                has_signature = True
            break

    new_signature = [
        "/**\n",
        f" * @file {rel_path}\n",
        f" * @category {category}\n",
        f" * @description Component or logic in {rel_path}\n",
        f" * @requires {requires}\n",
        " */\n"
    ]

    if has_signature:
        # Update existing signature
        lines[start_idx:end_idx+1] = new_signature
    else:
        # Insert new signature
        insert_pos = 0
        # Preserve "use client" or "use server" at the very top if present
        if lines and ("use client" in lines[0] or "use server" in lines[0]):
            insert_pos = 2 if len(lines) > 1 and lines[1].strip() == "" else 1
            if len(lines) > insert_pos and lines[insert_pos].strip() == "":
                pass
            else:
                new_signature.append("\n")
        else:
            new_signature.append("\n")

        lines[insert_pos:insert_pos] = new_signature

    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)
    print(f"✅ Processed {rel_path}")

def main():
    target_dir = sys.argv[1] if len(sys.argv) > 1 else "app/essentia/src"
    if not os.path.isdir(target_dir):
        print(f"❌ Directory not found: {target_dir}")
        sys.exit(1)

    for root, _, files in os.walk(target_dir):
        # Skip tests
        if '__tests__' in root:
            continue

        for file in files:
            if file.endswith(('.ts', '.tsx')) and not file.endswith('.d.ts'):
                inject_signature(os.path.join(root, file))

if __name__ == "__main__":
    main()

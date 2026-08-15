#!/usr/bin/env python3
# Category: Utility
# Description: Queries graphify-out/graph.json for symbols, callers, callees, and god nodes with minimal token output.
# Usage: python3 scripts/utility/query_graph.py <lookup|god-nodes|community|search> [target] [app_dir]
# Dependencies: python3

import json
import os
import sys
from pathlib import Path

def resolve_graph_file(app_dir=None):
    root = Path.cwd()
    if app_dir:
        cand = root / app_dir / "graphify-out" / "graph.json"
        if cand.exists():
            return cand
    # Search common locations
    candidates = [
        root / "graphify-out" / "graph.json",
        root / "app" / "ess-essentia" / "graphify-out" / "graph.json",
    ]
    for c in candidates:
        if c.exists():
            return c
    # Search any graph.json in app/*
    for p in (root / "app").glob("*/graphify-out/graph.json"):
        return p
    return None

def load_graph(graph_file):
    if not graph_file or not graph_file.exists():
        print(f"Error: graph.json not found. Run ./scripts/generate_graph.sh first.")
        sys.exit(1)
    with open(graph_file, "r", encoding="utf-8") as f:
        return json.load(f)

def cmd_lookup(data, query):
    nodes = {n["id"]: n for n in data.get("nodes", [])}
    edges = data.get("links") or data.get("edges", [])
    query_lower = query.lower()

    # Find matching nodes
    matches = [nid for nid in nodes if query_lower in nid.lower()]
    if not matches:
        print(f"No node matching '{query}' found.")
        return

    print(f"Found {len(matches)} match(es) for '{query}':")
    for nid in matches[:5]:
        node = nodes[nid]
        incoming = [e["source"] for e in edges if e["target"] == nid]
        outgoing = [e["target"] for e in edges if e["source"] == nid]
        community = node.get("community", "none")
        node_type = node.get("type", "symbol")

        print(f"\n- Node: `{nid}` (Type: {node_type}, Cluster: {community})")
        if incoming:
            print(f"  Called/Imported by ({len(incoming)}): {', '.join(incoming[:5])}{'...' if len(incoming) > 5 else ''}")
        if outgoing:
            print(f"  Calls/Imports ({len(outgoing)}): {', '.join(outgoing[:5])}{'...' if len(outgoing) > 5 else ''}")

def cmd_god_nodes(data):
    nodes = {n["id"]: n for n in data.get("nodes", [])}
    edges = data.get("links") or data.get("edges", [])
    degree = {}
    for e in edges:
        s, t = e["source"], e["target"]
        degree[s] = degree.get(s, 0) + 1
        degree[t] = degree.get(t, 0) + 1

    sorted_nodes = sorted(degree.items(), key=lambda x: x[1], reverse=True)[:10]
    print(f"Top {len(sorted_nodes)} God Nodes (Central Coupling):")
    for rank, (nid, count) in enumerate(sorted_nodes, 1):
        node = nodes.get(nid, {})
        ntype = node.get("type", "unknown")
        print(f"{rank}. `{nid}` ({ntype}) — {count} connections")

def cmd_community(data, cid=None):
    labels = data.get("community_labels", {})
    nodes = data.get("nodes", [])
    if not cid:
        print("Community Clusters:")
        for c_id, label in labels.items():
            count = sum(1 for n in nodes if str(n.get("community")) == str(c_id))
            print(f"- Cluster {c_id}: {label} ({count} nodes)")
    else:
        matched = [n["id"] for n in nodes if str(n.get("community")) == str(cid)]
        label = labels.get(str(cid), "Unknown")
        print(f"Cluster {cid} ({label}) — {len(matched)} nodes:")
        for nid in matched[:15]:
            print(f"  - `{nid}`")
        if len(matched) > 15:
            print(f"  ... and {len(matched) - 15} more nodes")

def main():
    if len(sys.argv) < 2:
        print("Usage: query_graph.py <lookup|god-nodes|community> [args] [app_dir]")
        sys.exit(1)

    cmd = sys.argv[1]
    arg = sys.argv[2] if len(sys.argv) > 2 else None
    app_dir = sys.argv[3] if len(sys.argv) > 3 else (arg if cmd == "god-nodes" else None)

    graph_file = resolve_graph_file(app_dir)
    data = load_graph(graph_file)

    if cmd == "lookup":
        if not arg:
            print("Error: Specify a symbol or filepath to lookup.")
            sys.exit(1)
        cmd_lookup(data, arg)
    elif cmd in ("god-nodes", "gods"):
        cmd_god_nodes(data)
    elif cmd in ("community", "cluster"):
        cmd_community(data, arg)
    else:
        print(f"Unknown command '{cmd}'. Available: lookup, god-nodes, community")

if __name__ == "__main__":
    main()

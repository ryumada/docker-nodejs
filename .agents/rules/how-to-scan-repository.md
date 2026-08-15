---
trigger: model_decision
category: Reference
tokens: ~12
---

# 🗺️ PROTOCOL: REPO_MAP_FIRST & TIERED DISCOVERY
**Objective:** Eliminate hallucinations and token bloat by using structured, tiered discovery.

1.  **Tier 1 — File Presence & Top-Level Topology:**
    -   Read root [`REPO_MAP.md`](REPO_MAP.md) for infrastructure files.
    -   For nested apps (`app/<app_name>`), use `grep_search` or slice-view specific sections of `app/<app_name>/REPO_MAP.md` rather than loading the entire file.
    -   **Navigation Rule:** Do NOT execute `ls -R` or `find .` to explore. Derive file existence strictly from `REPO_MAP.md`.

2.  **Tier 2 — Symbol & Dependency Tracing (Zero-Overhead AST):**
    -   Do NOT read raw `graph.json` or full `GRAPH_REPORT.md` into context.
    -   Use `python3 scripts/utility/query_graph.py lookup <symbol_or_path>` for callers, callees, and imports.
    -   Use `python3 scripts/utility/query_graph.py god-nodes` to identify central coupled modules.

3.  **Tier 3 — Slice-Reading Code:**
    -   Never load 500+ line files with `view_file` unless absolutely required.
    -   Always supply `StartLine` and `EndLine` parameters to view only the target function/component.

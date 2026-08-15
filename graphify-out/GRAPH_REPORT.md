# Graph Report - essentia  (2026-08-15)

## Corpus Check
- Corpus is ~17,070 words - fits in a single context window. You may not need a graph.

## Summary
- 171 nodes · 278 edges · 17 communities (14 shown, 3 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Setup Color Log
- Generate Map Log
- Update Deployment Color
- Check Compliance Color
- Cleanup Sudoers Log
- Setup Sudoers Log
- Utility Fix Webview
- Utility Update Env
- Export Extensions Color
- Setup Dev User
- Inject Utility Signatures
- Tree Utility Generate
- Generate Tree Category
- Validate Agent Config
- Graph Generate Build
- Bootstraping Init Next
- Bootstraping Run Entry

## God Nodes (most connected - your core abstractions)
1. `main()` - 11 edges
2. `log_info()` - 7 edges
3. `log_success()` - 7 edges
4. `check_compliance.sh script` - 6 edges
5. `cleanup_sudoers.sh script` - 6 edges
6. `log()` - 6 edges
7. `executeCommand()` - 6 edges
8. `log()` - 6 edges
9. `main()` - 6 edges
10. `update_docker_compose_build_args()` - 6 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (17 total, 3 thin omitted)

### Community 0 - "Setup Color Log"
Cohesion: 0.27
Nodes (17): COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, configure_proxy_mode(), filesubstitution(), log() (+9 more)

### Community 1 - "Generate Map Log"
Cohesion: 0.26
Nodes (13): COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, executeCommand(), log(), log_error() (+5 more)

### Community 2 - "Update Deployment Color"
Cohesion: 0.24
Nodes (13): COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, handle_error(), log(), log_error() (+5 more)

### Community 3 - "Check Compliance Color"
Cohesion: 0.27
Nodes (12): COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, is_excluded(), log(), log_error() (+4 more)

### Community 4 - "Cleanup Sudoers Log"
Cohesion: 0.28
Nodes (12): COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, log(), log_error(), log_info() (+4 more)

### Community 5 - "Setup Sudoers Log"
Cohesion: 0.27
Nodes (12): COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, log(), log_error(), log_info() (+4 more)

### Community 6 - "Utility Fix Webview"
Cohesion: 0.29
Nodes (12): clear_cache(), COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, log(), log_error() (+4 more)

### Community 7 - "Utility Update Env"
Cohesion: 0.27
Nodes (12): COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, log(), log_error(), log_info() (+4 more)

### Community 8 - "Export Extensions Color"
Cohesion: 0.29
Nodes (11): COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, log(), log_error(), log_info() (+3 more)

### Community 9 - "Setup Dev User"
Cohesion: 0.29
Nodes (11): COLOR_ERROR, COLOR_INFO, COLOR_RESET, COLOR_SUCCESS, COLOR_WARN, log(), log_error(), log_info() (+3 more)

### Community 10 - "Inject Utility Signatures"
Cohesion: 0.33
Nodes (8): extract_requires(), get_app_name(), get_category(), inject_signature(), main(), Detects the app name by finding a directory under 'app/' with a 'src' directory., Infers category based on file path., Extracts internal and key external dependencies from import statements.

### Community 11 - "Tree Utility Generate"
Cohesion: 0.43
Nodes (6): get_dependencies(), main(), print_tree(), Extracts dependencies from the 5-line signature header., Tries to resolve a dependency string to a physical file path., resolve_path()

### Community 12 - "Generate Tree Category"
Cohesion: 0.53
Nodes (4): is_entry_category(), list_scopes(), generate_app_tree.sh script, show_help()

### Community 13 - "Validate Agent Config"
Cohesion: 0.60
Nodes (5): fail(), log(), ok(), validate-agent-config.sh script, warn()

## Knowledge Gaps
- **52 isolated node(s):** `init-next-app.sh script`, `run.sh script`, `COLOR_RESET`, `COLOR_INFO`, `COLOR_SUCCESS` (+47 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `init-next-app.sh script`, `run.sh script`, `COLOR_RESET` to the rest of the system?**
  _52 weakly-connected nodes found - possible documentation gaps or missing edges._
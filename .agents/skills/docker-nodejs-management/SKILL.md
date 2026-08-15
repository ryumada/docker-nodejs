---
name: docker-nodejs-management
description: Knowledge for managing the docker-nodejs repository — setup, deployment, maintenance, and Russian-doll nested repository mapping (REPO_MAP + Graphify).
tokens: ~80
---

# Docker-NodeJS Management Skill

Use this skill when working with Node.js Docker deployment, configuration, container execution, or repository topology mapping.

## Repository Overview (Matryoshka / Russian Nesting Doll Model)

This repository follows a two-tier nested architecture:
1. **Outer Doll (Root Deployment & Infrastructure)**:
   - Contains Docker compose, Nginx reverse proxy configs, setup/maintenance scripts, and agent protocols.
   - Ground truth maps: Root `REPO_MAP.md` and Root `graphify-out/`.
2. **Inner Doll (Application Codebase)**:
   - Contains the active Node.js / Next.js web application mounted under `app/<app_name>`.
   - Ground truth maps: Nested `app/<app_name>/REPO_MAP.md` and Nested `app/<app_name>/graphify-out/`.

## Directory Structure
- `scripts/` — maintenance, bootstrapping, and mapping scripts.
- `scripts/bootstraping/run.sh` — wrapper script to run commands inside the running application container.
- `scripts/bootstraping/init-next-app.sh` — helper script to initialize a Next.js application structure.
- `scripts/generate_map.sh` — generates structured `REPO_MAP.md` with 5-line file signatures.
- `scripts/generate_graph.sh` — generates AST knowledge graphs (`graphify-out/`) for root and nested app.
- `app/` — local mount point for cloned or initialized Node.js projects (`app/<app_name>`).
- `nginx-sites-available.conf` — Nginx reverse proxy configuration.

## Critical Workflows

### 1. Executing Commands in Container
> [!IMPORTANT]
> **ALWAYS** use `./scripts/bootstraping/run.sh` to run **ANY** `npm`, `npx`, `node`, `tsc`, `vitest`, or build/test/install commands. Node.js and npm are executed inside the Docker container (`app`). Never run `npm` or `node` directly on the host machine.

```bash
./scripts/bootstraping/run.sh <command>
# Examples:
# ./scripts/bootstraping/run.sh npm install <package>
# ./scripts/bootstraping/run.sh npm run build
# ./scripts/bootstraping/run.sh npm run dev
```

### 2. Russian-Doll Repository Mapping

#### A. File Signatures Map (`REPO_MAP.md`)
```bash
# Generate Root Map
./scripts/generate_map.sh

# Generate App Map
./scripts/generate_map.sh app/<app_name>
```

#### B. Graphify Knowledge Graph (`graphify-out/`)
```bash
# Generate both Root and App nested graphs
./scripts/generate_graph.sh all

# Generate only Root infrastructure graph (outputs to ./graphify-out)
./scripts/generate_graph.sh root

# Generate only App code graph (outputs to app/<app_name>/graphify-out)
./scripts/generate_graph.sh app [optional_app_dir]
```

### 3. Graph Outputs & Navigation
Each `graphify-out/` folder contains:
- `GRAPH_REPORT.md` — Architectural breakdown, community clusters, and god nodes.
- `graph.json` — Structured graph for AST calls, imports, and component hierarchies.
- `graph.html` — Interactive visual graph viewable in browser.

### 4. Test Log Compression
- Always run tests with `--bail` or fail-fast flags:
  `./scripts/bootstraping/run.sh npm run test -- --bail=1`
- On test failures: inspect ONLY the assertion failure message, expected vs. actual values, and exact `file:line` reference. Discard passing setup logs.

---
title: docker-nodejs
category: Reference
description: Node.js Docker Deployment Utility for automated setup and environment management.
context: Root Repository
---
# docker-nodejs - Node.js Docker Deployment Utility

docker-nodejs is a utility repository designed to streamline the deployment of Node.js applications using Docker Compose. It provides automated setup scripts, environment variable management, and configuration for both development and production environments.

## Prerequisites

Before using this tool, ensure you have the following installed:
- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)
- [Git](https://git-scm.com/downloads)
- `bash` (standard on Linux/macOS)

## Quick Start

1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd docker-nodejs
    ```

2.  **Run the setup script:**
    ```bash
    ./setup.sh
    ```
    This script will:
    - Generate a `.env` file from `.env.example`.
    - Ask you to configure `APP_NAME` and other variables in `.env` if it's the first run.
    - Setup Docker Compose and Dockerfile templates based on your `DEPLOYMENT_MODE`.

3.  **Configure environment:**
    Open the generated `.env` file and set the required variables:
    ```bash
    APP_NAME=your_app_name
    DEPLOYMENT_MODE=development # or production
    ```
    *Note: `APP_NAME` should match the directory name of your application inside the `app/` folder.*

4.  **Re-run setup:**
    After configuring `.env`, run `./setup.sh` again to apply changes and generate the final configuration files.

5.  **Run the application:**
    ```bash
    docker compose up --build -d
    ```

## Development Guide

To run your application in development mode with features like hot-reloading:

1.  **Configure `.env`**:
    Ensure your `.env` file lists development mode:
    ```bash
    DEPLOYMENT_MODE=development
    ```

2.  **Run Setup**:
    Execute `./setup.sh`. This will:
    -   Configure `docker-compose.yml` to mount your local `app/<APP_NAME>` directory into the container.
    -   Set the container command to `npm run dev`.
    -   Use `dockerfile.dev.example` which installs all dependencies (including devDependencies).
    -   (Optional) Update file ownership if `RUN_SUDOERS_SETUP=Y` is set, ensuring you can edit files locally without permission issues.

3.  **Start the container**:
    ```bash
    docker compose up --build
    ```
    You can now edit files in `app/<APP_NAME>` and see changes reflected immediately.

## Initialization Guide (Bootstrapping New Projects)

If you want to create a new Node.js/Next.js application from scratch but don't want to install Node.js locally, follow this guide.

1.  **Configure `.env`**:
    Open `.env` and set:
    ```bash
    APP_NAME=your_new_app_name
    DEPLOYMENT_MODE=initialization
    HOST_USER_ID=1000 # Your user ID (run `id -u`)
    HOST_GROUP_ID=1000 # Your group ID (run `id -g`)
    ```

2.  **Run Setup**:
    ```bash
    ./setup.sh
    ```
    This will create the directory `app/<APP_NAME>` if it doesn't exist and generate a minimal `docker-compose.yml` that mounts this directory.

3.  **Start the Initial Container**:
    ```bash
    docker compose up -d --build
    ```

4.  **Run Bootstrapping Commands**:
    Use the helper script `scripts/bootstraping/run.sh` to execute commands inside the running container.

    *Example: Create a Next.js app*
    ```bash
    # Uses a helper script to bypass Docker volume permission issues
    ./scripts/bootstraping/init-next-app.sh "npx create-next-app@latest temp --typescript --tailwind --eslint"
    ```

    *Example: Initialize Shadcn UI*
    ```bash
    ./scripts/bootstraping/run.sh "npx shadcn@latest init"
    ```

    *Example: Clean up/Reset directory (Handling wildcards)*
    ```bash
    # Use sh -c to ensure wildcards (*) are expanded inside the container, not your local shell
    ./scripts/bootstraping/run.sh sh -c "rm -rf *"
    ```

5.  **Switch to Development Mode**:
    Once your project is initialized:
    1.  Stop the init container: `docker compose down`
    2.  Edit `.env`: set `DEPLOYMENT_MODE=development`
    3.  Run `./setup.sh` again to generate the full development configuration.
    4.  Start dev server: `docker compose up -d --build`

## Configuration

### Environment Variables (.env)
The `.env` file is true source of truth for the deployment configuration.

-   **`APP_NAME`**: The name of the subdirectory in `app/` where your Node.js application code resides.
-   **`DEPLOYMENT_MODE`**:
    -   `development`: Sets up volumes for live reloading, sets ownership for dev users, and uses `dockerfile.dev.example`.
    -   `production`: Optimizes for production build using `dockerfile.example` and standard deployment settings.
-   **`NEXT_PUBLIC_*`**: Any variable starting with `NEXT_PUBLIC_` in your `.env` will be automatically extracted and passed as a build argument to Docker.

## Scripts & Tools

### `setup.sh`
The main entry point for the repository.
-   **Usage**: `./setup.sh`
-   **Function**:
    -   Merges `.env.example` from the root and `app/<APP_NAME>/`.
    -   Validates the `.env` file.
    -   Processes `docker-compose.yml` and `dockerfile` templates using `sed` for variable substitution.
    -   Injects `NEXT_PUBLIC_` variables into the build process.
    -   (Development) Handles sudoers setup and file permissions if `RUN_SUDOERS_SETUP=Y`.

### `scripts/update_env_file.sh`
A helper script to manage environment file updates safely.
-   **Usage**: `scripts/update_env_file.sh <source_example_file>`
-   **Function**:
    -   Creates a timestamped backup of the existing `.env` (e.g., `.env.backup_20231024...`).
    -   Updates `.env` with new keys from the example file while preserving existing values from the latest backup.
    -   Rotates backups (keeping the last 3).
    -   Updates `.env` with new keys from the example file while preserving existing values from the latest backup.
    -   Rotates backups (keeping the last 3).
    -   Ensures correct file ownership.

## Project Architecture & Discovery

This project uses a **Self-Documenting Architecture** system to help developers (and AI agents) understand the codebase structure and logic without reading every file.

### 1. Repository Maps
These files are generated automatically and serve as the "Source of Truth" for the project structure:
-   **`REPO_MAP.md`**: The physical layout of the repository, including file signatures (Category, Description) for every file.
-   **`REPO_MAP_ARCHITECTURE.md`**: The logical dependency tree for infrastructure and orchestration scripts.
-   **`REPO_MAP_APP_ARCHITECTURE.md`**: The logical dependency tree for the Next.js application, showing how components and pages rely on each other.

### 2. Mapping Tools
Use these scripts to regenerate the maps after making changes.

#### `scripts/generate_map.sh`
Regenerates the physical `REPO_MAP.md`.
```bash
./scripts/generate_map.sh
```

#### `scripts/generate_app_tree.sh`
Regenerates the logical dependency trees (`REPO_MAP_*_ARCHITECTURE.md`). This script allows for **Targeted Analysis** to save context and focus on specific areas.

**Usage:**
```bash
# 1. Full Regeneration (All Pages & Scripts)
./scripts/generate_app_tree.sh

# 2. Scoped Generation (Focus on specific feature)
# Example: Only map 'admin' related components and pages
./scripts/generate_app_tree.sh --scope admin

# 3. Discovery Mode (List all valid entry points and suggested scopes)
./scripts/generate_app_tree.sh --list-scopes

# 4. Help
./scripts/generate_app_tree.sh --help
```

## Project Structure

-   `app/`: Place your Node.js application source code in a subdirectory here (e.g., `app/my-web-app/`).
-   `scripts/`: Contains helper scripts for environment updates and deployment tasks.
-   `setup.sh`: Main configuration automation script.
-   `docker-compose.yml.example` & `dockerfile.*.example`: Templates used by `setup.sh` to generate actual configuration files.

## AI Agent Integration

This repository includes a `.agents/` directory that optimizes AI coding assistants (Antigravity, Gemini, Claude) for **token-efficient** operation across both Infrastructure and Application layers.

### Directory Structure

```
.agents/
├── knowledge/          # Persistent reference documents (backup of global rules, etc.)
├── rules/              # Conditional instructions loaded by model decision
│   ├── always-create-tests.md
│   ├── file-signature-enforcement.md
│   ├── how-to-scan-repository.md
│   ├── phased-execution.md
│   └── run-npm-command.md
└── skills/             # On-demand capabilities loaded only when relevant
    ├── bash-orchestration/
    ├── frontend-design/
    └── nextjs-appwrite-troubleshooting/
```

### Key Design Principles

1. **Layered Context Loading** — The agent only reads maps relevant to the current task (Infrastructure vs Application), avoiding unnecessary token consumption.
2. **5-Line File Signatures** — Every file has a machine-readable header captured by `generate_map.sh`, enabling rapid codebase navigation without reading full files.
3. **Nested "Russian Doll" Maps** — The root `REPO_MAP.md` covers DevOps files (~30 files), while `app/<APP_NAME>/REPO_MAP.md` covers the application separately. Loaded on-demand.
4. **Skills over Global Rules** — Heavy templates (e.g., bash boilerplate) are stored as skills and loaded only when needed, instead of being injected into every conversation.

### Global Rules Setup

To enable AI agent optimizations across all repositories, create a global rules file:

```bash
mkdir -p ~/.gemini
cp .agents/knowledge/gemini-global-rules.md ~/.gemini/GEMINI.md
```

This configures the agent for concise output, token conservation, and structured communication. A backup is maintained in `.agents/knowledge/gemini-global-rules.md`.

## Token-Efficient Prompting Guide

When working with AI agents in this repository, your prompting style directly impacts token consumption and cost. Follow these patterns to stay efficient.

### Quick Reference

| You Want | Say This | Why It Saves Tokens |
|---|---|---|
| Agent edits files | "Do it" / "Edit it directly" | Agent proceeds without asking |
| Agent guides you | "Guide me" / "Just show me the code" | Skips file reads + tool overhead (~15% savings) |
| Focused scope | "Only touch `setup.sh`" | Prevents unnecessary REPO_MAP reads |
| Phased work | "Let's do this in phases" | Keeps per-turn context small (critical for lightest LLM like Gemini Flash) |

### Cost Awareness

| Agent Action | Token Cost | When It Happens |
|---|---|---|
| Reading a file | ~250 tokens per 1KB | Every `view_file` call |
| Reading nested app REPO_MAP | ~20,000 tokens | When agent scans app structure |
| Editing a file | ~same as guiding | Code content is same size either way |
| Asking a clarifying question | ~50-100 tokens | Cheap — saves expensive wrong turns |

### Best Practices

1. **Be specific upfront** — "Fix the logging in `setup.sh` line 45" is cheaper than "fix the logging" (avoids exploratory reads).
2. **Name the files** — If you know which files are involved, list them. This prevents the agent from scanning REPO_MAP.
3. **Say "guide me" for simple edits** — Config changes, frontmatter updates, one-liners. You save ~15% tokens.
4. **Say "do it" for complex changes** — Multi-file refactors, new features. The precision is worth the small overhead.
5. **Use phased execution for large tasks** — Say "let's phase this" to trigger the phased-execution rule. Essential for Gemini Flash.
6. **Batch related requests** — "Add signatures to these 3 files: X, Y, Z" in one prompt beats 3 separate conversations.

---

Copyright © 2025 TILabs and ryumada. All Rights Reserved.

Licensed under the [MIT](LICENSE) license.

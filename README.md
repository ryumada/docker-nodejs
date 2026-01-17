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
    -   Ensures correct file ownership.

## Project Structure

-   `app/`: Place your Node.js application source code in a subdirectory here (e.g., `app/my-web-app/`).
-   `scripts/`: Contains helper scripts for environment updates and deployment tasks.
-   `setup.sh`: Main configuration automation script.
-   `docker-compose.yml.example` & `dockerfile.*.example`: Templates used by `setup.sh` to generate actual configuration files.

---
name: docker-nodejs-management
description: Knowledge for managing the docker-nodejs repository — setup, deployment, maintenance.
tokens: ~50
---

# Docker-NodeJS Management Skill

Use this skill when working with Node.js Docker deployment, configuration, or troubleshooting.

## Repository Overview

This toolkit deploys Node.js applications via Docker containers. Run `./setup.sh` to configure environment parameters.

## Directory Structure
- `scripts/` — maintenance and bootstrapping scripts.
- `scripts/bootstraping/run.sh` — wrapper script to run commands inside the running application container.
- `scripts/bootstraping/init-next-app.sh` — helper script to initialize a Next.js application structure.
- `app/` — local mount point for cloned or initialized Node.js projects.
- `nginx-sites-available.conf` — Nginx reverse proxy configuration.

## Critical Workflows

### Executing Commands in Container
> [!IMPORTANT]
> **ALWAYS** use `./scripts/bootstraping/run.sh` to run **ANY** `npm`, `npx`, `node`, `tsc`, `vitest`, or build/test/install commands. Node.js and npm are executed inside the Docker container (`app`). Never run `npm` or `node` directly on the host machine.

```bash
./scripts/bootstraping/run.sh <command>
# Examples:
# ./scripts/bootstraping/run.sh npm install <package>
# ./scripts/bootstraping/run.sh npm run build
# ./scripts/bootstraping/run.sh npm run dev
```

### Test Log Compression
- Always run tests with `--bail` or fail-fast flags if supported to halt execution on first failure:
  `./scripts/bootstraping/run.sh npm run test -- --bail=1`
- On test failures: locate and inspect ONLY the assertion failure message, expected vs. actual values, and exact `file:line` reference. Discard passing setup logs.

---
trigger: model_decision
category: Reference
tokens: ~40
---

Ensure every file has a 5-line signature header so `generate_map.sh` captures accurate context.

**A. Bash (`.sh`)**: `#!/usr/bin/env bash` → `set -e` → `# Category:` → `# Description:` → `# Usage:` → `# Dependencies:`

**B. Node.js / React / TypeScript (`.js`, `.ts`, `.tsx`)**: `/**` → ` * @file` → ` * @category` → ` * @description` → ` * @requires` → ` */`

**C. Dockerfiles**: `# Category:` → `# Service:` → `# Description:` → `# Maintainer:` → `FROM`

**D. Markdown (`.md`)**: YAML frontmatter: `---` → `title:` → `category:` → `description:` → `context:` → `---`

**E. Config (`.yml`, `.yaml`, `.conf`, `.env.example`)**: `# Category:` → `# File:` → `# Description:` → `# Usage:` → `# Maintainer:`

Enforcement: insert on create, update on edit.

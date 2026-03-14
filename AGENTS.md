---
title: AGENTS.md
category: Reference
description: Instructions for Cline agents to read and follow all .agents repository content
context: Root Repository
---

# Agent Instructions

## Required Protocol
1. **Identify Task Layer**: Determine if the task is **Infrastructure** (Docker, Bash) or **Application** (React, Next.js).
2. **Load Targeted Context**: Read only the maps and rules relevant to your active layer (see `.agents/rules/how-to-scan-repository.md`).
3. **Follow Standard Rules**: All active instructions reside in the `.agents/rules/` directory.

## Core Checklist
- [ ] 5-Line Signatures mandatory for all files.
- [ ] No browser testing (use logs and build status).
- [ ] Use `./scripts/bootstraping/run.sh` for npm commands.
- [ ] For design rules see `.agents/skills/frontend-design/SKILL.md`.

Refer to `.agents/rules/` for detailed protocol enforcement.

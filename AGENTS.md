---
title: AGENTS.md
category: Reference
description: Instructions for Cline agents to read and follow all .agents repository content
context: Root Repository
---

# Agent Instructions

## For New Cline Agent Sessions

**Required Reading Protocol:**
1. List .agents/* recursively
2. Read all files in .agents/knowledge/, .agents/rules/, .agents/skills/
3. Extract key instructions and integrate with REPO_MAP.md context
4. Confirm understanding of: file signatures, scanning protocols, testing requirements, command guidelines
5. Apply all .agents instructions to future tasks

## Key Requirements from .agents Repository

### File Signature Protocol
- Every file must have a 5-line signature header
- Format varies by file type (Bash, Node/TS/JS, Markdown, etc.)
- Ensures project visibility and low-token context density

### Repository Scanning Protocol
- Always check REPO_MAP.md first before answering
- **Important:** `REPO_MAP.md`, `REPO_MAP_ARCHITECTURE.md`, and `REPO_MAP_APP_ARCHITECTURE.md` are git-ignored but exist on disk. Use `read_file` with absolute paths to verify their existence—do NOT rely on glob/search results that respect `.gitignore`.
- Follow multi-layer context loading: Physical → Structural → App → Nested maps
- Derive file existence from map files, don't use `ls` or `find`

### Command Execution
- Use `./scripts/bootstraping/run.sh <command>` for npm commands
- Prefer non-interactive commands with auto-confirm flags
- Redirect stderr to stdout for error visibility

### Testing Requirements
- Always create tests after writing code
- Run `npm run test` to verify all tests pass
- Check UI components follow base design system

### Frontend Design Guidelines
- Create distinctive, production-grade interfaces
- Avoid generic AI aesthetics (Inter, purple gradients, predictable layouts)
- Use bold typography, cohesive color themes, and intentional motion

### Next.js & Appwrite Troubleshooting
- Handle hydration mismatches with "use client" directives
- Configure CSP headers properly for inline scripts
- Use timeout races for network operations to prevent hanging

## Integration with Project Context
- Cross-reference with REPO_MAP.md for project structure
- Align with file signature requirements from signature-protocol.md
- Apply repository scanning protocols from how-to-scan-repository.md
- Follow command execution guidelines from run-npm-command.md

## Verification
Before proceeding with any task, confirm:
- [ ] Understanding of file signature requirements
- [ ] Knowledge of repository scanning protocols  
- [ ] Awareness of testing requirements
- [ ] Familiarity with command execution guidelines
- [ ] Application of frontend design principles (when applicable)
- [ ] Next.js and Appwrite troubleshooting knowledge (when applicable)

**Note:** This file provides the essential instructions. For complete details, refer to the individual files in the .agent directory.
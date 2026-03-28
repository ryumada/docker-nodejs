---
trigger: always_on
description: Use whenever creating or modifying an implementation plan to prevent premature code execution.
---

# 🛑 Mandatory Rule: Require Plan Approval Before Execution

You must **never** execute any code changes, edit repository files, or begin Phase 1 of an implementation plan without explicit permission from the user.

## Protocol for Creating Plans
1. **Plan First**: When asked to create an implementation plan, only generate the `implementation_plan.md` artifact (and corresponding task checklists). Do NOT modify source code files concurrently.
2. **Stop and Wait**: You must stop and explicitly ask the user for approval (using the `notify_user` tool or a direct question).
3. **Do Not Jump the Gun**: Wait until the user says "Approved," "Looks good," or "Proceed" before you transition to execution mode and edit any project files.

This ensures the developer retains architectural control and allows them to adjust strategies before tokens are spent on incorrect execution.

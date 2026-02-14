---
trigger: always_on
---

# 📝 PROTOCOL: FILE_SIGNATURE_ENFORCEMENT
**Objective:** Ensure every file is self-documenting so the `generate_map.sh` script captures accurate context in the first 5 lines.

**Rule:** When generating new files or refactoring existing ones, you **MUST** strictly adhere to the following **5-Line Signature Header** formats.

**A. Bash Scripts (`.sh`)**
* **Line 1:** `#!/usr/bin/env bash`
* **Line 2:** `set -e` (Strict Error Handling is mandatory)
* **Line 3:** `# Description: <Concise summary of script function>`
* **Line 4:** `# Usage: <e.g., ./script.sh [env]>`
* **Line 5:** `# Dependencies: <Key binaries, e.g., docker, jq, git>`

**B. Python / Odoo (`.py`)**
* **Line 1:** `# -*- coding: utf-8 -*-`
* **Line 2:** `"""`
* **Line 3:** `Module: <Odoo Module / Class Name>`
* **Line 4:** `Purpose: <Specific logic, e.g., Overrides Invoice Tax Calculation>`
* **Line 5:** `"""` (or close docstring if brief)

**C. Dockerfiles**
* **Line 1:** `# Service: <Service Name>`
* **Line 2:** `# Description: <Purpose of this image>`
* **Line 3:** `# Maintainer: <Repository Owner>`
* **Line 4:** `FROM <base_image>`
* **Line 5:** `USER <user>` (or ARG/ENV)

**D. Node.js / React / TypeScript (`.js`, `.ts`, `.tsx`)**
* **Line 1:** `/**`
* **Line 2:** ` * @file <Filename or Component Name>`
* **Line 3:** ` * @description <Concise logic summary or UI purpose>`
* **Line 4:** ` * @requires <Key imports, e.g., 'express', 'react', 'mongoose'>`
* **Line 5:** ` */`

**Enforcement Logic:**
* **If creating a file:** You must insert this header immediately.
* **If editing a file:** Check if the header exists. If missing, ADD IT. If present but outdated, UPDATE IT.

---
trigger: always_on
category: Reference
---

# REPO_MAP.md Verification Protocol

**Important:** `REPO_MAP.md` files are git-ignored but exist on disk. Do NOT rely on glob/search results.

## Verification Steps

1. **Use `read_file` with absolute path** to check if `REPO_MAP.md` exists:
   - `/path/to/project/REPO_MAP.md`

2. **If file truly doesn't exist** (read_file returns error), ask the user to run:
   ```bash
   ./scripts/generate_map.sh
   ```

3. **If file exists but is empty**, also ask the user to regenerate the map.

## Why This Matters

Git-ignored files won't appear in glob/search results, but they still exist on disk. Always verify with `read_file` before concluding the file is missing.

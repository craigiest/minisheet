# PR Update Troubleshooting (Codex)

If Codex shows this loop:

- **"Update branch"** button appears repeatedly
- Clicking it returns: **"Codex does not currently support updating PRs that are updated outside of Codex. For now, please create a new PR."**

Use this recovery workflow:

1. Keep your current branch state as-is.
2. Create a **new PR** from the same branch/commit instead of trying to update the old Codex-tracked PR.
3. Mark the previous PR as superseded and link to the new PR.

Why this happens:

- Codex tracks PR state internally.
- If branch/PR metadata drifts from what Codex expects (even without manual edits), Codex can fail to attach updates to the existing PR and require a fresh PR record.

This document is only operational guidance and does not change runtime app behavior.

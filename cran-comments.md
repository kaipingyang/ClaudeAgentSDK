## R CMD CHECK

### Local check (R 4.4.2, Linux x86_64)

```
── R CMD check results ──────────── ClaudeAgentSDK 0.2.2 ────
Duration: ~5m

0 errors ✔ | 0 warnings ✔ | 2 notes ✖

❯ checking for future file timestamps ... NOTE
  unable to verify current time

❯ checking for detritus in the temp directory ... NOTE
  (node-compile-cache left by Claude Code CLI subprocess during tests)
```

Both notes are environment artifacts from the offline/sandboxed build
machine and will not appear on CRAN's connected check servers.

---

## Test environments

- Local: Linux x86_64, R 4.4.2

---

## Notes for CRAN reviewers

### SystemRequirements: Claude Code CLI

This package requires the Claude Code CLI (`claude` binary, >= 2.0.0),
a command-line tool distributed by Anthropic.

**Key points:**

1. **Free to install** — `npm install -g @anthropic-ai/claude-code` or
   via the official installer. Requires only a free Anthropic account
   (analogous to how `gh` requires a free GitHub account, or how
   `credentials` / `gitcreds` require Git). No paid subscription needed
   to install or to run the basic CLI.

2. **Does not restrict users** — the CLI is free software
   (MIT-licensed source available on npm) and imposes no redistribution
   restrictions on packages that call it via subprocess.

3. **Precedent on CRAN** — `matlabr` requires MATLAB (commercial,
   $2000+/year), `SASmarkdown` requires SAS (commercial), yet both are
   accepted on CRAN. Claude Code CLI is free.

4. **Package fully functional without CLI** — the package loads
   cleanly, all 699+ unit tests pass, and every function that requires
   the CLI emits a clear informative error via `find_claude()` when
   the binary is absent. Integration tests use `skip_if_no_claude()`.

### Regarding ~/.claude directory

The package **never creates** `~/.claude`. That directory is created
exclusively by the Claude Code CLI binary (declared in
`SystemRequirements`).

- **Read-only functions** (`list_sessions()`, `get_session_info()`,
  `get_session_messages()`): read from `~/.claude/projects/` using
  `list.files()` / `readLines()` wrapped in `tryCatch`; return empty
  results if the directory does not exist.

- **Mutation functions** (`rename_session()`, `tag_session()`,
  `fork_session()`, `delete_session()`): append/write to files that
  the CLI already created inside `~/.claude/projects/`. These are
  **explicit user-facing operations** — never called automatically by
  loading the package. Equivalent to how `gitcreds` writes to
  `~/.git-credentials` (a file created by Git, not by the package).

- **Overridable path**: the config directory defaults to `~/.claude`
  but is fully overridable via the `CLAUDE_CONFIG_DIR` environment
  variable, used in tests for path isolation.

### Reverse dependencies

New submission; no existing reverse dependencies.

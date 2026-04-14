# List Claude Code sessions

Scans `~/.claude/projects/` (or the project-specific sub-directory) for
`.jsonl` session files and extracts metadata from `stat` + head/tail
reads — no full JSONL parsing required.

## Usage

``` r
list_sessions(
  directory = NULL,
  limit = NULL,
  offset = 0L,
  include_worktrees = TRUE
)
```

## Arguments

- directory:

  Character or NULL. Project directory path. When provided, only
  sessions for that project (and its git worktrees when
  `include_worktrees = TRUE`) are returned. When `NULL`, all sessions
  across all projects are returned.

- limit:

  Integer or NULL. Maximum number of sessions to return.

- offset:

  Integer. Number of sessions to skip (for pagination).

- include_worktrees:

  Logical. Scan git worktrees (default `TRUE`).

## Value

List of `SDKSessionInfo` objects sorted by `last_modified` descending.

## Examples

``` r
# \donttest{
# All sessions
sessions <- list_sessions(limit = 5L)
length(sessions)
#> [1] 0

# Sessions for a specific project
sessions <- list_sessions(directory = getwd(), limit = 10L)
if (length(sessions) > 0) cat(sessions[[1]]$session_id, "\n")
# }
```

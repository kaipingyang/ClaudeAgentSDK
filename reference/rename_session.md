# Rename a session

Appends a `custom-title` JSONL entry to the session file.
[`list_sessions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/list_sessions.md)
reads the LAST custom-title from the tail, so repeated calls are safe —
most recent wins.

## Usage

``` r
rename_session(session_id, title, directory = NULL)
```

## Arguments

- session_id:

  Character. UUID of the session.

- title:

  Character. New title. Leading/trailing whitespace is stripped; must be
  non-empty after stripping.

- directory:

  Character or NULL. Project directory (same semantics as
  `list_sessions(directory = ...)`). When `NULL`, all project
  directories are searched.

## Value

Invisibly `NULL`.

## Examples

``` r
# \donttest{
sessions <- list_sessions(limit = 1L)
if (length(sessions) > 0) {
  rename_session(sessions[[1]]$session_id, "My renamed session")
}
# }
```

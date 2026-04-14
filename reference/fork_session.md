# Fork a session

Copies transcript messages from the source session into a new JSONL file
with fresh UUIDs, preserving the `parentUuid` chain. Supports
`up_to_message_id` for branching from a specific point.

## Usage

``` r
fork_session(
  session_id,
  directory = NULL,
  up_to_message_id = NULL,
  title = NULL
)
```

## Arguments

- session_id:

  Character. UUID of the source session.

- directory:

  Character or NULL. Project directory.

- up_to_message_id:

  Character or NULL. Slice transcript up to this message UUID
  (inclusive). `NULL` copies the full transcript.

- title:

  Character or NULL. Custom title for the fork. If `NULL`, derives title
  from the original + " (fork)".

## Value

Named list with `session_id` — the UUID of the new forked session.

## Examples

``` r
# \donttest{
sessions <- list_sessions(limit = 1L)
if (length(sessions) > 0) {
  forked <- fork_session(sessions[[1]]$session_id, title = "Branch A")
  forked$session_id  # UUID of the new session
}
# }
```

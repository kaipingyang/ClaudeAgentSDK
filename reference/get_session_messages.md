# Get conversation messages from a session

Reads the full JSONL transcript, reconstructs the conversation chain via
`parentUuid` links, and returns `user`/`assistant` messages in
chronological order.

## Usage

``` r
get_session_messages(session_id, directory = NULL, limit = NULL, offset = 0L)
```

## Arguments

- session_id:

  Character. UUID of the session.

- directory:

  Character or NULL. Project directory.

- limit:

  Integer or NULL. Maximum messages to return.

- offset:

  Integer. Messages to skip.

## Value

List of `SessionMessage` objects.

## Examples

``` r
# \donttest{
sessions <- list_sessions(limit = 1L)
if (length(sessions) > 0) {
  msgs <- get_session_messages(sessions[[1]]$session_id, limit = 5L)
  length(msgs)
}
# }
```

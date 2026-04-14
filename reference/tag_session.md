# Tag a session

Appends a `tag` JSONL entry. Pass `NULL` to clear the tag.
[`list_sessions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/list_sessions.md)
reads the LAST tag — most recent wins. Tags are Unicode-sanitized before
storing.

## Usage

``` r
tag_session(session_id, tag = NULL, directory = NULL)
```

## Arguments

- session_id:

  Character. UUID of the session.

- tag:

  Character or NULL. Tag string, or `NULL` to clear.

- directory:

  Character or NULL. Project directory.

## Value

Invisibly `NULL`.

## Examples

``` r
# \donttest{
sessions <- list_sessions(limit = 1L)
if (length(sessions) > 0) {
  tag_session(sessions[[1]]$session_id, "important")
  # Clear the tag
  tag_session(sessions[[1]]$session_id, NULL)
}
# }
```

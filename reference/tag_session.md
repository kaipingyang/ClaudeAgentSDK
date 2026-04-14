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

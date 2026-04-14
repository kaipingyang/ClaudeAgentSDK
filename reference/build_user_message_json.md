# Build an outgoing user-message JSON string

Build an outgoing user-message JSON string

## Usage

``` r
build_user_message_json(prompt, session_id = "default")
```

## Arguments

- prompt:

  Character(1) or list. Prompt text or content block list.

- session_id:

  Character(1). Session identifier (default `"default"`).

## Value

Character(1). JSON string ready to write to the CLI's stdin.

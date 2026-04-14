# Run Claude Code synchronously and collect all messages

Convenience wrapper around
[`claude_query()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_query.md)
that blocks until the `ResultMessage` is received and returns a
structured result list. Equivalent to the Python pattern:

    messages = []
    async for msg in query(prompt, options): messages.append(msg)

## Usage

``` r
claude_run(prompt, options = ClaudeAgentOptions(), ...)
```

## Arguments

- prompt:

  Character(1) or list.

- options:

  A `ClaudeAgentOptions` from
  [`ClaudeAgentOptions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ClaudeAgentOptions.md).

- ...:

  Named arguments passed to
  [`ClaudeAgentOptions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ClaudeAgentOptions.md),
  overriding values in `options`. E.g.
  `claude_run("...", max_turns = 1L)`.

## Value

A list of class `ClaudeRunResult` with:

- `$messages` — all messages in order

- `$result` — the `ResultMessage` (or `NULL` if not received)

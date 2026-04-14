# Query Claude Code (streaming generator)

Creates a `SubprocessCLITransport`, connects to the CLI, sends the
prompt, and returns a `coro` generator that yields typed message
objects. The generator terminates automatically after the
`ResultMessage`.

## Usage

``` r
claude_query(prompt, options = ClaudeAgentOptions(), transport = NULL)
```

## Arguments

- prompt:

  Character(1) or list. Prompt text, or a list of content blocks.

- options:

  A `ClaudeAgentOptions` from
  [`ClaudeAgentOptions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ClaudeAgentOptions.md).

- transport:

  Optional `SubprocessCLITransport` R6 object. When supplied,
  `connect()` is NOT called automatically — the caller must have already
  connected.

## Value

A `coro` generator yielding message objects (see types.R).

## Details

The caller is responsible for disconnecting the transport after the
generator is exhausted. For a simpler synchronous API see
[`claude_run()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_run.md).

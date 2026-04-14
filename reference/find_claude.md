# Find the Claude Code CLI binary

Searches common install locations and the system PATH. Raises
`claude_error_cli_not_found` if the binary cannot be found.

## Usage

``` r
find_claude(cli_path = NULL)
```

## Arguments

- cli_path:

  Character or NULL. If non-NULL, that path is validated and returned
  directly (skipping the search).

## Value

Character. Absolute path to the `claude` binary.

# Raise CLIConnectionError

Raised when a connection to the Claude Code CLI fails.

## Usage

``` r
claude_cli_connection_error(message, ...)
```

## Arguments

- message:

  Character. Human-readable description.

- ...:

  Additional fields.

## Examples

``` r
err <- tryCatch(
  claude_cli_connection_error("Connection refused"),
  error = function(e) e
)
inherits(err, "claude_error_cli_connection")
#> [1] TRUE
```

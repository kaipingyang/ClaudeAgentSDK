# Raise CLINotFoundError

Raised when the Claude Code CLI binary cannot be located.

## Usage

``` r
claude_cli_not_found(cli_path = NULL)
```

## Arguments

- cli_path:

  Character or NULL. Path that was searched, appended to the message
  when not NULL.

## Examples

``` r
err <- tryCatch(
  claude_cli_not_found("/bad/path/claude"),
  error = function(e) e
)
inherits(err, "claude_error_cli_not_found")
#> [1] TRUE
```

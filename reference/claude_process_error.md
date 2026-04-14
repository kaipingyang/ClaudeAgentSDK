# Raise ProcessError

Raised when the Claude Code CLI subprocess exits with a non-zero status.

## Usage

``` r
claude_process_error(message, exit_code = NULL, stderr = NULL, ...)
```

## Arguments

- message:

  Character. Base message.

- exit_code:

  Integer or NULL. Process exit code.

- stderr:

  Character or NULL. Captured stderr text.

- ...:

  Additional fields.

## Examples

``` r
err <- tryCatch(
  claude_process_error("Process failed", exit_code = 1L),
  error = function(e) e
)
inherits(err, "claude_error_process")
#> [1] TRUE
```

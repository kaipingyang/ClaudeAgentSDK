# Raise CLIJSONDecodeError

Raised when a line from the CLI stdout cannot be decoded as JSON.

## Usage

``` r
claude_json_decode_error(line, original_error = NULL, ...)
```

## Arguments

- line:

  Character. The raw line that failed to parse.

- original_error:

  Condition or NULL. The underlying parse error.

- ...:

  Additional fields.

## Examples

``` r
err <- tryCatch(
  claude_json_decode_error("{bad json"),
  error = function(e) e
)
inherits(err, "claude_error_json_decode")
#> [1] TRUE
```

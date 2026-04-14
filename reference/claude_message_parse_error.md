# Raise MessageParseError

Raised when a parsed JSON object cannot be converted into a typed
message.

## Usage

``` r
claude_message_parse_error(message, data = NULL, ...)
```

## Arguments

- message:

  Character. Description.

- data:

  List or NULL. The raw parsed object.

- ...:

  Additional fields.

## Examples

``` r
err <- tryCatch(
  claude_message_parse_error("Unknown message type", data = list(type = "x")),
  error = function(e) e
)
inherits(err, "claude_error_message_parse")
#> [1] TRUE
```

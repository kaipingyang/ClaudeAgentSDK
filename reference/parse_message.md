# Parse a single JSON line from the CLI into a typed message object

Parse a single JSON line from the CLI into a typed message object

## Usage

``` r
parse_message(line)
```

## Arguments

- line:

  Character(1). A single newline-delimited JSON string received from the
  CLI's stdout.

## Value

A typed message object (one of the classes defined in `types.R`), a raw
control-request list (passed through to the transport layer), or `NULL`
for unrecognized message types (forward-compatible behaviour).

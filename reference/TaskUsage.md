# Create a TaskUsage

Create a TaskUsage

## Usage

``` r
TaskUsage(total_tokens, tool_uses)
```

## Arguments

- total_tokens:

  Integer.

- tool_uses:

  Integer.

## Value

Object of class `TaskUsage`.

## Examples

``` r
usage <- TaskUsage(total_tokens = 500L, tool_uses = 3L)
usage$total_tokens
#> [1] 500
```

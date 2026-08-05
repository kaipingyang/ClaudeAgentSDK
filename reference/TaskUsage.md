# Create a TaskUsage

Create a TaskUsage

## Usage

``` r
TaskUsage(total_tokens, tool_uses, duration_ms = NULL)
```

## Arguments

- total_tokens:

  Integer.

- tool_uses:

  Integer.

- duration_ms:

  Integer. Wall-clock milliseconds for the task.

## Value

Object of class `TaskUsage`.

## Examples

``` r
usage <- TaskUsage(total_tokens = 500L, tool_uses = 3L, duration_ms = 1200L)
usage$total_tokens
#> [1] 500
```

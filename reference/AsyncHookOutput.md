# Create an AsyncHookOutput

Signals that the hook will complete asynchronously.

## Usage

``` r
AsyncHookOutput(async_timeout = NULL)
```

## Arguments

- async_timeout:

  Integer or NULL. Timeout in milliseconds.

## Value

Object of class `AsyncHookOutput`.

## Examples

``` r
out <- AsyncHookOutput(async_timeout = 5000L)
out$asyncTimeout
#> [1] 5000
```

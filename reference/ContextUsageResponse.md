# Create a ContextUsageResponse

Create a ContextUsageResponse

## Usage

``` r
ContextUsageResponse(categories, total_tokens)
```

## Arguments

- categories:

  List of `ContextUsageCategory`.

- total_tokens:

  Integer.

## Value

Object of class `ContextUsageResponse`.

## Examples

``` r
cats <- list(ContextUsageCategory("user", 1024L, "#4e79a7"))
resp <- ContextUsageResponse(cats, total_tokens = 1024L)
resp$totalTokens
#> [1] 1024
```

# Create a ThinkingConfigEnabled

Create a ThinkingConfigEnabled

## Usage

``` r
ThinkingConfigEnabled(budget_tokens)
```

## Arguments

- budget_tokens:

  Integer. Token budget for thinking.

## Value

Object of class `ThinkingConfigEnabled`.

## Examples

``` r
cfg <- ThinkingConfigEnabled(budget_tokens = 5000L)
cfg$budget_tokens
#> [1] 5000
```

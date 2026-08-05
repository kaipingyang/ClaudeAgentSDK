# Create a ThinkingConfigEnabled

Create a ThinkingConfigEnabled

## Usage

``` r
ThinkingConfigEnabled(budget_tokens, display = NULL)
```

## Arguments

- budget_tokens:

  Integer. Token budget for thinking.

- display:

  Character or NULL. `"summarized"` or `"omitted"`. See
  [`ThinkingConfigAdaptive()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ThinkingConfigAdaptive.md).

## Value

Object of class `ThinkingConfigEnabled`.

## Examples

``` r
cfg <- ThinkingConfigEnabled(budget_tokens = 5000L)
cfg$budget_tokens
#> [1] 5000
```

# Create a ThinkingConfigAdaptive

Create a ThinkingConfigAdaptive

## Usage

``` r
ThinkingConfigAdaptive(display = NULL)
```

## Arguments

- display:

  Character or NULL. `"summarized"` or `"omitted"`. Controls whether
  thinking text is returned summarized or omitted (signature-only). Opus
  4.7+ defaults to `"omitted"`; pass `"summarized"` to receive text.

## Value

Object of class `ThinkingConfigAdaptive`.

## Examples

``` r
cfg <- ThinkingConfigAdaptive()
cfg$type  # "adaptive"
#> [1] "adaptive"
```

# Create a ThinkingBlock

Create a ThinkingBlock

## Usage

``` r
ThinkingBlock(thinking, signature)
```

## Arguments

- thinking:

  Character. The thinking content.

- signature:

  Character. Signature for extended thinking.

## Value

Object of class `ThinkingBlock`.

## Examples

``` r
blk <- ThinkingBlock("Let me reason step by step...", signature = "sig123")
blk$thinking
#> [1] "Let me reason step by step..."
```

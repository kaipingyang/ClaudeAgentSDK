# Create a ContextUsageCategory

Create a ContextUsageCategory

## Usage

``` r
ContextUsageCategory(name, tokens, color, is_deferred = NULL)
```

## Arguments

- name:

  Character.

- tokens:

  Integer.

- color:

  Character.

- is_deferred:

  Logical or NULL.

## Value

Object of class `ContextUsageCategory`.

## Examples

``` r
cat <- ContextUsageCategory("user", 1024L, "#4e79a7")
cat$name
#> [1] "user"
```

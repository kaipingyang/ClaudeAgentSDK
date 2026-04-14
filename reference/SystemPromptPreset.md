# Create a SystemPromptPreset

Create a SystemPromptPreset

## Usage

``` r
SystemPromptPreset(exclude_dynamic_sections = NULL, append = NULL)
```

## Arguments

- exclude_dynamic_sections:

  Logical or NULL.

- append:

  Character or NULL. Additional instructions to append.

## Value

Object of class `SystemPromptPreset`.

## Examples

``` r
sp <- SystemPromptPreset(exclude_dynamic_sections = TRUE)
sp$type  # "preset"
#> [1] "preset"
```

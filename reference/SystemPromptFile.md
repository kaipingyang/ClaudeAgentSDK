# Create a SystemPromptFile

Create a SystemPromptFile

## Usage

``` r
SystemPromptFile(path)
```

## Arguments

- path:

  Character. Path to the system prompt file.

## Value

Object of class `SystemPromptFile`.

## Examples

``` r
sp <- SystemPromptFile("/path/to/prompt.md")
sp$path
#> [1] "/path/to/prompt.md"
```

# Create a ToolUseBlock

Create a ToolUseBlock

## Usage

``` r
ToolUseBlock(id, name, input)
```

## Arguments

- id:

  Character. Tool use ID.

- name:

  Character. Tool name.

- input:

  List. Tool input parameters.

## Value

Object of class `ToolUseBlock`.

## Examples

``` r
blk <- ToolUseBlock("tool1", "Bash", list(command = "ls -la"))
blk$name
#> [1] "Bash"
```

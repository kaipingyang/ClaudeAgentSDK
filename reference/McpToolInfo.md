# Create a McpToolInfo

Create a McpToolInfo

## Usage

``` r
McpToolInfo(name, description = NULL, annotations = NULL)
```

## Arguments

- name:

  Character.

- description:

  Character or NULL.

- annotations:

  List or NULL.

## Value

Object of class `McpToolInfo`.

## Examples

``` r
tool <- McpToolInfo("add", description = "Add two numbers")
tool$name
#> [1] "add"
```

# Create a McpServerInfo

Create a McpServerInfo

## Usage

``` r
McpServerInfo(name, version)
```

## Arguments

- name:

  Character.

- version:

  Character.

## Value

Object of class `McpServerInfo`.

## Examples

``` r
info <- McpServerInfo("my_server", "1.0.0")
info$version
#> [1] "1.0.0"
```

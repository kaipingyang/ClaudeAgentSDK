# Create a McpStatusResponse

Create a McpStatusResponse

## Usage

``` r
McpStatusResponse(mcp_servers)
```

## Arguments

- mcp_servers:

  List of `McpServerStatus`.

## Value

Object of class `McpStatusResponse`.

## Examples

``` r
resp <- McpStatusResponse(list(McpServerStatus("calc", "connected")))
length(resp$mcpServers)
#> [1] 1
```

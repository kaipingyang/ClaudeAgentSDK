# Create a ServerToolResultBlock

Result block returned for a server-side tool call. Mirrors
`ToolResultBlock`'s shape. `content` is the raw list from the API,
opaque to this layer — callers that care about a specific server tool's
result schema can inspect `content$type`.

## Usage

``` r
ServerToolResultBlock(tool_use_id, content)
```

## Arguments

- tool_use_id:

  Character. ID of the corresponding server tool use.

- content:

  List. Raw result content from the API.

## Value

Object of class `ServerToolResultBlock`.

## Examples

``` r
blk <- ServerToolResultBlock("srv1", list(type = "web_search_result"))
blk$tool_use_id
#> [1] "srv1"
```

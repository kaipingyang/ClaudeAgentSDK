# Create a McpServerStatus

Create a McpServerStatus

## Usage

``` r
McpServerStatus(
  name,
  status,
  server_info = NULL,
  error = NULL,
  config = NULL,
  scope = NULL,
  tools = NULL
)
```

## Arguments

- name:

  Character. Server name.

- status:

  Character. One of `"connected"`, `"failed"`, `"needs-auth"`,
  `"pending"`, `"disabled"`.

- server_info:

  `McpServerInfo` or NULL.

- error:

  Character or NULL.

- config:

  List or NULL.

- scope:

  Character or NULL.

- tools:

  List of `McpToolInfo` or NULL.

## Value

Object of class `McpServerStatus`.

## Examples

``` r
s <- McpServerStatus("calculator", "connected")
s$status
#> [1] "connected"
```

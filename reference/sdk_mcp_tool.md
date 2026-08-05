# Define an in-process SDK MCP tool

Creates a tool that runs *inside* the R SDK process. Pass the result to
[`create_sdk_mcp_server()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/create_sdk_mcp_server.md)
and register the server via `ClaudeAgentOptions(mcp_servers = ...)`.
This is the R analogue of the Python SDK's `tool()` decorator; it is
named `sdk_mcp_tool()` (rather than `tool()`) to avoid masking
`ellmer::tool()`.

## Usage

``` r
sdk_mcp_tool(name, description, input_schema, handler, annotations = NULL)
```

## Arguments

- name:

  Character(1). Unique tool identifier Claude uses to call it.

- description:

  Character(1). What the tool does (helps Claude decide).

- input_schema:

  List. Either a full JSON Schema (a list with `type` and `properties`),
  or a shorthand mapping parameter names to a type string (e.g.
  `list(x = "number", label = "string")`) or to a partial schema (e.g.
  `list(x = list(type = "number", description = "..."))`).

- handler:

  Function of one argument (a named list of the call arguments). It
  should return a list with a `content` field —
  `list(content = list(list(type = "text", text = "...")))` — and may
  set `isError = TRUE`. A bare character string is also accepted and
  wrapped as text content.

- annotations:

  Optional list of MCP tool annotations.

## Value

An object of class `SdkMcpTool`.

## See also

[`create_sdk_mcp_server()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/create_sdk_mcp_server.md)

## Examples

``` r
greet <- sdk_mcp_tool(
  name = "greet", description = "Greet a user",
  input_schema = list(name = "string"),
  handler = function(args) {
    list(content = list(list(type = "text",
                             text = paste0("Hello, ", args$name, "!"))))
  }
)
```

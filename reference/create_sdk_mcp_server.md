# Create an in-process SDK MCP server

Bundles
[`sdk_mcp_tool()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/sdk_mcp_tool.md)
definitions into a server configuration that runs inside the R SDK
process. Pass it inside
`ClaudeAgentOptions(mcp_servers = list(<name> = create_sdk_mcp_server(...)))`.
The R analogue of the Python SDK's `create_sdk_mcp_server()`.

## Usage

``` r
create_sdk_mcp_server(name, version = "1.0.0", tools = NULL)
```

## Arguments

- name:

  Character(1). Server identifier referenced in `mcp_servers`.

- version:

  Character(1). Informational server version.

- tools:

  List of `SdkMcpTool` objects (from
  [`sdk_mcp_tool()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/sdk_mcp_tool.md)).

## Value

An object of class `McpSdkServerConfig`: a list with `type = "sdk"`,
`name`, `version`, and an `instance` holding the tool registry. The
transport strips `instance` before forwarding the config to the CLI; the
registry stays in-process to dispatch tool calls.

## See also

[`sdk_mcp_tool()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/sdk_mcp_tool.md)

## Examples

``` r
add <- sdk_mcp_tool(
  "add", "Add two numbers", list(a = "number", b = "number"),
  function(args) list(content = list(list(
    type = "text", text = paste0("Sum: ", args$a + args$b))))
)
server <- create_sdk_mcp_server("calc", version = "1.0.0", tools = list(add))
if (FALSE) { # \dontrun{
opts <- ClaudeAgentOptions(
  mcp_servers   = list(calc = server),
  allowed_tools = "mcp__calc__add"
)
} # }
```

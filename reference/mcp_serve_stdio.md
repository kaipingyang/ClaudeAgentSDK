# Serve SDK MCP tools over stdio (newline-delimited JSON-RPC)

Runs a blocking read/serve loop that speaks the MCP stdio transport
(newline-delimited JSON-RPC 2.0) for a server created with
[`create_sdk_mcp_server()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/create_sdk_mcp_server.md).
Intended to be the body of a small `Rscript` launched by the CLI as an
**external stdio** MCP server (register it with `type = "stdio"` in
`mcp_servers`).

## Usage

``` r
mcp_serve_stdio(server, input = NULL, output = stdout())
```

## Arguments

- server:

  An `McpSdkServerConfig` from
  [`create_sdk_mcp_server()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/create_sdk_mcp_server.md).

- input, output:

  Connections to read requests from / write responses to. Default
  stdin/stdout. Exposed for testing.

## Value

Invisibly `NULL` when the input stream reaches EOF.

## Details

Unlike an in-process (`type = "sdk"`) server, a stdio server is
initialized by the CLI at startup and does **not** exhibit the ~50s
first-message stall that in-process servers hit when the client
connection idles before the first message. It depends only on `jsonlite`
— no `ellmer`/`curl`.

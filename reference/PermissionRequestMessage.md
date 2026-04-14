# Create a PermissionRequestMessage

Yielded by the message stream when a `can_use_tool` control request
arrives and no handler (`can_use_tool` / `on_tool_request`) is
configured. The caller must eventually call
[ClaudeSDKClient](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ClaudeSDKClient.md)`$approve_tool()`
or `$deny_tool()` with the `request_id` to unblock the CLI.

## Usage

``` r
PermissionRequestMessage(
  request_id,
  tool_name,
  tool_input,
  tool_use_id = NULL,
  agent_id = NULL,
  suggestions = NULL
)
```

## Arguments

- request_id:

  Character. Unique ID for this control request.

- tool_name:

  Character. Name of the tool Claude wants to use.

- tool_input:

  List. Input arguments for the tool.

- tool_use_id:

  Character or NULL.

- agent_id:

  Character or NULL.

- suggestions:

  List or NULL. Permission suggestions from the CLI.

## Value

Object of class `PermissionRequestMessage`.

## Examples

``` r
msg <- PermissionRequestMessage(
  request_id = "req1",
  tool_name  = "Bash",
  tool_input = list(command = "ls /tmp")
)
msg$tool_name
#> [1] "Bash"
```

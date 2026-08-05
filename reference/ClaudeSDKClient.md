# ClaudeSDKClient R6 Class

Provides a stateful, bidirectional connection to the Claude Code CLI.
Supports sending multiple prompts, receiving streamed responses, runtime
permission-mode changes, interrupts, and MCP server management.

## Lifecycle

    client <- ClaudeSDKClient$new(ClaudeAgentOptions(model = "claude-opus-4-6"))
    client$connect()
    client$send("Hello, Claude!")
    coro::loop(for (msg in client$receive_response()) {
      if (inherits(msg, "AssistantMessage")) cat(msg$content[[1]]$text)
    })
    client$disconnect()

## Public fields

- `options`:

  The `ClaudeAgentOptions` used by this client.

## Active bindings

- `session_id`:

  The `session_id` captured from the most recent `ResultMessage`. Empty
  string `""` if no turn has completed yet. Use with
  `ClaudeAgentOptions(resume = client$session_id)` or call
  `client$resume()` to set up the client for the next turn.

## Methods

### Public methods

- [`ClaudeSDKClient$new()`](#method-ClaudeSDKClient-initialize)

- [`ClaudeSDKClient$connect()`](#method-ClaudeSDKClient-connect)

- [`ClaudeSDKClient$disconnect()`](#method-ClaudeSDKClient-disconnect)

- [`ClaudeSDKClient$send()`](#method-ClaudeSDKClient-send)

- [`ClaudeSDKClient$query()`](#method-ClaudeSDKClient-query)

- [`ClaudeSDKClient$poll_messages()`](#method-ClaudeSDKClient-poll_messages)

- [`ClaudeSDKClient$receive_messages()`](#method-ClaudeSDKClient-receive_messages)

- [`ClaudeSDKClient$receive_response()`](#method-ClaudeSDKClient-receive_response)

- [`ClaudeSDKClient$receive_response_async()`](#method-ClaudeSDKClient-receive_response_async)

- [`ClaudeSDKClient$approve_tool()`](#method-ClaudeSDKClient-approve_tool)

- [`ClaudeSDKClient$deny_tool()`](#method-ClaudeSDKClient-deny_tool)

- [`ClaudeSDKClient$interrupt()`](#method-ClaudeSDKClient-interrupt)

- [`ClaudeSDKClient$set_permission_mode()`](#method-ClaudeSDKClient-set_permission_mode)

- [`ClaudeSDKClient$set_model()`](#method-ClaudeSDKClient-set_model)

- [`ClaudeSDKClient$rewind_files()`](#method-ClaudeSDKClient-rewind_files)

- [`ClaudeSDKClient$stop_task()`](#method-ClaudeSDKClient-stop_task)

- [`ClaudeSDKClient$get_mcp_status()`](#method-ClaudeSDKClient-get_mcp_status)

- [`ClaudeSDKClient$get_context_usage()`](#method-ClaudeSDKClient-get_context_usage)

- [`ClaudeSDKClient$get_server_info()`](#method-ClaudeSDKClient-get_server_info)

- [`ClaudeSDKClient$reconnect_mcp_server()`](#method-ClaudeSDKClient-reconnect_mcp_server)

- [`ClaudeSDKClient$toggle_mcp_server()`](#method-ClaudeSDKClient-toggle_mcp_server)

- [`ClaudeSDKClient$resume()`](#method-ClaudeSDKClient-resume)

- [`ClaudeSDKClient$clone()`](#method-ClaudeSDKClient-clone)

------------------------------------------------------------------------

### `ClaudeSDKClient$new()`

Create a new ClaudeSDKClient.

#### Usage

    ClaudeSDKClient$new(options = ClaudeAgentOptions(), transport = NULL)

#### Arguments

- `options`:

  A `ClaudeAgentOptions` from
  [`ClaudeAgentOptions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ClaudeAgentOptions.md).

- `transport`:

  Optional `SubprocessCLITransport`. When supplied the client uses it
  directly instead of creating one.

------------------------------------------------------------------------

### `ClaudeSDKClient$connect()`

Connect to Claude Code.

#### Usage

    ClaudeSDKClient$connect(prompt = NULL)

#### Arguments

- `prompt`:

  Character(1) or NULL. Optional initial prompt to send immediately
  after connecting.

------------------------------------------------------------------------

### `ClaudeSDKClient$disconnect()`

Disconnect from Claude Code and clean up.

#### Usage

    ClaudeSDKClient$disconnect()

------------------------------------------------------------------------

### `ClaudeSDKClient$send()`

Send a new prompt to Claude.

#### Usage

    ClaudeSDKClient$send(prompt, session_id = "default")

#### Arguments

- `prompt`:

  Character(1) or list. Prompt text or list of content blocks.

- `session_id`:

  Character(1). Session identifier (default `"default"`).

------------------------------------------------------------------------

### `ClaudeSDKClient$query()`

Send a new request in streaming mode. Alias for `send()` that matches
the Python SDK's `client.query()` API.

#### Usage

    ClaudeSDKClient$query(prompt, session_id = "default")

#### Arguments

- `prompt`:

  Character(1) or list. Prompt text or list of content blocks.

- `session_id`:

  Character(1). Session identifier (default `"default"`).

------------------------------------------------------------------------

### `ClaudeSDKClient$poll_messages()`

Non-blocking single-cycle poll. Returns a list of messages available
right now (may be empty). Designed for Shiny `observe()` +
`invalidateLater()` polling patterns where
[`later::later()`](https://later.r-lib.org/reference/later.html)-based
approaches starve input processing.

#### Usage

    ClaudeSDKClient$poll_messages()

#### Returns

List of typed message objects (may be empty).

------------------------------------------------------------------------

### `ClaudeSDKClient$receive_messages()`

Return a `coro` generator that yields ALL messages (no automatic stop).
Use `receive_response()` for a single request/response cycle.

#### Usage

    ClaudeSDKClient$receive_messages()

------------------------------------------------------------------------

### `ClaudeSDKClient$receive_response()`

Return a `coro` generator that yields messages until and including the
next `ResultMessage`, then stops. The `session_id` from the
`ResultMessage` is automatically captured; read it back with
`client$session_id` after the loop completes.

#### Usage

    ClaudeSDKClient$receive_response()

------------------------------------------------------------------------

### `ClaudeSDKClient$receive_response_async()`

Return a
[`promises::promise`](https://rstudio.github.io/promises/reference/promise.html)
that resolves to the next `ResultMessage`. Each intermediate message is
passed to `on_message` as it arrives. Requires the **promises** package
(listed in Suggests).

Designed for Shiny `ExtendedTask` integration: the promise keeps the
Shiny session unblocked while `on_message` streams intermediate results
(e.g., into a `reactiveVal`) for real-time UI updates.

The `session_id` from the `ResultMessage` is automatically captured;
read it back with `client$session_id` after the promise resolves.

#### Usage

    ClaudeSDKClient$receive_response_async(on_message = NULL, poll_interval = 0.01)

#### Arguments

- `on_message`:

  Function(msg) or NULL. Called for every message (AssistantMessage,
  SystemMessage, StreamEvent, PermissionRequestMessage, etc.) except the
  final ResultMessage. Handle `PermissionRequestMessage` here and call
  `client$approve_tool()` / `client$deny_tool()` to continue.

- `poll_interval`:

  Numeric. Seconds between non-blocking polls (default 0.01 = 10 ms).

#### Returns

A
[`promises::promise`](https://rstudio.github.io/promises/reference/promise.html)
that resolves to the `ResultMessage`.

------------------------------------------------------------------------

### `ClaudeSDKClient$approve_tool()`

Approve a pending tool request. Call this after receiving a
`PermissionRequestMessage` from the message stream to allow the tool to
execute.

#### Usage

    ClaudeSDKClient$approve_tool(
      request_id,
      updated_input = NULL,
      updated_permissions = NULL
    )

#### Arguments

- `request_id`:

  Character. The `request_id` from the `PermissionRequestMessage`.

- `updated_input`:

  List or NULL. Modified tool input (default: use original input).

- `updated_permissions`:

  List of `PermissionUpdate` or NULL. Permission rule changes to persist
  into project/user settings. Each entry is serialized to camelCase wire
  format before sending. The CLI writes these rules to settings after
  processing the response, making them permanent for future tool calls.

#### Examples

    # Allow once (no rule written)
    client$approve_tool(rid)

    # Allow and persist rule to project settings
    client$approve_tool(rid, updated_permissions = list(
      PermissionUpdate("addRules",
        rules    = list(PermissionRuleValue("Bash", "allow")),
        behavior = "allow",
        destination = "projectSettings"
      )
    ))

------------------------------------------------------------------------

### `ClaudeSDKClient$deny_tool()`

Deny a pending tool request.

#### Usage

    ClaudeSDKClient$deny_tool(
      request_id,
      message = "Denied by user",
      interrupt = FALSE
    )

#### Arguments

- `request_id`:

  Character. The `request_id` from the `PermissionRequestMessage`.

- `message`:

  Character. Reason for denial (default `"Denied by user"`).

- `interrupt`:

  Logical. If `TRUE`, ask the CLI to interrupt the running task entirely
  after denying (default `FALSE`).

------------------------------------------------------------------------

### `ClaudeSDKClient$interrupt()`

Send an interrupt control request.

#### Usage

    ClaudeSDKClient$interrupt()

------------------------------------------------------------------------

### `ClaudeSDKClient$set_permission_mode()`

Change the permission mode at runtime.

#### Usage

    ClaudeSDKClient$set_permission_mode(mode)

#### Arguments

- `mode`:

  Character. One of `"default"`, `"acceptEdits"`, `"bypassPermissions"`,
  `"plan"`, `"dontAsk"`, `"auto"`.

------------------------------------------------------------------------

### `ClaudeSDKClient$set_model()`

Change the AI model at runtime.

#### Usage

    ClaudeSDKClient$set_model(model = NULL)

#### Arguments

- `model`:

  Character or NULL. Model ID, or NULL for default.

------------------------------------------------------------------------

### `ClaudeSDKClient$rewind_files()`

Rewind tracked files to their state at a specific user message. Requires
`enable_file_checkpointing = TRUE`.

#### Usage

    ClaudeSDKClient$rewind_files(user_message_id)

#### Arguments

- `user_message_id`:

  Character. UUID of the target user message.

------------------------------------------------------------------------

### `ClaudeSDKClient$stop_task()`

Stop a running task by ID.

#### Usage

    ClaudeSDKClient$stop_task(task_id)

#### Arguments

- `task_id`:

  Character. Task ID from a `TaskNotificationMessage`.

------------------------------------------------------------------------

### `ClaudeSDKClient$get_mcp_status()`

Get MCP server connection status.

#### Usage

    ClaudeSDKClient$get_mcp_status(timeout_ms = 30000L)

#### Arguments

- `timeout_ms`:

  Integer. Milliseconds to wait for response (default 30 000).

#### Returns

Named list with `mcpServers` key, or `NULL` on timeout.

------------------------------------------------------------------------

### `ClaudeSDKClient$get_context_usage()`

Get context window usage breakdown.

#### Usage

    ClaudeSDKClient$get_context_usage(timeout_ms = 30000L)

#### Arguments

- `timeout_ms`:

  Integer. Milliseconds to wait for response (default 30 000).

#### Returns

Named list with token counts by category, or `NULL` on timeout.

------------------------------------------------------------------------

### `ClaudeSDKClient$get_server_info()`

Get server initialization info.

#### Usage

    ClaudeSDKClient$get_server_info()

#### Returns

List with server capabilities, or NULL.

------------------------------------------------------------------------

### `ClaudeSDKClient$reconnect_mcp_server()`

Reconnect a failed MCP server.

#### Usage

    ClaudeSDKClient$reconnect_mcp_server(server_name)

#### Arguments

- `server_name`:

  Character. Server name.

------------------------------------------------------------------------

### `ClaudeSDKClient$toggle_mcp_server()`

Enable or disable an MCP server.

#### Usage

    ClaudeSDKClient$toggle_mcp_server(server_name, enabled)

#### Arguments

- `server_name`:

  Character. Server name.

- `enabled`:

  Logical. `TRUE` to enable, `FALSE` to disable.

------------------------------------------------------------------------

### `ClaudeSDKClient$resume()`

Prepare client to resume the last captured session. Sets
`options$resume` to the `session_id` captured from the most recent
`ResultMessage`. The next `$connect()` call will pass
`--resume <session_id>` to the CLI.

#### Usage

    ClaudeSDKClient$resume()

#### Returns

`self` invisibly (for chaining).

------------------------------------------------------------------------

### `ClaudeSDKClient$clone()`

The objects of this class are cloneable with this method.

#### Usage

    ClaudeSDKClient$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
if (FALSE) { # \dontrun{
# Multi-turn conversation
client <- ClaudeSDKClient$new(ClaudeAgentOptions(max_turns = 3L))
client$connect()

client$send("What is the capital of France?")
coro::loop(for (msg in client$receive_response()) {
  if (inherits(msg, "AssistantMessage")) {
    for (blk in msg$content)
      if (inherits(blk, "TextBlock")) cat(blk$text, "\n")
  }
})

client$disconnect()
} # }

## ------------------------------------------------
## Method `ClaudeSDKClient$approve_tool()`
## ------------------------------------------------

if (FALSE) { # \dontrun{
# Allow once (no rule written)
client$approve_tool(rid)

# Allow and persist rule to project settings
client$approve_tool(rid, updated_permissions = list(
  PermissionUpdate("addRules",
    rules    = list(PermissionRuleValue("Bash", "allow")),
    behavior = "allow",
    destination = "projectSettings"
  )
))
} # }
```

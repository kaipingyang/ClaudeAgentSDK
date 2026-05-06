# ClaudeAgentSDK — Developer Notes

R implementation of the Claude Agent SDK. Mirrors the Python SDK
(`claude-agent-sdk-python/`) at the API level; idiomatic R internals.

## Architecture

    R/
      types.R            # S3 constructors for all message/block/config/hook/thinking types
      errors.R           # S3 error constructors (claude_error, cli_not_found, …)
      options.R          # ClaudeAgentOptions() — validated options object
      protocol.R         # parse_message(), build_*_json() — JSON <-> typed objects
      transport.R        # SubprocessCLITransport R6 — subprocess + control protocol
      client.R           # ClaudeSDKClient R6 — stateful multi-turn client
      query.R            # claude_run() / claude_query() — one-shot API
      sessions.R         # list_sessions(), get_session_info(), get_session_messages()
      session_mutations.R# rename_session(), tag_session(), delete_session(), fork_session()
      utils.R            # %||%, find_claude(), list_skills(), r_mcp_server(), …

### Key design decisions

**`SubprocessCLITransport`** spawns
`claude --output-format stream-json --input-format stream-json --verbose`,
reads newline-delimited JSON from stdout, and handles the bidirectional
control protocol: - `wait_for_initialize()` — sends the SDK’s
`initialize` control request and waits for the CLI’s `control_response`.
Captures the response in `private$init_result` (exposed via
`get_init_result()`). - `send_and_wait()` — synchronous polling loop for
control requests that return data (mirrors Python’s async
`_send_control_request`). Safe only when called *between* generator
iterations. - `receive_messages()` — `coro` generator; routes
`control_request` and `control_cancel_request` internally, yields all
other message types. - `read_available_messages()` — non-blocking
single-cycle read (0ms `poll_io`). Returns a list of parsed SDK
messages; control requests handled internally. Used by
`receive_response_async()` for event-loop-friendly polling.

**Agents** are sent as a named dict `{name: config}` via the
`initialize` control request (not CLI args). `AgentDefinition` stores
fields in snake_case; `build_agents_config()` converts to camelCase
(`disallowed_tools` -\> `disallowedTools`, `mcp_servers` -\>
`mcpServers`, etc.) during serialization.

**Session mutations** (`session_mutations.R`) operate directly on
`~/.claude/projects/` JSONL files without a CLI connection. Append-only
for rename/tag (most-recent-wins semantics), file deletion for delete,
UUID-remapping copy for fork.

**`.simple_hash()`** uses double arithmetic with modulo
(`%% 4294967296`) instead of `bitwAnd` to avoid R’s 32-bit integer
overflow.

**`.extract_last_json_string_field()`** uses
`length(m) == 1L && m[[1L]] == -1L` instead of `identical(m, -1L)`
because `gregexpr` returns `-1L` with attributes.

**Rate limit event wire format** uses both snake_case (`resets_at`,
`overage_status`) and camelCase (`resetsAt`, `overageStatus`) depending
on CLI version. The parser checks both with `%||%` fallback.

**Async tool approval** requires `permission_prompt_tool_name = "stdio"`
in `ClaudeAgentOptions`. - **Message-driven**
(`PermissionRequestMessage` + `approve_tool/deny_tool`): When no
`can_use_tool` sync handler is configured, `can_use_tool` requests yield
`PermissionRequestMessage` through the message stream. The request is
stored in `private$pending_permissions` (an `env`).
`client$approve_tool(request_id)` / `client$deny_tool(request_id)`
resolve it. Use this with `coro::async + poll_messages` for reliable
interrupt support (example 15). - **Sync callback** (`can_use_tool`):
`ClaudeAgentOptions(can_use_tool = function(name, input, ctx) PermissionResultAllow())`
— handled synchronously in the transport, no Shiny support.

### Type system

All types are lightweight S3 classes (named lists with `class`
attribute). Types mirror Python SDK’s `types.py`:

- **Content blocks**: `TextBlock`, `ThinkingBlock`, `ToolUseBlock`,
  `ToolResultBlock`
- **Messages**: `UserMessage`, `AssistantMessage`, `SystemMessage`,
  `ResultMessage`, `StreamEvent`, `RateLimitEvent`
- **Task messages**: `TaskStartedMessage`, `TaskProgressMessage`,
  `TaskNotificationMessage`
- **Permission**: `PermissionResultAllow`, `PermissionResultDeny`,
  `PermissionRuleValue`, `PermissionUpdate`
- **Hook inputs**: `PreToolUseHookInput`, `PostToolUseHookInput`,
  `PostToolUseFailureHookInput`, `UserPromptSubmitHookInput`,
  `StopHookInput`, `SubagentStopHookInput`, `PreCompactHookInput`,
  `NotificationHookInput`, `SubagentStartHookInput`,
  `PermissionRequestHookInput`
- **Hook outputs**: `SyncHookOutput`, `AsyncHookOutput`
- **System prompt**: `SystemPromptPreset`, `SystemPromptFile`
- **Sandbox**: `SandboxSettings`, `SandboxNetworkConfig`,
  `SandboxIgnoreViolations`
- **MCP status**: `McpToolInfo`, `McpServerInfo`, `McpServerStatus`,
  `McpStatusResponse`
- **Thinking config**: `ThinkingConfigAdaptive`,
  `ThinkingConfigEnabled`, `ThinkingConfigDisabled`
- **Task/Context**: `TaskBudget`, `TaskUsage`, `ContextUsageCategory`,
  `ContextUsageResponse`
- **Agent/Hook config**: `AgentDefinition` (13 fields), `HookMatcher`
- **Session**: `SDKSessionInfo`, `SessionMessage` (internal)

## Running tests

``` r

devtools::test()
```

643+ tests. Integration tests require a real Claude Code CLI and skip
automatically if not found.

### Test files

| File | Coverage | Needs CLI |
|----|----|----|
| `test-types.R` | S3 constructors, AgentDefinition (all 13 fields), hook input/output types, permission types, system prompt types, sandbox types | No |
| `test-errors.R` | Error constructors | No |
| `test-options.R` | ClaudeAgentOptions defaults and storage | No |
| `test-protocol.R` | parse_message (user/assistant/system/result/stream/rate_limit/control), builders, hook conversion, agents camelCase | No |
| `test-transport-build-command.R` | All CLI flag combinations (33+ scenarios) | No |
| `test-sessions-unit.R` | validate_uuid, sanitize_path, simple_hash, JSON field extraction, sort_and_slice, list_sessions with mock data, get_session_messages chain reconstruction | No |
| `test-session-mutations.R` | rename/tag/delete/fork (file I/O) | No |
| `test-client-unit.R` | Client lifecycle without CLI (disconnect/send/interrupt/receive_response_async before connect) | No |
| `test-rate-limit-event.R` | Rate limit event parsing: allowed_warning, rejected with overage, minimal fields, forward compat | No |
| `test-buffering.R` | split_lines_with_buffer edge cases: split reads, large JSON, mixed complete/partial, non-JSON debug lines | No |
| `test-query.R` | claude_run, claude_query, ClaudeSDKClient lifecycle | **Yes** |
| `test-integration.R` | Full integration: get_server_info, set_permission_mode, set_model, interrupt, agents init, exclude_dynamic_sections, partial messages, StreamEvent, get_context_usage, get_mcp_status, multi-turn, stderr callback, can_use_tool, structured output, sessions list/info/messages, receive_response_async | **Yes** |

## GitHub

Remote: `https://github.com/kaipingyang/ClaudeAgentSDK`

Push without `gh` CLI (token in `~/.Renviron`):

``` bash
source ~/.Renviron
git push https://kaipingyang:${GITHUB_TOKEN}@github.com/kaipingyang/ClaudeAgentSDK.git main
```

## Development scripts

    scripts/
      pre-push          # Git pre-push hook — runs devtools::test() before allowing push
      initial-setup.sh  # Installs pre-push hook into .git/hooks/

Install: `bash scripts/initial-setup.sh`

## Python SDK parity assessment (as of v0.2.0, 2026-05-06)

| Module | Parity | Notes |
|----|----|----|
| Options fields | 97% | 38/39 fields; `debug_stderr` (deprecated Python-only); `TaskBudget` field renamed `max_tokens`→`total` (bug fixed) |
| Session management | 99% | 7 functions covered; [`fork_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/fork_session.md) returns plain list vs Python’s `ForkSessionResult` dataclass |
| Error types | 100% | 6 error types identical; R uses [`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html) S3 conditions vs Python class hierarchy |
| Type definitions | 88% | R missing: SDK MCP types (`SdkMcpTool`, `McpSdkServerConfig`, typed MCP config variants), hook-specific output TypedDicts, `ToolPermissionContext` dataclass, abstract `Transport` base class, union type aliases; `TaskUsage` now includes `duration_ms` (bug fixed) |
| Client methods | 100% Python + R extras | All 15 Python methods covered; R adds 6: `poll_messages()`, `receive_response_async()`, `approve_tool()`, `deny_tool()`, `resume()`, `session_id` active binding |
| Transport/Protocol | 85% | Functionally equivalent; R adds `send_and_wait()`, `read_available_messages()`, pending-permission API; no abstract `Transport` interface |
| Public API | 80% | R missing: `create_sdk_mcp_server()`/`@tool`, `Transport` ABC, `ForkSessionResult`, union type aliases, hook-specific output types, `ToolPermissionContext`; R adds [`find_claude()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/find_claude.md), [`list_skills()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/list_skills.md), [`r_mcp_server()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/r_mcp_server.md), `PermissionRequestMessage` |
| Examples | 85% | R has 23 examples vs Python 16; Python-only: async runtime variants (trio/ipython) + plugin example (N/A for R); R-only: 10 Shiny integration examples |
| Tests | 663 | All pass; 3 env-dependent skips |

### Why Options fields is 97% (not 100%)

`debug_stderr` in Python is a deprecated file-like object for debug
output, kept only for backwards compatibility. R never had this param
and has no legacy users to support.

### Why Type definitions is 88% (not 100%)

**SDK MCP types** (`SdkMcpTool`, `McpSdkServerConfig`, etc.): Python’s
in-process MCP server requires typed config objects. R uses `mcptools`
subprocess instead — same protocol, no need for in-process type
hierarchy.

**Hook-specific output TypedDicts** (`PreToolUseHookSpecificOutput`,
etc.): Python exports these as distinct typed dicts for each hook phase.
R `SyncHookOutput`/`AsyncHookOutput` cover all phases generically —
functionally equivalent, less granular typing.

**`ToolPermissionContext` dataclass**: Python passes a typed dataclass
with `signal`, `suggestions`, `tool_use_id`, `agent_id` fields to
`can_use_tool` callbacks. R passes a plain named list with the same
fields. Structurally equivalent.

**Abstract `Transport` base class**: Python exports this so users can
implement custom transports. R only has the internal
`SubprocessCLITransport`. There is only one transport implementation, so
an abstract base adds no value for R users.

**Union type aliases** (`ContentBlock`, `Message`, `ThinkingConfig`,
etc.): Python exports these for static type checking. R is dynamically
typed; these are redundant.

### Why Public API is 80% (not 100%)

Python’s `create_sdk_mcp_server()` runs an MCP server **in-process**
(same Python event loop). R is single-threaded and synchronous — running
an MCP server in the same process while also communicating with the CLI
subprocess would require complex `later`/`callr` coordination. The
`mcptools` package provides equivalent functionality via a subprocess
MCP server, which uses the same protocol and covers 99% of use cases.
The only loss is shared-memory access to the main R process.

The remaining missing exports are type aliases and abstract base classes
— see “Type definitions” above.

### Why Examples is 85% (not 100%)

Python has `streaming_mode_trio.py`, `streaming_mode_ipython.py`
(multiple async runtime examples) and `plugin_example.py`. R has only
one concurrency model (`coro`), so async variant examples are N/A.
Plugin support in R is not yet documented.

### Known remaining gaps

- `rewind_files()` / `stop_task()` — fire-and-forget control messages,
  no integration test
- `ForkSessionResult` S3 class —
  [`fork_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/fork_session.md)
  returns plain `list(session_id = ...)` instead of typed object
- SDK-managed MCP servers (Python’s `create_sdk_mcp_server`) — R uses
  `mcptools` subprocess instead
- Large MCP output handling (`CLAUDE_MCP_OUTPUT_MAX_TOKENS`) — not
  implemented
- Plugin support — examples exist but no integration test
- `ToolPermissionContext` S3 class — plain list passed to `can_use_tool`
  callbacks instead of typed object

## Shiny integration patterns

### 流式输出 + 可靠打断（推荐模式）

使用 [`coro::async`](https://coro.r-lib.org/reference/async.html) +
`poll_messages()` + `ExtendedTask`。
[`later::later()`](https://later.r-lib.org/reference/later.html)
轮询（`receive_response_async` 内部用法）在 Shiny 中优先于输入事件，
导致打断按钮只有在 promise
结束后才生效。[`await()`](https://coro.r-lib.org/reference/async.html)
模式每次让出 R 事件循环， 使 `observeEvent` 能在 token 之间触发。

``` r

library(coro); library(promises)

interrupt_flag <- reactiveVal(FALSE)

do_stream <- coro::async(function(client, interrupt_flag, session) {
  chunk_started <- FALSE
  interrupted   <- FALSE

  repeat {
    msgs <- tryCatch(client$poll_messages(), error = function(e) list())

    if (length(msgs) == 0L) {
      # 无消息时等 50ms（让 Shiny 处理输入事件）
      await(promises::promise(function(resolve, reject) {
        later::later(function() resolve(TRUE), 0.05)
      }))
      next
    }

    for (msg in msgs) {
      await(promises::promise_resolve(TRUE))  # 每条消息间让出事件循环

      if (shiny::isolate(interrupt_flag())) { interrupted <- TRUE; break }

      if (inherits(msg, "StreamEvent") && ...) { ... }   # 追加 token
      if (inherits(msg, "ResultMessage")) { ...; return("done") }
    }
    if (interrupted) break
  }

  if (interrupted) {
    tryCatch(client$interrupt(), error = function(e) NULL)
    # 追加 "[Interrupted]" 消息
  }
  "done"
})

stream_task <- ExtendedTask$new(function(user_input) {
  client$send(user_input)
  do_stream(client, interrupt_flag, session)
})

# JS: ESC → priority:'event' 确保立即触发，不被 later 回调淹没
# tags$script(HTML("document.addEventListener('keydown', function(e) {
#   if (e.key === 'Escape') Shiny.setInputValue('esc', Math.random(), {priority:'event'});
# });"))

observeEvent(input$chat_user_input, {
  if (stream_task$status() == "running") return()
  interrupt_flag(FALSE)
  stream_task$invoke(input$chat_user_input)
})
observeEvent(input$esc, { if (stream_task$status() == "running") interrupt_flag(TRUE) })
```

### 工具审批 + 打断（消息驱动模式）

在上述模式基础上，在 coro::async 循环中处理 `PermissionRequestMessage`：

``` r

# ClaudeAgentOptions 设置 permission_prompt_tool_name = "stdio"
# 不传 on_tool_request → can_use_tool 自动变成 PermissionRequestMessage

pending_id <- reactiveVal(NULL)

# 在 do_stream 循环中：
if (inherits(msg, "PermissionRequestMessage")) {
  pending_id(msg$request_id)
  showModal(modalDialog(..., footer = tagList(
    actionButton("tool_allow", "Allow"), actionButton("tool_deny", "Deny")
  )), session = session)
  next  # 继续轮询（CLI 此时阻塞等待 control_response）
}

# 审批按钮（在轮询 await 间隙触发）
observeEvent(input$tool_allow, {
  rid <- pending_id()
  if (!is.null(rid)) { pending_id(NULL); removeModal(); client$approve_tool(rid) }
})
```

完整示例见 `examples/15_shinychat_tool_approval_msgdriven.R`。

### receive_response_async 的适用场景

`receive_response_async(on_message)` 适合： -
不需要流式打断（等待完整回复后显示） - 工具审批期间不需要打断（弹窗时
later 不阻塞） - 简单集成（代码量更少）

完整示例见 `examples/14_shinychat_simple.R`（非流式）。

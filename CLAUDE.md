# ClaudeAgentSDK — Developer Notes

R implementation of the Claude Agent SDK. Mirrors the Python SDK (`claude-agent-sdk-python/`) at the API level; idiomatic R internals.

## Architecture

```
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
```

### Key design decisions

**`SubprocessCLITransport`** spawns `claude --output-format stream-json --input-format stream-json --verbose`, reads newline-delimited JSON from stdout, and handles the bidirectional control protocol:
- `wait_for_initialize()` — sends the SDK's `initialize` control request and waits for the CLI's `control_response`. Captures the response in `private$init_result` (exposed via `get_init_result()`).
- `send_and_wait()` — synchronous polling loop for control requests that return data (mirrors Python's async `_send_control_request`). Safe only when called *between* generator iterations.
- `receive_messages()` — `coro` generator; routes `control_request` and `control_cancel_request` internally, yields all other message types.
- `read_available_messages()` — non-blocking single-cycle read (0ms `poll_io`). Returns a list of parsed SDK messages; control requests handled internally. Used by `receive_response_async()` for event-loop-friendly polling.

**Agents** are sent as a named dict `{name: config}` via the `initialize` control request (not CLI args). `AgentDefinition` stores fields in snake_case; `build_agents_config()` converts to camelCase (`disallowed_tools` -> `disallowedTools`, `mcp_servers` -> `mcpServers`, etc.) during serialization.

**Session mutations** (`session_mutations.R`) operate directly on `~/.claude/projects/` JSONL files without a CLI connection. Append-only for rename/tag (most-recent-wins semantics), file deletion for delete, UUID-remapping copy for fork.

**`.simple_hash()`** uses double arithmetic with modulo (`%% 4294967296`) instead of `bitwAnd` to avoid R's 32-bit integer overflow.

**`.extract_last_json_string_field()`** uses `length(m) == 1L && m[[1L]] == -1L` instead of `identical(m, -1L)` because `gregexpr` returns `-1L` with attributes.

**Rate limit event wire format** uses both snake_case (`resets_at`, `overage_status`) and camelCase (`resetsAt`, `overageStatus`) depending on CLI version. The parser checks both with `%||%` fallback.

**Async tool approval** (`on_tool_request`): When `receive_response_async(on_tool_request = ...)` is called, the transport's `tool_request_callback` is set. During `read_available_messages()`, if a `can_use_tool` control request arrives and the callback is set, `handle_permission_request_async()` builds a one-shot `resolve` closure and calls the callback without sending the response. The response is sent later when `resolve()` is called (e.g., from a Shiny button handler). The callback is cleared via `promises::finally()` when the promise settles. The sync `receive_messages()` path is unaffected. Requires `permission_prompt_tool_name = "stdio"` in options.

### Type system

All types are lightweight S3 classes (named lists with `class` attribute). Types mirror Python SDK's `types.py`:

- **Content blocks**: `TextBlock`, `ThinkingBlock`, `ToolUseBlock`, `ToolResultBlock`
- **Messages**: `UserMessage`, `AssistantMessage`, `SystemMessage`, `ResultMessage`, `StreamEvent`, `RateLimitEvent`
- **Task messages**: `TaskStartedMessage`, `TaskProgressMessage`, `TaskNotificationMessage`
- **Permission**: `PermissionResultAllow`, `PermissionResultDeny`, `PermissionRuleValue`, `PermissionUpdate`
- **Hook inputs**: `PreToolUseHookInput`, `PostToolUseHookInput`, `PostToolUseFailureHookInput`, `UserPromptSubmitHookInput`, `StopHookInput`, `SubagentStopHookInput`, `PreCompactHookInput`, `NotificationHookInput`, `SubagentStartHookInput`, `PermissionRequestHookInput`
- **Hook outputs**: `SyncHookOutput`, `AsyncHookOutput`
- **System prompt**: `SystemPromptPreset`, `SystemPromptFile`
- **Sandbox**: `SandboxSettings`, `SandboxNetworkConfig`, `SandboxIgnoreViolations`
- **MCP status**: `McpToolInfo`, `McpServerInfo`, `McpServerStatus`, `McpStatusResponse`
- **Thinking config**: `ThinkingConfigAdaptive`, `ThinkingConfigEnabled`, `ThinkingConfigDisabled`
- **Task/Context**: `TaskBudget`, `TaskUsage`, `ContextUsageCategory`, `ContextUsageResponse`
- **Agent/Hook config**: `AgentDefinition` (13 fields), `HookMatcher`
- **Session**: `SDKSessionInfo`, `SessionMessage` (internal)

## Running tests

```r
devtools::test()
```

643+ tests. Integration tests require a real Claude Code CLI and skip automatically if not found.

### Test files

| File | Coverage | Needs CLI |
|------|----------|-----------|
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
```bash
source ~/.Renviron
git push https://kaipingyang:${GITHUB_TOKEN}@github.com/kaipingyang/ClaudeAgentSDK.git main
```

## Development scripts

```
scripts/
  pre-push          # Git pre-push hook — runs devtools::test() before allowing push
  initial-setup.sh  # Installs pre-push hook into .git/hooks/
```

Install: `bash scripts/initial-setup.sh`

## Python SDK parity assessment (as of v0.1.4, 2026-04-10)

| Module | Parity | Notes |
|--------|--------|-------|
| Options fields | 100% | 35/35 fields identical |
| Session management | 100% | 7 functions identical (list/get/messages + rename/tag/delete/fork) |
| Error types | 100% | 6 error types identical |
| Type definitions | 100% | 100+ S3 constructors covering all Python TypedDicts/dataclasses |
| Client methods | 100% | 16 methods including query(), send(), receive_response_async(), connect(), disconnect(), get_mcp_status(), etc. |
| Transport/Protocol | 90% | Functionally identical; R uses `coro` sync generators vs Python `async/await` — architectural difference, not a feature gap |
| Public API | 92% | Only missing: `create_sdk_mcp_server()` / `@tool` — R uses `mcptools` subprocess instead (same MCP protocol, different execution model) |
| Examples | 87% | Missing: Python async variant examples (trio/ipython), plugin example — N/A for R's single-threaded model |
| Tests | 651 | All pass; 4 env-dependent skips |

### Why Transport/Protocol is 90% (not 100%)

Python exports a `Transport` abstract base class so users can implement custom transports. R only has the internal `SubprocessCLITransport` and does not expose an abstract interface. There is only one transport implementation (subprocess), so an abstract base adds no value for R users.

### Why Public API is 92% (not 100%)

Python's `create_sdk_mcp_server()` runs an MCP server **in-process** (same Python event loop). R is single-threaded and synchronous — running an MCP server in the same process while also communicating with the CLI subprocess would require complex `later`/`callr` coordination. The `mcptools` package provides equivalent functionality via a subprocess MCP server, which uses the same protocol and covers 99% of use cases. The only loss is shared-memory access to the main R process.

### Why Examples is 87% (not 100%)

Python has `streaming_mode_trio.py`, `streaming_mode_ipython.py` (multiple async runtime examples) and `plugin_example.py`. R has only one concurrency model (`coro`), so async variant examples are N/A. Plugin support in R is not yet documented.

## Known remaining gaps

- `rewind_files()` / `stop_task()` — fire-and-forget control messages, no integration test
- SDK-managed MCP servers (Python's `create_sdk_mcp_server`) — R uses `mcptools` subprocess instead
- Large MCP output handling (`CLAUDE_MCP_OUTPUT_MAX_TOKENS`) — not implemented
- Plugin support — examples exist but no integration test

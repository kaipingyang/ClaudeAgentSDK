# Changelog

## 0.1.4 (2026-04-10)

### New Features

- **`on_tool_request` in `receive_response_async()`**: Async tool approval callback for Shiny interactive dialogs. When Claude requests permission to use a tool, the callback receives `(tool_name, tool_input, context, resolve)`. Call `resolve(PermissionResultAllow())` or `resolve(PermissionResultDeny())` asynchronously (e.g., from a Shiny button handler). The CLI blocks until resolved. The resolve function is one-shot (double-resolution warns and no-ops).
- **`transport$set_tool_request_callback()`**: Internal method to inject/clear the async tool approval handler on the transport layer.
- **Example 15**: `15_shinychat_tool_approval.R` — Full streaming chat with modal-based tool approval and interrupt button.
- **Example 13**: Added interrupt button to streaming chat.

### Tests

- 651 tests total (up from 643)
- Added unit tests: `on_tool_request` before connect, non-function rejection
- Added integration tests: async tool approval allow/deny/deferred resolve

## 0.1.3 (2026-04-10)

### New Features

- **`client$receive_response_async()`**: Promise-based async receive method for Shiny `ExtendedTask` integration. Returns a `promises::promise` that resolves to the `ResultMessage`, with an `on_message` callback for real-time streaming of intermediate messages. Uses non-blocking 10ms polling via `later::later()` + `transport$read_available_messages()`.
- **`transport$read_available_messages()`**: Non-blocking single-cycle read method on `SubprocessCLITransport`. Polls stdout with 0ms timeout, parses available data, handles control requests internally, returns list of SDK messages.

### Tests

- 643 tests total (up from 637)
- Added unit test: `receive_response_async()` before connect errors
- Added integration tests: async round-trip resolves `ResultMessage`, `on_message` receives `AssistantMessage`

## 0.1.2 (2026-04-09)

### New Features

- **`client$query()` method**: Added `query()` as alias for `send()` on `ClaudeSDKClient`, matching the Python SDK's `client.query()` API
- **MCP status types**: Added `McpToolInfo`, `McpServerInfo`, `McpServerStatus`, `McpStatusResponse` constructors
- **Thinking configuration types**: Added `ThinkingConfigAdaptive`, `ThinkingConfigEnabled`, `ThinkingConfigDisabled` constructors
- **Task budget/usage types**: Added `TaskBudget`, `TaskUsage` constructors
- **Context usage types**: Added `ContextUsageCategory`, `ContextUsageResponse` constructors
- **Pre-push hook**: Added `scripts/pre-push` and `scripts/initial-setup.sh` for running tests before push

### Tests

- 637 tests total (up from 608)

## 0.1.1 (2026-04-09)

### Bug Fixes

- **Rate limit event parsing**: Fixed parser to accept both snake_case (`resets_at`, `overage_status`) and camelCase (`resetsAt`, `overageStatus`) field names from CLI wire format
- **`toggle_mcp_server` param name**: Renamed `enable` to `enabled` to match Python SDK API

### New Features

- **Hook input type constructors**: Added `PreToolUseHookInput`, `PostToolUseHookInput`, `PostToolUseFailureHookInput`, `UserPromptSubmitHookInput`, `StopHookInput`, `SubagentStopHookInput`, `PreCompactHookInput`, `NotificationHookInput`, `SubagentStartHookInput`, `PermissionRequestHookInput`
- **Hook output type constructors**: Added `SyncHookOutput`, `AsyncHookOutput`
- **Permission update types**: Added `PermissionRuleValue`, `PermissionUpdate`
- **System prompt types**: Added `SystemPromptPreset`, `SystemPromptFile`
- **Sandbox types**: Added `SandboxNetworkConfig`, `SandboxIgnoreViolations`, `SandboxSettings`

### Tests

- Added `test-rate-limit-event.R`: rate limit event parsing edge cases (5 tests)
- Added `test-buffering.R`: line buffer / split_lines_with_buffer edge cases (9 tests)
- Expanded `test-types.R`: hook inputs, hook outputs, permission types, system prompt types, sandbox types (20+ new tests)

### Examples

- Added `00_quick_start.R`: simple getting-started example
- Added `12_filesystem_agents.R`: loading agents from `.claude/agents/` via `setting_sources`

## 0.1.0 (2026-04-08)

### Initial Release

- Full R implementation of the Claude Agent SDK mirroring Python SDK
- `ClaudeSDKClient` R6 class for interactive, stateful conversations
- `claude_run()` / `claude_query()` one-shot query functions
- `SubprocessCLITransport` with bidirectional control protocol
- `send_and_wait()` synchronous polling for status queries
- `get_server_info()`, `get_mcp_status()`, `get_context_usage()`
- `AgentDefinition` with all 13 fields (parity with Python SDK)
- Named dict serialization with camelCase conversion for agents
- Session management: `list_sessions()`, `get_session_info()`, `get_session_messages()`
- Session mutations: `rename_session()`, `tag_session()`, `delete_session()`, `fork_session()`
- Hook system with `HookMatcher` and bidirectional callback protocol
- `can_use_tool` permission callback with `PermissionResultAllow`/`PermissionResultDeny`
- Streaming via `include_partial_messages` and `StreamEvent` objects
- Structured output via `output_format` with JSON schema
- `stderr` callback for CLI debug output capture
- 509 unit + integration tests

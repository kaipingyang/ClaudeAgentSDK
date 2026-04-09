# Changelog

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
- 608 tests total (up from 509)

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

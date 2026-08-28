# Changelog

## ClaudeAgentSDK 0.2.4 (2026-08-26)

Performance-focused bug-fix release (no API changes).

#### Performance

- **Claude Code version checks no longer block `connect()`.** A
  successful initialize schedules a separate short-lived `claude -v`
  process; `later` polls it without blocking the R/Shiny event loop.
  Checks are deduplicated per normalized CLI executable and file
  signature, failures/timeouts never affect the usable connection, and
  only an unsupported version emits an asynchronous warning.
  `CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK` still disables the advisory
  check.

## ClaudeAgentSDK 0.2.3 (2026-08-05)

Bug-fix and additive release (no breaking changes).

#### Bug Fixes

- **Large messages no longer hang the CLI.** `transport$send()` (and the
  `initialize` handshake) wrote the whole message to the CLI’s stdin
  with a single non-blocking `processx::write_input()` and ignored its
  return value. Any message larger than the OS pipe buffer (~200 KB) was
  silently truncated, so the CLI never received the line’s terminating
  newline and the turn hung forever — this hit large text prompts and
  (especially) image attachments. Writes now loop until the entire
  payload is flushed, re-feeding the unwritten remainder and briefly
  yielding for stdin backpressure, matching the official Python SDK’s
  awaited full stdin write.

#### New Features

- **[`mcp_serve_stdio()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/mcp_serve_stdio.md)**
  — serve SDK-defined MCP tools over stdio, avoiding the in-process idle
  stall.

#### Internal

- Documentation regenerated with roxygen2 8.0.0; minor build hygiene
  (`.Rbuildignore`, `.gitignore`).

## ClaudeAgentSDK 0.2.2 (2026-07-24)

Additive feature release (no breaking changes).

#### New Features

- **In-process SDK MCP servers.** Define MCP tools that run *inside* the
  R session — no subprocess — and register them via
  `ClaudeAgentOptions(mcp_servers = list(<name> = create_sdk_mcp_server(...)))`.
  New exports
  [`sdk_mcp_tool()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/sdk_mcp_tool.md)
  and
  [`create_sdk_mcp_server()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/create_sdk_mcp_server.md)
  mirror the Python SDK’s `tool()` /
  [`create_sdk_mcp_server()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/create_sdk_mcp_server.md)
  (the tool constructor is named
  [`sdk_mcp_tool()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/sdk_mcp_tool.md)
  to avoid masking `ellmer::tool()`). The CLI routes each tool call back
  over the stream-json control protocol (`control_request` with
  `subtype = "mcp_message"` carrying JSON-RPC `initialize` /
  `tools/list` / `tools/call`), and the handler runs in-process with
  direct access to session state. **Depends only on `jsonlite` — no new
  dependencies** (notably no `ellmer` / `httr2` / `curl`), so it is safe
  in `curl`-pinned `renv` projects. This complements the existing
  external-server helper
  [`r_mcp_server()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/r_mcp_server.md).
  Verified end-to-end against the live Claude Code CLI.

## ClaudeAgentSDK 0.2.1 (2026-07-05)

Parity upgrade against the official Python `claude-agent-sdk` v0.2.110.
All changes are additive (no breaking changes).

#### New Features

- **Server-side tool blocks**: parse `server_tool_use` and
  `advisor_tool_result` content blocks into new
  [`ServerToolUseBlock()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ServerToolUseBlock.md)
  /
  [`ServerToolResultBlock()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ServerToolResultBlock.md)
  types (used by `web_search`, `web_fetch`, `advisor`, etc.). Added the
  `SERVER_TOOL_NAMES` constant.
- **`TaskUpdatedMessage`**: parse `system`/`task_updated` events,
  exposing `task_id`, `patch`, and `status` (from `patch$status`).
  Terminal task completion sometimes arrives only via `task_updated` (no
  `task_notification`). Added `TASK_UPDATED_STATUSES` /
  `TERMINAL_TASK_STATUSES` constants.
- **`HookEventMessage`**: parse `hook_started` / `hook_response` system
  messages (emitted when the new `include_hook_events` option is
  `TRUE`).
- **`DeferredToolUse`** type plus `ResultMessage$deferred_tool_use` and
  `ResultMessage$api_error_status` fields.
- **New `ClaudeAgentOptions`**: `strict_mcp_config`
  (`--strict-mcp-config`), `skills` (injects `Skill` / `Skill(name)`
  into allowed tools and defaults setting sources), and
  `include_hook_events` (`--include-hook-events`).
- **Thinking display**:
  [`ThinkingConfigAdaptive()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ThinkingConfigAdaptive.md)
  /
  [`ThinkingConfigEnabled()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ThinkingConfigEnabled.md)
  gain a `display` argument (`"summarized"` / `"omitted"`), emitted as
  `--thinking-display` (relevant for Opus 4.7+, which defaults to
  signature-only).
- **Sandbox network config**:
  [`SandboxNetworkConfig()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SandboxNetworkConfig.md)
  gains `allowed_domains`, `denied_domains`,
  `allow_managed_domains_only`, and `allow_mach_lookup`.
- **Permission UI context**:
  [`ToolPermissionContext()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ToolPermissionContext.md)
  and
  [`PermissionRequestMessage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PermissionRequestMessage.md)
  gain `blocked_path`, `decision_reason`, `title`, `display_name`, and
  `description` (populated from the incoming request).
- **[`PostToolUseHookSpecificOutput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PostToolUseHookSpecificOutput.md)**
  gains `updated_tool_output` (rewrite a regular tool’s output,
  alongside the existing `updated_mcp_tool_output`).
- Added `RATE_LIMIT_STATUSES` / `RATE_LIMIT_TYPES` constants.

## ClaudeAgentSDK 0.2.0 (2026-04-12)

#### Breaking Changes

- **Removed `on_tool_request` in `receive_response_async()`**: The
  callback-based async tool approval API introduced in 0.1.4 has been
  removed. Use the message-driven API instead: set
  `permission_prompt_tool_name = "stdio"` in `ClaudeAgentOptions`,
  handle `PermissionRequestMessage` in your message loop, and call
  `client$approve_tool()` / `client$deny_tool()` from your UI event
  handlers. This design gives reliable interrupt support when combined
  with [`coro::async`](https://coro.r-lib.org/reference/async.html) +
  `poll_messages()`.
- **Removed `transport$set_tool_request_callback()`**: Internal method
  removed along with the callback API.

#### New Features

- **[`coro::async`](https://coro.r-lib.org/reference/async.html) +
  `poll_messages()` Shiny integration pattern**: Recommended pattern for
  Shiny streaming + interrupt. Uses
  [`await()`](https://coro.r-lib.org/reference/async.html) to yield the
  R event loop between message batches, allowing `observeEvent` handlers
  (interrupt button, approval buttons) to fire between tokens.
  Documented in `CLAUDE.md` with a full code template.
- **Shiny examples 14–19**: Six complete Shiny examples covering simple
  non-streaming (14), streaming with interrupt (13), modal approval
  (15), inline approval bar (16), conversational approval (17), insertUI
  approval cards (18), and native tool cards + thinking + inline
  approval with blank-bubble fix (19).

#### Bug Fixes

- **Drain stale `ResultMessage` after interrupt**: After calling
  `client$interrupt()`, the loop now continues polling until
  `ResultMessage` arrives, ensuring no stale messages bleed into the
  next turn.
- **Suppress `system2` timeout warning in
  [`check_claude_version()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/check_claude_version.md)**:
  Eliminated spurious warning on systems where `claude --version` exits
  non-zero.

#### Examples

- `16_shinychat_tool_approval_inline.R`: Fixed approval bar below
  `chat_ui`
- `17_shinychat_tool_approval_conversational.R`: Type `allow`/`deny` in
  chat
- `18_shinychat_tool_approval_insertui.R`: `insertUI` approval cards in
  chat history
- `19_shinychat_tool_cards.R`: Native `<shiny-tool-request/result>` tool
  cards + `<details>` thinking blocks + inline approval. Fixes
  blank-bubble issue caused by `shiny-tool-request-hide` by replacing
  the `<shiny-tool-request>` element with a plain div before appending
  the approval card.

------------------------------------------------------------------------

## ClaudeAgentSDK 0.1.4 (2026-04-10)

#### New Features

- **`PermissionRequestMessage` + `approve_tool()` / `deny_tool()`**:
  Message-driven tool approval API. When no `can_use_tool` handler is
  configured and `permission_prompt_tool_name = "stdio"` is set,
  `can_use_tool` control requests are yielded as
  `PermissionRequestMessage` objects through the message stream. Call
  `client$approve_tool(request_id)` or `client$deny_tool(request_id)` to
  respond asynchronously (e.g., from a Shiny button handler).
- **Example 15**: `15_shinychat_tool_approval_msgdriven.R` — Streaming
  chat with message-driven modal approval and interrupt button.
- **Example 13**: Added interrupt button to streaming chat.

#### Tests

- 661 tests total (up from 643)
- Added unit tests: approve/deny_tool before connect,
  PermissionRequestMessage constructor
- Added integration tests: message-driven approve_tool/deny_tool
  allow/deny

## ClaudeAgentSDK 0.1.3 (2026-04-10)

#### New Features

- **`client$receive_response_async()`**: Promise-based async receive
  method for Shiny `ExtendedTask` integration. Returns a
  [`promises::promise`](https://rstudio.github.io/promises/reference/promise.html)
  that resolves to the `ResultMessage`, with an `on_message` callback
  for real-time streaming of intermediate messages. Uses non-blocking
  10ms polling via
  [`later::later()`](https://later.r-lib.org/reference/later.html) +
  `transport$read_available_messages()`.
- **`transport$read_available_messages()`**: Non-blocking single-cycle
  read method on `SubprocessCLITransport`. Polls stdout with 0ms
  timeout, parses available data, handles control requests internally,
  returns list of SDK messages.

#### Tests

- 643 tests total (up from 637)
- Added unit test: `receive_response_async()` before connect errors
- Added integration tests: async round-trip resolves `ResultMessage`,
  `on_message` receives `AssistantMessage`

## ClaudeAgentSDK 0.1.2 (2026-04-09)

#### New Features

- **`client$query()` method**: Added
  [`query()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/query.md)
  as alias for `send()` on `ClaudeSDKClient`, matching the Python SDK’s
  `client.query()` API
- **MCP status types**: Added `McpToolInfo`, `McpServerInfo`,
  `McpServerStatus`, `McpStatusResponse` constructors
- **Thinking configuration types**: Added `ThinkingConfigAdaptive`,
  `ThinkingConfigEnabled`, `ThinkingConfigDisabled` constructors
- **Task budget/usage types**: Added `TaskBudget`, `TaskUsage`
  constructors
- **Context usage types**: Added `ContextUsageCategory`,
  `ContextUsageResponse` constructors
- **Pre-push hook**: Added `scripts/pre-push` and
  `scripts/initial-setup.sh` for running tests before push

#### Tests

- 637 tests total (up from 608)

## ClaudeAgentSDK 0.1.1 (2026-04-09)

#### Bug Fixes

- **Rate limit event parsing**: Fixed parser to accept both snake_case
  (`resets_at`, `overage_status`) and camelCase (`resetsAt`,
  `overageStatus`) field names from CLI wire format
- **`toggle_mcp_server` param name**: Renamed `enable` to `enabled` to
  match Python SDK API

#### New Features

- **Hook input type constructors**: Added `PreToolUseHookInput`,
  `PostToolUseHookInput`, `PostToolUseFailureHookInput`,
  `UserPromptSubmitHookInput`, `StopHookInput`, `SubagentStopHookInput`,
  `PreCompactHookInput`, `NotificationHookInput`,
  `SubagentStartHookInput`, `PermissionRequestHookInput`
- **Hook output type constructors**: Added `SyncHookOutput`,
  `AsyncHookOutput`
- **Permission update types**: Added `PermissionRuleValue`,
  `PermissionUpdate`
- **System prompt types**: Added `SystemPromptPreset`,
  `SystemPromptFile`
- **Sandbox types**: Added `SandboxNetworkConfig`,
  `SandboxIgnoreViolations`, `SandboxSettings`

#### Tests

- Added `test-rate-limit-event.R`: rate limit event parsing edge cases
  (5 tests)
- Added `test-buffering.R`: line buffer / split_lines_with_buffer edge
  cases (9 tests)
- Expanded `test-types.R`: hook inputs, hook outputs, permission types,
  system prompt types, sandbox types (20+ new tests)

#### Examples

- Added `00_quick_start.R`: simple getting-started example
- Added `12_filesystem_agents.R`: loading agents from `.claude/agents/`
  via `setting_sources`

## ClaudeAgentSDK 0.1.0 (2026-04-08)

#### Initial Release

- Full R implementation of the Claude Agent SDK mirroring Python SDK
- `ClaudeSDKClient` R6 class for interactive, stateful conversations
- [`claude_run()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_run.md)
  /
  [`claude_query()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_query.md)
  one-shot query functions
- `SubprocessCLITransport` with bidirectional control protocol
- `send_and_wait()` synchronous polling for status queries
- `get_server_info()`, `get_mcp_status()`, `get_context_usage()`
- `AgentDefinition` with all 13 fields (parity with Python SDK)
- Named dict serialization with camelCase conversion for agents
- Session management:
  [`list_sessions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/list_sessions.md),
  [`get_session_info()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/get_session_info.md),
  [`get_session_messages()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/get_session_messages.md)
- Session mutations:
  [`rename_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/rename_session.md),
  [`tag_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/tag_session.md),
  [`delete_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/delete_session.md),
  [`fork_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/fork_session.md)
- Hook system with `HookMatcher` and bidirectional callback protocol
- `can_use_tool` permission callback with
  `PermissionResultAllow`/`PermissionResultDeny`
- Streaming via `include_partial_messages` and `StreamEvent` objects
- Structured output via `output_format` with JSON schema
- `stderr` callback for CLI debug output capture
- 509 unit + integration tests

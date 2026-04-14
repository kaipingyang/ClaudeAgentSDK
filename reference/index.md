# Package index

## Core Client

High-level stateful client for multi-turn conversations.

- [`ClaudeSDKClient`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ClaudeSDKClient.md)
  : ClaudeSDKClient R6 Class
- [`ClaudeAgentOptions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ClaudeAgentOptions.md)
  : Create ClaudeAgentOptions

## One-Shot Query

Simple functions for single-turn queries without managing a client.

- [`claude_query()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_query.md)
  : Query Claude Code (streaming generator)
- [`claude_run()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_run.md)
  : Run Claude Code synchronously and collect all messages

## Session Management

Read and browse saved Claude Code sessions from disk.

- [`list_sessions()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/list_sessions.md)
  : List Claude Code sessions
- [`get_session_info()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/get_session_info.md)
  : Get metadata for a single session
- [`get_session_messages()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/get_session_messages.md)
  : Get conversation messages from a session

## Session Mutations

Rename, tag, delete, or fork existing sessions.

- [`rename_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/rename_session.md)
  : Rename a session
- [`tag_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/tag_session.md)
  : Tag a session
- [`delete_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/delete_session.md)
  : Delete a session
- [`fork_session()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/fork_session.md)
  : Fork a session

## Permission Types

Return values for `can_use_tool` callbacks and message-driven approval.

- [`PermissionResultAllow()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PermissionResultAllow.md)
  : Allow permission result
- [`PermissionResultDeny()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PermissionResultDeny.md)
  : Deny permission result
- [`PermissionRequestMessage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PermissionRequestMessage.md)
  : Create a PermissionRequestMessage
- [`PermissionRuleValue()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PermissionRuleValue.md)
  : Create a PermissionRuleValue
- [`PermissionUpdate()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PermissionUpdate.md)
  : Create a PermissionUpdate

## Message Types

S3 classes representing messages yielded by
[`claude_query()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_query.md)
and the client.

- [`UserMessage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/UserMessage.md)
  : Create a UserMessage
- [`AssistantMessage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/AssistantMessage.md)
  : Create an AssistantMessage
- [`SystemMessage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SystemMessage.md)
  : Create a SystemMessage
- [`ResultMessage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ResultMessage.md)
  : Create a ResultMessage
- [`StreamEvent()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/StreamEvent.md)
  : Create a StreamEvent
- [`RateLimitEvent()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/RateLimitEvent.md)
  : Create a RateLimitEvent
- [`RateLimitInfo()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/RateLimitInfo.md)
  : Create a RateLimitInfo
- [`TaskStartedMessage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/TaskStartedMessage.md)
  : Create a TaskStartedMessage
- [`TaskProgressMessage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/TaskProgressMessage.md)
  : Create a TaskProgressMessage
- [`TaskNotificationMessage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/TaskNotificationMessage.md)
  : Create a TaskNotificationMessage

## Content Block Types

Blocks that appear inside `AssistantMessage$content`.

- [`TextBlock()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/TextBlock.md)
  : Create a TextBlock
- [`ThinkingBlock()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ThinkingBlock.md)
  : Create a ThinkingBlock
- [`ToolUseBlock()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ToolUseBlock.md)
  : Create a ToolUseBlock
- [`ToolResultBlock()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ToolResultBlock.md)
  : Create a ToolResultBlock

## Hook Types

Input and output types for the hook system.

- [`PreToolUseHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PreToolUseHookInput.md)
  : Create a PreToolUseHookInput
- [`PostToolUseHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PostToolUseHookInput.md)
  : Create a PostToolUseHookInput
- [`PostToolUseFailureHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PostToolUseFailureHookInput.md)
  : Create a PostToolUseFailureHookInput
- [`UserPromptSubmitHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/UserPromptSubmitHookInput.md)
  : Create a UserPromptSubmitHookInput
- [`StopHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/StopHookInput.md)
  : Create a StopHookInput
- [`SubagentStopHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SubagentStopHookInput.md)
  : Create a SubagentStopHookInput
- [`SubagentStartHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SubagentStartHookInput.md)
  : Create a SubagentStartHookInput
- [`PreCompactHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PreCompactHookInput.md)
  : Create a PreCompactHookInput
- [`NotificationHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/NotificationHookInput.md)
  : Create a NotificationHookInput
- [`PermissionRequestHookInput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/PermissionRequestHookInput.md)
  : Create a PermissionRequestHookInput
- [`SyncHookOutput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SyncHookOutput.md)
  : Create a SyncHookOutput
- [`AsyncHookOutput()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/AsyncHookOutput.md)
  : Create an AsyncHookOutput
- [`HookMatcher()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/HookMatcher.md)
  : Create a HookMatcher

## Agent & MCP Types

Configuration and status types for agents and MCP servers.

- [`AgentDefinition()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/AgentDefinition.md)
  : Create an AgentDefinition
- [`McpToolInfo()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/McpToolInfo.md)
  : Create a McpToolInfo
- [`McpServerInfo()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/McpServerInfo.md)
  : Create a McpServerInfo
- [`McpServerStatus()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/McpServerStatus.md)
  : Create a McpServerStatus
- [`McpStatusResponse()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/McpStatusResponse.md)
  : Create a McpStatusResponse

## Thinking & Effort Types

Configuration for extended thinking / effort level.

- [`ThinkingConfigAdaptive()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ThinkingConfigAdaptive.md)
  : Create a ThinkingConfigAdaptive
- [`ThinkingConfigEnabled()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ThinkingConfigEnabled.md)
  : Create a ThinkingConfigEnabled
- [`ThinkingConfigDisabled()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ThinkingConfigDisabled.md)
  : Create a ThinkingConfigDisabled

## System Prompt & Sandbox Types

Typed helpers for system prompt and sandbox configuration.

- [`SystemPromptPreset()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SystemPromptPreset.md)
  : Create a SystemPromptPreset
- [`SystemPromptFile()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SystemPromptFile.md)
  : Create a SystemPromptFile
- [`SandboxSettings()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SandboxSettings.md)
  : Create SandboxSettings
- [`SandboxNetworkConfig()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SandboxNetworkConfig.md)
  : Create a SandboxNetworkConfig
- [`SandboxIgnoreViolations()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/SandboxIgnoreViolations.md)
  : Create a SandboxIgnoreViolations

## Task & Context Budget Types

Budget and usage tracking for API tasks.

- [`TaskBudget()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/TaskBudget.md)
  : Create a TaskBudget
- [`TaskUsage()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/TaskUsage.md)
  : Create a TaskUsage
- [`ContextUsageCategory()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ContextUsageCategory.md)
  : Create a ContextUsageCategory
- [`ContextUsageResponse()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/ContextUsageResponse.md)
  : Create a ContextUsageResponse

## Utilities

Helper functions for CLI discovery and MCP server setup.

- [`find_claude()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/find_claude.md)
  : Find the Claude Code CLI binary

- [`check_claude_version()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/check_claude_version.md)
  : Check Claude Code CLI version

- [`list_skills()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/list_skills.md)
  : List available Claude Code skills

- [`r_mcp_server()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/r_mcp_server.md)
  :

  Create an R-based MCP server entry for `mcp_servers`

- [`split_lines_with_buffer()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/split_lines_with_buffer.md)
  : Split buffered output into complete lines

## Error Constructors

Typed error objects raised by the SDK.

- [`claude_cli_not_found()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_cli_not_found.md)
  : Raise CLINotFoundError
- [`claude_cli_connection_error()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_cli_connection_error.md)
  : Raise CLIConnectionError
- [`claude_process_error()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_process_error.md)
  : Raise ProcessError
- [`claude_json_decode_error()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_json_decode_error.md)
  : Raise CLIJSONDecodeError
- [`claude_message_parse_error()`](https://kaipingyang.github.io/ClaudeAgentSDK/reference/claude_message_parse_error.md)
  : Raise MessageParseError

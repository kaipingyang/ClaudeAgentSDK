#' @title Message Type Constructors
#' @description Lightweight S3 constructors mirroring every dataclass defined
#'   in the Python SDK's `types.py`.  All objects are named lists with a
#'   `class` attribute.  Fields match Python field names exactly (snake_case).
#' @name types
#' @keywords internal
NULL

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

.new_obj <- function(fields, class) {
  structure(fields, class = c(class, "list"))
}

# ---------------------------------------------------------------------------
# Content block types
# ---------------------------------------------------------------------------

#' Create a TextBlock
#' @param text Character. The text content.
#' @return Object of class `TextBlock`.
#' @export
TextBlock <- function(text) {
  .new_obj(list(text = text), "TextBlock")
}

#' Create a ThinkingBlock
#' @param thinking Character. The thinking content.
#' @param signature Character. Signature for extended thinking.
#' @return Object of class `ThinkingBlock`.
#' @export
ThinkingBlock <- function(thinking, signature) {
  .new_obj(list(thinking = thinking, signature = signature), "ThinkingBlock")
}

#' Create a ToolUseBlock
#' @param id Character. Tool use ID.
#' @param name Character. Tool name.
#' @param input List. Tool input parameters.
#' @return Object of class `ToolUseBlock`.
#' @export
ToolUseBlock <- function(id, name, input) {
  .new_obj(list(id = id, name = name, input = input), "ToolUseBlock")
}

#' Create a ToolResultBlock
#' @param tool_use_id Character. ID of the corresponding tool use.
#' @param content Character, list, or NULL. Tool result content.
#' @param is_error Logical or NULL. Whether this is an error result.
#' @return Object of class `ToolResultBlock`.
#' @export
ToolResultBlock <- function(tool_use_id, content = NULL, is_error = NULL) {
  .new_obj(
    list(tool_use_id = tool_use_id, content = content, is_error = is_error),
    "ToolResultBlock"
  )
}

# ---------------------------------------------------------------------------
# Message types
# ---------------------------------------------------------------------------

#' Create a UserMessage
#' @param content Character or list of content blocks.
#' @param uuid Character or NULL. Unique message ID.
#' @param parent_tool_use_id Character or NULL.
#' @param tool_use_result List or NULL.
#' @return Object of class `UserMessage`.
#' @export
UserMessage <- function(content,
                        uuid               = NULL,
                        parent_tool_use_id = NULL,
                        tool_use_result    = NULL) {
  .new_obj(
    list(
      content            = content,
      uuid               = uuid,
      parent_tool_use_id = parent_tool_use_id,
      tool_use_result    = tool_use_result
    ),
    "UserMessage"
  )
}

#' Create an AssistantMessage
#' @param content List of content blocks.
#' @param model Character. Model ID.
#' @param parent_tool_use_id Character or NULL.
#' @param error Character or NULL. Error type if present.
#' @param usage List or NULL. Token usage dict.
#' @param message_id Character or NULL.
#' @param stop_reason Character or NULL.
#' @param session_id Character or NULL.
#' @param uuid Character or NULL.
#' @return Object of class `AssistantMessage`.
#' @export
AssistantMessage <- function(content,
                             model,
                             parent_tool_use_id = NULL,
                             error              = NULL,
                             usage              = NULL,
                             message_id         = NULL,
                             stop_reason        = NULL,
                             session_id         = NULL,
                             uuid               = NULL) {
  .new_obj(
    list(
      content            = content,
      model              = model,
      parent_tool_use_id = parent_tool_use_id,
      error              = error,
      usage              = usage,
      message_id         = message_id,
      stop_reason        = stop_reason,
      session_id         = session_id,
      uuid               = uuid
    ),
    "AssistantMessage"
  )
}

#' Create a SystemMessage
#' @param subtype Character. Subtype string.
#' @param data List. Raw data dict.
#' @return Object of class `SystemMessage`.
#' @export
SystemMessage <- function(subtype, data) {
  .new_obj(list(subtype = subtype, data = data), "SystemMessage")
}

#' Create a TaskStartedMessage
#' @param subtype Character.
#' @param data List. Raw data.
#' @param task_id Character.
#' @param description Character.
#' @param uuid Character.
#' @param session_id Character.
#' @param tool_use_id Character or NULL.
#' @param task_type Character or NULL.
#' @return Object of class `c("TaskStartedMessage","SystemMessage")`.
#' @export
TaskStartedMessage <- function(subtype, data, task_id, description,
                               uuid, session_id,
                               tool_use_id = NULL, task_type = NULL) {
  .new_obj(
    list(
      subtype     = subtype,
      data        = data,
      task_id     = task_id,
      description = description,
      uuid        = uuid,
      session_id  = session_id,
      tool_use_id = tool_use_id,
      task_type   = task_type
    ),
    c("TaskStartedMessage", "SystemMessage")
  )
}

#' Create a TaskProgressMessage
#' @param subtype Character.
#' @param data List.
#' @param task_id Character.
#' @param description Character.
#' @param usage List. Usage stats.
#' @param uuid Character.
#' @param session_id Character.
#' @param tool_use_id Character or NULL.
#' @param last_tool_name Character or NULL.
#' @return Object of class `c("TaskProgressMessage","SystemMessage")`.
#' @export
TaskProgressMessage <- function(subtype, data, task_id, description,
                                usage, uuid, session_id,
                                tool_use_id    = NULL,
                                last_tool_name = NULL) {
  .new_obj(
    list(
      subtype        = subtype,
      data           = data,
      task_id        = task_id,
      description    = description,
      usage          = usage,
      uuid           = uuid,
      session_id     = session_id,
      tool_use_id    = tool_use_id,
      last_tool_name = last_tool_name
    ),
    c("TaskProgressMessage", "SystemMessage")
  )
}

#' Create a TaskNotificationMessage
#' @param subtype Character.
#' @param data List.
#' @param task_id Character.
#' @param status Character. `"completed"`, `"failed"`, or `"stopped"`.
#' @param output_file Character.
#' @param summary Character.
#' @param uuid Character.
#' @param session_id Character.
#' @param tool_use_id Character or NULL.
#' @param usage List or NULL.
#' @return Object of class `c("TaskNotificationMessage","SystemMessage")`.
#' @export
TaskNotificationMessage <- function(subtype, data, task_id, status,
                                    output_file, summary, uuid, session_id,
                                    tool_use_id = NULL, usage = NULL) {
  .new_obj(
    list(
      subtype     = subtype,
      data        = data,
      task_id     = task_id,
      status      = status,
      output_file = output_file,
      summary     = summary,
      uuid        = uuid,
      session_id  = session_id,
      tool_use_id = tool_use_id,
      usage       = usage
    ),
    c("TaskNotificationMessage", "SystemMessage")
  )
}

#' Create a ResultMessage
#' @param subtype Character.
#' @param duration_ms Integer.
#' @param duration_api_ms Integer.
#' @param is_error Logical.
#' @param num_turns Integer.
#' @param session_id Character.
#' @param stop_reason Character or NULL.
#' @param total_cost_usd Numeric or NULL.
#' @param usage List or NULL.
#' @param result Character or NULL.
#' @param structured_output Any or NULL.
#' @param model_usage List or NULL.
#' @param permission_denials List or NULL.
#' @param errors List or NULL.
#' @param uuid Character or NULL.
#' @return Object of class `ResultMessage`.
#' @export
ResultMessage <- function(subtype, duration_ms, duration_api_ms,
                          is_error, num_turns, session_id,
                          stop_reason         = NULL,
                          total_cost_usd      = NULL,
                          usage               = NULL,
                          result              = NULL,
                          structured_output   = NULL,
                          model_usage         = NULL,
                          permission_denials  = NULL,
                          errors              = NULL,
                          uuid                = NULL) {
  .new_obj(
    list(
      subtype            = subtype,
      duration_ms        = duration_ms,
      duration_api_ms    = duration_api_ms,
      is_error           = is_error,
      num_turns          = num_turns,
      session_id         = session_id,
      stop_reason        = stop_reason,
      total_cost_usd     = total_cost_usd,
      usage              = usage,
      result             = result,
      structured_output  = structured_output,
      model_usage        = model_usage,
      permission_denials = permission_denials,
      errors             = errors,
      uuid               = uuid
    ),
    "ResultMessage"
  )
}

#' Create a StreamEvent
#' @param uuid Character.
#' @param session_id Character.
#' @param event List. Raw Anthropic API stream event.
#' @param parent_tool_use_id Character or NULL.
#' @return Object of class `StreamEvent`.
#' @export
StreamEvent <- function(uuid, session_id, event, parent_tool_use_id = NULL) {
  .new_obj(
    list(
      uuid               = uuid,
      session_id         = session_id,
      event              = event,
      parent_tool_use_id = parent_tool_use_id
    ),
    "StreamEvent"
  )
}

#' Create a RateLimitInfo
#' @param status Character. `"allowed"`, `"allowed_warning"`, or `"rejected"`.
#' @param resets_at Integer or NULL. Unix timestamp (ms) when limit resets.
#' @param rate_limit_type Character or NULL.
#' @param utilization Numeric or NULL. Fraction consumed (0-1).
#' @param overage_status Character or NULL.
#' @param overage_resets_at Integer or NULL.
#' @param overage_disabled_reason Character or NULL.
#' @param raw List. Full raw dict from CLI.
#' @return Object of class `RateLimitInfo`.
#' @export
RateLimitInfo <- function(status,
                          resets_at               = NULL,
                          rate_limit_type         = NULL,
                          utilization             = NULL,
                          overage_status          = NULL,
                          overage_resets_at       = NULL,
                          overage_disabled_reason = NULL,
                          raw                     = list()) {
  .new_obj(
    list(
      status                  = status,
      resets_at               = resets_at,
      rate_limit_type         = rate_limit_type,
      utilization             = utilization,
      overage_status          = overage_status,
      overage_resets_at       = overage_resets_at,
      overage_disabled_reason = overage_disabled_reason,
      raw                     = raw
    ),
    "RateLimitInfo"
  )
}

#' Create a RateLimitEvent
#' @param rate_limit_info A `RateLimitInfo` object.
#' @param uuid Character.
#' @param session_id Character.
#' @return Object of class `RateLimitEvent`.
#' @export
RateLimitEvent <- function(rate_limit_info, uuid, session_id) {
  .new_obj(
    list(
      rate_limit_info = rate_limit_info,
      uuid            = uuid,
      session_id      = session_id
    ),
    "RateLimitEvent"
  )
}

# ---------------------------------------------------------------------------
# Permission result types
# ---------------------------------------------------------------------------

#' Allow permission result
#' @param updated_input List or NULL. Modified tool input.
#' @param updated_permissions List or NULL. Permission updates.
#' @return Object of class `PermissionResultAllow`.
#' @export
PermissionResultAllow <- function(updated_input = NULL,
                                  updated_permissions = NULL) {
  .new_obj(
    list(
      behavior            = "allow",
      updated_input       = updated_input,
      updated_permissions = updated_permissions
    ),
    "PermissionResultAllow"
  )
}

#' Deny permission result
#' @param message Character. Reason for denial.
#' @param interrupt Logical. Whether to interrupt the current operation.
#' @return Object of class `PermissionResultDeny`.
#' @export
PermissionResultDeny <- function(message = "", interrupt = FALSE) {
  .new_obj(
    list(behavior = "deny", message = message, interrupt = interrupt),
    "PermissionResultDeny"
  )
}

#' Create a PermissionRequestMessage
#'
#' Yielded by the message stream when a `can_use_tool` control request
#' arrives and no handler (`can_use_tool` / `on_tool_request`) is configured.
#' The caller must eventually call [ClaudeSDKClient]`$approve_tool()` or
#' `$deny_tool()` with the `request_id` to unblock the CLI.
#'
#' @param request_id Character. Unique ID for this control request.
#' @param tool_name Character. Name of the tool Claude wants to use.
#' @param tool_input List. Input arguments for the tool.
#' @param tool_use_id Character or NULL.
#' @param agent_id Character or NULL.
#' @param suggestions List or NULL. Permission suggestions from the CLI.
#' @return Object of class `PermissionRequestMessage`.
#' @export
PermissionRequestMessage <- function(request_id,
                                     tool_name,
                                     tool_input,
                                     tool_use_id = NULL,
                                     agent_id    = NULL,
                                     suggestions = NULL) {
  .new_obj(
    list(
      request_id  = request_id,
      tool_name   = tool_name,
      tool_input  = tool_input,
      tool_use_id = tool_use_id,
      agent_id    = agent_id,
      suggestions = suggestions
    ),
    "PermissionRequestMessage"
  )
}

# ---------------------------------------------------------------------------
# Session types  (mirrors SDKSessionInfo + SessionMessage)
# ---------------------------------------------------------------------------

#' @keywords internal
sdk_session_info <- function(session_id, summary, last_modified,
                              file_size = NULL, custom_title = NULL,
                              first_prompt = NULL, git_branch = NULL,
                              cwd = NULL, tag = NULL, created_at = NULL) {
  .new_obj(
    list(
      session_id    = session_id,
      summary       = summary,
      last_modified = last_modified,
      file_size     = file_size,
      custom_title  = custom_title,
      first_prompt  = first_prompt,
      git_branch    = git_branch,
      cwd           = cwd,
      tag           = tag,
      created_at    = created_at
    ),
    "SDKSessionInfo"
  )
}

#' @keywords internal
session_message_obj <- function(type, uuid, session_id, message,
                                parent_tool_use_id = NULL) {
  .new_obj(
    list(
      type               = type,
      uuid               = uuid,
      session_id         = session_id,
      message            = message,
      parent_tool_use_id = parent_tool_use_id
    ),
    "SessionMessage"
  )
}

# ---------------------------------------------------------------------------
# Agent and Hook configuration types  (mirrors Python AgentDefinition / HookMatcher)
# ---------------------------------------------------------------------------

#' Create an AgentDefinition
#'
#' Defines a custom sub-agent that Claude Code can delegate tasks to.
#' Mirrors Python's `AgentDefinition` dataclass in `types.py`.
#'
#' @param description Character. Short description of what this agent does.
#' @param prompt Character or NULL. System prompt for the agent.
#' @param tools Character vector or NULL. Tools the agent can use.
#' @param disallowed_tools Character vector or NULL. Tools the agent cannot use.
#' @param model Character or NULL. Model ID for the agent.
#' @param skills Character vector or NULL. Additional skills for the agent.
#' @param memory Character or NULL. Memory scope: `"user"`, `"project"`, or
#'   `"local"`.
#' @param mcp_servers List or NULL. MCP server configurations.
#' @param initial_prompt Character or NULL. Initial prompt for the agent.
#' @param max_turns Integer or NULL. Maximum turns for the agent.
#' @param background Logical or NULL. Whether agent runs in background.
#' @param effort Character or integer or NULL. Effort level: `"low"`,
#'   `"medium"`, `"high"`, `"max"`, or an integer.
#' @param permission_mode Character or NULL. Permission mode for the agent.
#' @return Object of class `AgentDefinition`.
#' @export
AgentDefinition <- function(description,
                             prompt           = NULL,
                             tools            = NULL,
                             disallowed_tools = NULL,
                             model            = NULL,
                             skills           = NULL,
                             memory           = NULL,
                             mcp_servers      = NULL,
                             initial_prompt   = NULL,
                             max_turns        = NULL,
                             background       = NULL,
                             effort           = NULL,
                             permission_mode  = NULL) {
  .new_obj(
    list(
      description      = description,
      prompt           = prompt,
      tools            = tools,
      disallowed_tools = disallowed_tools,
      model            = model,
      skills           = skills,
      memory           = memory,
      mcp_servers      = mcp_servers,
      initial_prompt   = initial_prompt,
      max_turns        = max_turns,
      background       = background,
      effort           = effort,
      permission_mode  = permission_mode
    ),
    "AgentDefinition"
  )
}

#' Create a HookMatcher
#'
#' Pairs a tool/event matcher with a list of hook callback functions.
#' Mirrors Python's `HookMatcher` dataclass in `types.py`.
#'
#' @param matcher Character or NULL. Tool name or pattern to match
#'   (e.g., `"Bash"`, `"Write"`). Pass `NULL` to match all events.
#' @param hooks List of functions. Each function has signature
#'   `function(input_data, tool_use_id, context)` and returns a named list.
#' @param timeout Integer or NULL. Timeout in milliseconds for each hook call.
#' @return Object of class `HookMatcher`.
#' @export
HookMatcher <- function(matcher, hooks, timeout = NULL) {
  .new_obj(
    list(matcher = matcher, hooks = hooks, timeout = timeout),
    "HookMatcher"
  )
}

# ---------------------------------------------------------------------------
# MCP status types (returned by get_mcp_status)
# ---------------------------------------------------------------------------

#' Create a McpToolInfo
#' @param name Character.
#' @param description Character or NULL.
#' @param annotations List or NULL.
#' @return Object of class `McpToolInfo`.
#' @export
McpToolInfo <- function(name, description = NULL, annotations = NULL) {
  .new_obj(list(name = name, description = description,
                annotations = annotations), "McpToolInfo")
}

#' Create a McpServerInfo
#' @param name Character.
#' @param version Character.
#' @return Object of class `McpServerInfo`.
#' @export
McpServerInfo <- function(name, version) {
  .new_obj(list(name = name, version = version), "McpServerInfo")
}

#' Create a McpServerStatus
#' @param name Character. Server name.
#' @param status Character. One of `"connected"`, `"failed"`, `"needs-auth"`,
#'   `"pending"`, `"disabled"`.
#' @param server_info `McpServerInfo` or NULL.
#' @param error Character or NULL.
#' @param config List or NULL.
#' @param scope Character or NULL.
#' @param tools List of `McpToolInfo` or NULL.
#' @return Object of class `McpServerStatus`.
#' @export
McpServerStatus <- function(name, status, server_info = NULL, error = NULL,
                             config = NULL, scope = NULL, tools = NULL) {
  .new_obj(list(
    name       = name,
    status     = status,
    serverInfo = server_info,
    error      = error,
    config     = config,
    scope      = scope,
    tools      = tools
  ), "McpServerStatus")
}

#' Create a McpStatusResponse
#' @param mcp_servers List of `McpServerStatus`.
#' @return Object of class `McpStatusResponse`.
#' @export
McpStatusResponse <- function(mcp_servers) {
  .new_obj(list(mcpServers = mcp_servers), "McpStatusResponse")
}

# ---------------------------------------------------------------------------
# Thinking configuration types
# ---------------------------------------------------------------------------

#' Create a ThinkingConfigAdaptive
#' @return Object of class `ThinkingConfigAdaptive`.
#' @export
ThinkingConfigAdaptive <- function() {
  .new_obj(list(type = "adaptive"), "ThinkingConfigAdaptive")
}

#' Create a ThinkingConfigEnabled
#' @param budget_tokens Integer. Token budget for thinking.
#' @return Object of class `ThinkingConfigEnabled`.
#' @export
ThinkingConfigEnabled <- function(budget_tokens) {
  .new_obj(list(type = "enabled", budget_tokens = budget_tokens),
           "ThinkingConfigEnabled")
}

#' Create a ThinkingConfigDisabled
#' @return Object of class `ThinkingConfigDisabled`.
#' @export
ThinkingConfigDisabled <- function() {
  .new_obj(list(type = "disabled"), "ThinkingConfigDisabled")
}

# ---------------------------------------------------------------------------
# Task budget / usage types
# ---------------------------------------------------------------------------

#' Create a TaskBudget
#'
#' API-side task budget in tokens. When set, the model is made aware of its
#' remaining token budget so it can pace tool use and wrap up before the limit.
#'
#' @param max_tokens Integer. Maximum token budget for the task.
#' @return Object of class `TaskBudget`.
#' @export
TaskBudget <- function(max_tokens) {
  .new_obj(list(max_tokens = max_tokens), "TaskBudget")
}

#' Create a TaskUsage
#' @param total_tokens Integer.
#' @param tool_uses Integer.
#' @return Object of class `TaskUsage`.
#' @export
TaskUsage <- function(total_tokens, tool_uses) {
  .new_obj(list(total_tokens = total_tokens, tool_uses = tool_uses),
           "TaskUsage")
}

# ---------------------------------------------------------------------------
# Context usage types
# ---------------------------------------------------------------------------

#' Create a ContextUsageCategory
#' @param name Character.
#' @param tokens Integer.
#' @param color Character.
#' @param is_deferred Logical or NULL.
#' @return Object of class `ContextUsageCategory`.
#' @export
ContextUsageCategory <- function(name, tokens, color, is_deferred = NULL) {
  .new_obj(list(
    name       = name,
    tokens     = tokens,
    color      = color,
    isDeferred = is_deferred
  ), "ContextUsageCategory")
}

#' Create a ContextUsageResponse
#' @param categories List of `ContextUsageCategory`.
#' @param total_tokens Integer.
#' @return Object of class `ContextUsageResponse`.
#' @export
ContextUsageResponse <- function(categories, total_tokens) {
  .new_obj(list(
    categories  = categories,
    totalTokens = total_tokens
  ), "ContextUsageResponse")
}

# ---------------------------------------------------------------------------
# Hook input types (mirrors Python TypedDicts in types.py)
# ---------------------------------------------------------------------------

#' Create a PreToolUseHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param tool_name Character.
#' @param tool_input List.
#' @param tool_use_id Character.
#' @param permission_mode Character or NULL.
#' @param agent_id Character or NULL.
#' @param agent_type Character or NULL.
#' @return Object of class `PreToolUseHookInput`.
#' @export
PreToolUseHookInput <- function(session_id, transcript_path, cwd,
                                tool_name, tool_input, tool_use_id,
                                permission_mode = NULL,
                                agent_id = NULL, agent_type = NULL) {
  .new_obj(list(
    hook_event_name = "PreToolUse",
    session_id      = session_id,
    transcript_path = transcript_path,
    cwd             = cwd,
    tool_name       = tool_name,
    tool_input      = tool_input,
    tool_use_id     = tool_use_id,
    permission_mode = permission_mode,
    agent_id        = agent_id,
    agent_type      = agent_type
  ), "PreToolUseHookInput")
}

#' Create a PostToolUseHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param tool_name Character.
#' @param tool_input List.
#' @param tool_response Any.
#' @param tool_use_id Character.
#' @param permission_mode Character or NULL.
#' @param agent_id Character or NULL.
#' @param agent_type Character or NULL.
#' @return Object of class `PostToolUseHookInput`.
#' @export
PostToolUseHookInput <- function(session_id, transcript_path, cwd,
                                 tool_name, tool_input, tool_response,
                                 tool_use_id,
                                 permission_mode = NULL,
                                 agent_id = NULL, agent_type = NULL) {
  .new_obj(list(
    hook_event_name = "PostToolUse",
    session_id      = session_id,
    transcript_path = transcript_path,
    cwd             = cwd,
    tool_name       = tool_name,
    tool_input      = tool_input,
    tool_response   = tool_response,
    tool_use_id     = tool_use_id,
    permission_mode = permission_mode,
    agent_id        = agent_id,
    agent_type      = agent_type
  ), "PostToolUseHookInput")
}

#' Create a PostToolUseFailureHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param tool_name Character.
#' @param tool_input List.
#' @param tool_use_id Character.
#' @param error Character.
#' @param is_interrupt Logical or NULL.
#' @param permission_mode Character or NULL.
#' @param agent_id Character or NULL.
#' @param agent_type Character or NULL.
#' @return Object of class `PostToolUseFailureHookInput`.
#' @export
PostToolUseFailureHookInput <- function(session_id, transcript_path, cwd,
                                        tool_name, tool_input, tool_use_id,
                                        error,
                                        is_interrupt = NULL,
                                        permission_mode = NULL,
                                        agent_id = NULL, agent_type = NULL) {
  .new_obj(list(
    hook_event_name = "PostToolUseFailure",
    session_id      = session_id,
    transcript_path = transcript_path,
    cwd             = cwd,
    tool_name       = tool_name,
    tool_input      = tool_input,
    tool_use_id     = tool_use_id,
    error           = error,
    is_interrupt    = is_interrupt,
    permission_mode = permission_mode,
    agent_id        = agent_id,
    agent_type      = agent_type
  ), "PostToolUseFailureHookInput")
}

#' Create a UserPromptSubmitHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param prompt Character.
#' @param permission_mode Character or NULL.
#' @return Object of class `UserPromptSubmitHookInput`.
#' @export
UserPromptSubmitHookInput <- function(session_id, transcript_path, cwd,
                                      prompt,
                                      permission_mode = NULL) {
  .new_obj(list(
    hook_event_name = "UserPromptSubmit",
    session_id      = session_id,
    transcript_path = transcript_path,
    cwd             = cwd,
    prompt          = prompt,
    permission_mode = permission_mode
  ), "UserPromptSubmitHookInput")
}

#' Create a StopHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param stop_hook_active Logical.
#' @param permission_mode Character or NULL.
#' @return Object of class `StopHookInput`.
#' @export
StopHookInput <- function(session_id, transcript_path, cwd,
                           stop_hook_active,
                           permission_mode = NULL) {
  .new_obj(list(
    hook_event_name  = "Stop",
    session_id       = session_id,
    transcript_path  = transcript_path,
    cwd              = cwd,
    stop_hook_active = stop_hook_active,
    permission_mode  = permission_mode
  ), "StopHookInput")
}

#' Create a SubagentStopHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param stop_hook_active Logical.
#' @param agent_id Character.
#' @param agent_transcript_path Character.
#' @param agent_type Character.
#' @param permission_mode Character or NULL.
#' @return Object of class `SubagentStopHookInput`.
#' @export
SubagentStopHookInput <- function(session_id, transcript_path, cwd,
                                   stop_hook_active,
                                   agent_id, agent_transcript_path,
                                   agent_type,
                                   permission_mode = NULL) {
  .new_obj(list(
    hook_event_name      = "SubagentStop",
    session_id           = session_id,
    transcript_path      = transcript_path,
    cwd                  = cwd,
    stop_hook_active     = stop_hook_active,
    agent_id             = agent_id,
    agent_transcript_path = agent_transcript_path,
    agent_type           = agent_type,
    permission_mode      = permission_mode
  ), "SubagentStopHookInput")
}

#' Create a PreCompactHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param trigger Character. `"manual"` or `"auto"`.
#' @param custom_instructions Character or NULL.
#' @param permission_mode Character or NULL.
#' @return Object of class `PreCompactHookInput`.
#' @export
PreCompactHookInput <- function(session_id, transcript_path, cwd,
                                 trigger, custom_instructions = NULL,
                                 permission_mode = NULL) {
  .new_obj(list(
    hook_event_name     = "PreCompact",
    session_id          = session_id,
    transcript_path     = transcript_path,
    cwd                 = cwd,
    trigger             = trigger,
    custom_instructions = custom_instructions,
    permission_mode     = permission_mode
  ), "PreCompactHookInput")
}

#' Create a NotificationHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param message Character.
#' @param notification_type Character.
#' @param title Character or NULL.
#' @param permission_mode Character or NULL.
#' @return Object of class `NotificationHookInput`.
#' @export
NotificationHookInput <- function(session_id, transcript_path, cwd,
                                   message, notification_type,
                                   title = NULL,
                                   permission_mode = NULL) {
  .new_obj(list(
    hook_event_name   = "Notification",
    session_id        = session_id,
    transcript_path   = transcript_path,
    cwd               = cwd,
    message           = message,
    notification_type = notification_type,
    title             = title,
    permission_mode   = permission_mode
  ), "NotificationHookInput")
}

#' Create a SubagentStartHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param agent_id Character.
#' @param agent_type Character.
#' @param permission_mode Character or NULL.
#' @return Object of class `SubagentStartHookInput`.
#' @export
SubagentStartHookInput <- function(session_id, transcript_path, cwd,
                                    agent_id, agent_type,
                                    permission_mode = NULL) {
  .new_obj(list(
    hook_event_name = "SubagentStart",
    session_id      = session_id,
    transcript_path = transcript_path,
    cwd             = cwd,
    agent_id        = agent_id,
    agent_type      = agent_type,
    permission_mode = permission_mode
  ), "SubagentStartHookInput")
}

#' Create a PermissionRequestHookInput
#' @param session_id Character.
#' @param transcript_path Character.
#' @param cwd Character.
#' @param tool_name Character.
#' @param tool_input List.
#' @param permission_suggestions List or NULL.
#' @param permission_mode Character or NULL.
#' @param agent_id Character or NULL.
#' @param agent_type Character or NULL.
#' @return Object of class `PermissionRequestHookInput`.
#' @export
PermissionRequestHookInput <- function(session_id, transcript_path, cwd,
                                        tool_name, tool_input,
                                        permission_suggestions = NULL,
                                        permission_mode = NULL,
                                        agent_id = NULL, agent_type = NULL) {
  .new_obj(list(
    hook_event_name        = "PermissionRequest",
    session_id             = session_id,
    transcript_path        = transcript_path,
    cwd                    = cwd,
    tool_name              = tool_name,
    tool_input             = tool_input,
    permission_suggestions = permission_suggestions,
    permission_mode        = permission_mode,
    agent_id               = agent_id,
    agent_type             = agent_type
  ), "PermissionRequestHookInput")
}

# ---------------------------------------------------------------------------
# Hook output types
# ---------------------------------------------------------------------------

#' Create a SyncHookOutput
#'
#' Synchronous hook output returned by hook callbacks.
#'
#' @param continue_ Logical or NULL. Whether to continue execution.
#'   Note: The trailing underscore avoids R's `continue` reserved word.
#'   Serialized as `"continue"` for the CLI.
#' @param suppress_output Logical or NULL. Suppress output.
#' @param stop_reason Character or NULL.
#' @param decision Character or NULL. `"block"` to block execution.
#' @param system_message Character or NULL.
#' @param reason Character or NULL.
#' @param hook_specific_output List or NULL.
#' @return Object of class `SyncHookOutput`.
#' @export
SyncHookOutput <- function(continue_            = NULL,
                            suppress_output      = NULL,
                            stop_reason          = NULL,
                            decision             = NULL,
                            system_message       = NULL,
                            reason               = NULL,
                            hook_specific_output = NULL) {
  .new_obj(list(
    continue_            = continue_,
    suppressOutput       = suppress_output,
    stopReason           = stop_reason,
    decision             = decision,
    systemMessage        = system_message,
    reason               = reason,
    hookSpecificOutput   = hook_specific_output
  ), "SyncHookOutput")
}

#' Create an AsyncHookOutput
#'
#' Signals that the hook will complete asynchronously.
#'
#' @param async_timeout Integer or NULL. Timeout in milliseconds.
#' @return Object of class `AsyncHookOutput`.
#' @export
AsyncHookOutput <- function(async_timeout = NULL) {
  .new_obj(list(
    async_       = TRUE,
    asyncTimeout = async_timeout
  ), "AsyncHookOutput")
}

# ---------------------------------------------------------------------------
# Permission update types
# ---------------------------------------------------------------------------

#' Create a PermissionRuleValue
#' @param tool_name Character. Tool name pattern.
#' @param rule_content Character or NULL.
#' @return Object of class `PermissionRuleValue`.
#' @export
PermissionRuleValue <- function(tool_name, rule_content = NULL) {
  .new_obj(
    list(tool_name = tool_name, rule_content = rule_content),
    "PermissionRuleValue"
  )
}

#' Create a PermissionUpdate
#'
#' Specifies a permission rule change to apply.
#'
#' @param type Character. One of `"addRules"`, `"replaceRules"`,
#'   `"removeRules"`, `"setMode"`, `"addDirectories"`, `"removeDirectories"`.
#' @param rules List of `PermissionRuleValue` or NULL.
#' @param behavior Character or NULL. `"allow"`, `"deny"`, or `"ask"`.
#' @param mode Character or NULL. Permission mode.
#' @param directories Character vector or NULL.
#' @param destination Character or NULL. `"userSettings"`, `"projectSettings"`,
#'   `"localSettings"`, or `"session"`.
#' @return Object of class `PermissionUpdate`.
#' @export
PermissionUpdate <- function(type, rules = NULL, behavior = NULL,
                              mode = NULL, directories = NULL,
                              destination = NULL) {
  .new_obj(list(
    type        = type,
    rules       = rules,
    behavior    = behavior,
    mode        = mode,
    directories = directories,
    destination = destination
  ), "PermissionUpdate")
}

# ---------------------------------------------------------------------------
# System prompt types
# ---------------------------------------------------------------------------

#' Create a SystemPromptPreset
#' @param exclude_dynamic_sections Logical or NULL.
#' @param append Character or NULL. Additional instructions to append.
#' @return Object of class `SystemPromptPreset`.
#' @export
SystemPromptPreset <- function(exclude_dynamic_sections = NULL,
                                append = NULL) {
  .new_obj(list(
    type                      = "preset",
    exclude_dynamic_sections = exclude_dynamic_sections,
    append                   = append
  ), "SystemPromptPreset")
}

#' Create a SystemPromptFile
#' @param path Character. Path to the system prompt file.
#' @return Object of class `SystemPromptFile`.
#' @export
SystemPromptFile <- function(path) {
  .new_obj(list(type = "file", path = path), "SystemPromptFile")
}

# ---------------------------------------------------------------------------
# Sandbox types
# ---------------------------------------------------------------------------

#' Create a SandboxNetworkConfig
#' @param allow_unix_sockets Character vector or NULL.
#' @param allow_all_unix_sockets Logical or NULL.
#' @param allow_local_binding Logical or NULL.
#' @param http_proxy_port Integer or NULL.
#' @param socks_proxy_port Integer or NULL.
#' @return Object of class `SandboxNetworkConfig`.
#' @export
SandboxNetworkConfig <- function(allow_unix_sockets     = NULL,
                                  allow_all_unix_sockets = NULL,
                                  allow_local_binding    = NULL,
                                  http_proxy_port        = NULL,
                                  socks_proxy_port       = NULL) {
  .new_obj(list(
    allowUnixSockets    = allow_unix_sockets,
    allowAllUnixSockets = allow_all_unix_sockets,
    allowLocalBinding   = allow_local_binding,
    httpProxyPort       = http_proxy_port,
    socksProxyPort      = socks_proxy_port
  ), "SandboxNetworkConfig")
}

#' Create a SandboxIgnoreViolations
#' @param file Character vector or NULL.
#' @param network Character vector or NULL.
#' @return Object of class `SandboxIgnoreViolations`.
#' @export
SandboxIgnoreViolations <- function(file = NULL, network = NULL) {
  .new_obj(list(file = file, network = network), "SandboxIgnoreViolations")
}

#' Create SandboxSettings
#' @param enabled Logical or NULL.
#' @param auto_allow_bash_if_sandboxed Logical or NULL.
#' @param excluded_commands Character vector or NULL.
#' @param allow_unsandboxed_commands Logical or NULL.
#' @param network `SandboxNetworkConfig` or NULL.
#' @param ignore_violations `SandboxIgnoreViolations` or NULL.
#' @param enable_weaker_nested_sandbox Logical or NULL.
#' @return Object of class `SandboxSettings`.
#' @export
SandboxSettings <- function(enabled                      = NULL,
                             auto_allow_bash_if_sandboxed = NULL,
                             excluded_commands            = NULL,
                             allow_unsandboxed_commands   = NULL,
                             network                      = NULL,
                             ignore_violations            = NULL,
                             enable_weaker_nested_sandbox = NULL) {
  .new_obj(list(
    enabled                    = enabled,
    autoAllowBashIfSandboxed   = auto_allow_bash_if_sandboxed,
    excludedCommands           = excluded_commands,
    allowUnsandboxedCommands   = allow_unsandboxed_commands,
    network                    = network,
    ignoreViolations           = ignore_violations,
    enableWeakerNestedSandbox  = enable_weaker_nested_sandbox
  ), "SandboxSettings")
}

# ---------------------------------------------------------------------------
# print methods
# ---------------------------------------------------------------------------

#' @export
print.AssistantMessage <- function(x, ...) {
  cat("<AssistantMessage model=", x$model, ">\n", sep = "")
  for (blk in x$content) {
    if (inherits(blk, "TextBlock")) {
      cat("  [text] ", blk$text, "\n", sep = "")
    } else if (inherits(blk, "ToolUseBlock")) {
      cat("  [tool_use] ", blk$name, "(", blk$id, ")\n", sep = "")
    }
  }
  invisible(x)
}

#' @export
print.ResultMessage <- function(x, ...) {
  cat("<ResultMessage is_error=", x$is_error,
      " turns=", x$num_turns,
      " cost=", x$total_cost_usd %||% "NA",
      ">\n", sep = "")
  invisible(x)
}

#' @title Message Type Constructors
#' @description Lightweight S3 constructors mirroring every dataclass defined
#'   in the Python SDK's `types.py`.  All objects are named lists with a
#'   `class` attribute.  Fields match Python field names exactly (snake_case).
#' @name types
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
#' @param model Character or NULL. Model ID for the agent.
#' @return Object of class `AgentDefinition`.
#' @export
AgentDefinition <- function(description,
                             prompt  = NULL,
                             tools   = NULL,
                             model   = NULL) {
  .new_obj(
    list(
      description = description,
      prompt      = prompt,
      tools       = tools,
      model       = model
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

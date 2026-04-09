#' @title Protocol — JSON Parsing and Message Building
#' @description Converts raw newline-delimited JSON lines from the Claude Code
#'   CLI into typed R objects, and builds outgoing JSON messages.
#'   Mirrors `_internal/message_parser.py`.
#' @name protocol
NULL

# ---------------------------------------------------------------------------
# parse_message  — raw JSON line → typed Message object
# ---------------------------------------------------------------------------

#' Parse a single JSON line from the CLI into a typed message object
#'
#' @param line Character(1). A single newline-delimited JSON string received
#'   from the CLI's stdout.
#' @return A typed message object (one of the classes defined in `types.R`),
#'   a raw control-request list (passed through to the transport layer), or
#'   `NULL` for unrecognized message types (forward-compatible behaviour).
#' @keywords internal
parse_message <- function(line) {
  obj <- tryCatch(
    jsonlite::fromJSON(line, simplifyVector = FALSE),
    error = function(e) claude_json_decode_error(line, e)
  )

  if (!is.list(obj)) {
    claude_message_parse_error(
      paste0("Invalid message data type (expected object, got ", class(obj)[[1]], ")"),
      obj
    )
  }

  msg_type <- obj[["type"]]
  if (is.null(msg_type) || !nzchar(msg_type)) {
    claude_message_parse_error("Message missing 'type' field", obj)
  }

  switch(msg_type,
    "user"             = .parse_user_message(obj),
    "assistant"        = .parse_assistant_message(obj),
    "system"           = .parse_system_message(obj),
    "result"           = .parse_result_message(obj),
    "stream_event"     = .parse_stream_event(obj),
    "rate_limit_event" = .parse_rate_limit_event(obj),
    "control_request"        = obj,   # pass-through for transport layer
    "control_response"       = obj,   # pass-through for client layer
    "control_cancel_request" = obj,   # pass-through; handled in transport loop
    {
      # Forward-compatible: skip unknown types silently (returns NULL)
      NULL
    }
  )
}

# ---------------------------------------------------------------------------
# Private parsers
# ---------------------------------------------------------------------------

.parse_content_blocks <- function(content_list) {
  blocks <- vector("list", length(content_list))
  for (i in seq_along(content_list)) {
    blk <- content_list[[i]]
    blocks[[i]] <- switch(blk[["type"]],
      "text"        = TextBlock(blk[["text"]]),
      "thinking"    = ThinkingBlock(blk[["thinking"]], blk[["signature"]]),
      "tool_use"    = ToolUseBlock(blk[["id"]], blk[["name"]], blk[["input"]]),
      "tool_result" = ToolResultBlock(
        blk[["tool_use_id"]],
        blk[["content"]],
        blk[["is_error"]]
      ),
      blk  # unknown block type → pass through raw
    )
  }
  blocks
}

.parse_user_message <- function(obj) {
  msg <- obj[["message"]]
  if (is.null(msg)) {
    claude_message_parse_error("Missing 'message' field in user message", obj)
  }
  content <- msg[["content"]]
  parsed_content <- if (is.list(content)) {
    .parse_content_blocks(content)
  } else {
    content  # plain string
  }
  UserMessage(
    content            = parsed_content,
    uuid               = obj[["uuid"]],
    parent_tool_use_id = obj[["parent_tool_use_id"]],
    tool_use_result    = obj[["tool_use_result"]]
  )
}

.parse_assistant_message <- function(obj) {
  msg <- obj[["message"]]
  if (is.null(msg)) {
    claude_message_parse_error("Missing 'message' field in assistant message", obj)
  }
  content_list <- msg[["content"]]
  if (!is.list(content_list)) {
    claude_message_parse_error("Missing 'content' in assistant message", obj)
  }
  AssistantMessage(
    content            = .parse_content_blocks(content_list),
    model              = msg[["model"]] %||% "",
    parent_tool_use_id = obj[["parent_tool_use_id"]],
    error              = obj[["error"]],
    usage              = msg[["usage"]],
    message_id         = msg[["id"]],
    stop_reason        = msg[["stop_reason"]],
    session_id         = obj[["session_id"]],
    uuid               = obj[["uuid"]]
  )
}

.parse_system_message <- function(obj) {
  subtype <- obj[["subtype"]]
  if (is.null(subtype)) {
    claude_message_parse_error("Missing 'subtype' in system message", obj)
  }
  switch(subtype,
    "task_started" = TaskStartedMessage(
      subtype     = subtype,
      data        = obj,
      task_id     = obj[["task_id"]],
      description = obj[["description"]],
      uuid        = obj[["uuid"]],
      session_id  = obj[["session_id"]],
      tool_use_id = obj[["tool_use_id"]],
      task_type   = obj[["task_type"]]
    ),
    "task_progress" = TaskProgressMessage(
      subtype        = subtype,
      data           = obj,
      task_id        = obj[["task_id"]],
      description    = obj[["description"]],
      usage          = obj[["usage"]],
      uuid           = obj[["uuid"]],
      session_id     = obj[["session_id"]],
      tool_use_id    = obj[["tool_use_id"]],
      last_tool_name = obj[["last_tool_name"]]
    ),
    "task_notification" = TaskNotificationMessage(
      subtype     = subtype,
      data        = obj,
      task_id     = obj[["task_id"]],
      status      = obj[["status"]],
      output_file = obj[["output_file"]],
      summary     = obj[["summary"]],
      uuid        = obj[["uuid"]],
      session_id  = obj[["session_id"]],
      tool_use_id = obj[["tool_use_id"]],
      usage       = obj[["usage"]]
    ),
    # default
    SystemMessage(subtype = subtype, data = obj)
  )
}

.parse_result_message <- function(obj) {
  ResultMessage(
    subtype            = obj[["subtype"]],
    duration_ms        = obj[["duration_ms"]],
    duration_api_ms    = obj[["duration_api_ms"]],
    is_error           = isTRUE(obj[["is_error"]]),
    num_turns          = obj[["num_turns"]],
    session_id         = obj[["session_id"]],
    stop_reason        = obj[["stop_reason"]],
    total_cost_usd     = obj[["total_cost_usd"]],
    usage              = obj[["usage"]],
    result             = obj[["result"]],
    structured_output  = obj[["structured_output"]],
    model_usage        = obj[["modelUsage"]],
    permission_denials = obj[["permission_denials"]],
    errors             = obj[["errors"]],
    uuid               = obj[["uuid"]]
  )
}

.parse_stream_event <- function(obj) {
  StreamEvent(
    uuid               = obj[["uuid"]],
    session_id         = obj[["session_id"]],
    event              = obj[["event"]],
    parent_tool_use_id = obj[["parent_tool_use_id"]]
  )
}

.parse_rate_limit_event <- function(obj) {
  info <- obj[["rate_limit_info"]]
  if (is.null(info)) {
    claude_message_parse_error("Missing 'rate_limit_info' in rate_limit_event", obj)
  }
  RateLimitEvent(
    rate_limit_info = RateLimitInfo(
      status                   = info[["status"]],
      resets_at                = info[["resetsAt"]],
      rate_limit_type          = info[["rateLimitType"]],
      utilization              = info[["utilization"]],
      overage_status           = info[["overageStatus"]],
      overage_resets_at        = info[["overageResetsAt"]],
      overage_disabled_reason  = info[["overageDisabledReason"]],
      raw                      = info
    ),
    uuid       = obj[["uuid"]],
    session_id = obj[["session_id"]]
  )
}

# ---------------------------------------------------------------------------
# Outgoing message builders
# ---------------------------------------------------------------------------

#' Build a control-response JSON string
#'
#' @param request_id Character. The `request_id` from the incoming
#'   `control_request`.
#' @param response List. The response payload.
#' @return Character(1). JSON string to write to the CLI's stdin.
#' @keywords internal
build_control_response <- function(request_id, response) {
  jsonlite::toJSON(
    list(
      type     = "control_response",
      response = list(
        subtype    = "success",
        request_id = request_id,
        response   = response
      )
    ),
    auto_unbox = TRUE,
    null       = "null"
  )
}

#' Build an error control-response JSON string
#' @keywords internal
build_control_error_response <- function(request_id, error_msg) {
  jsonlite::toJSON(
    list(
      type     = "control_response",
      response = list(
        subtype    = "error",
        request_id = request_id,
        error      = error_msg
      )
    ),
    auto_unbox = TRUE,
    null       = "null"
  )
}

#' Build an outgoing user-message JSON string
#'
#' @param prompt Character(1) or list. Prompt text or content block list.
#' @param session_id Character(1). Session identifier (default `"default"`).
#' @return Character(1). JSON string ready to write to the CLI's stdin.
#' @keywords internal
build_user_message_json <- function(prompt, session_id = "default") {
  jsonlite::toJSON(
    list(
      type               = "user",
      session_id         = session_id,
      message            = list(role = "user", content = prompt),
      parent_tool_use_id = NULL
    ),
    auto_unbox = TRUE,
    null       = "null"
  )
}

#' Build an initialize control-request JSON string
#' @param request_id Character.
#' @param hooks_config List or NULL. Hook configuration.
#' @param agents List or NULL. Agent definitions.
#' @param exclude_dynamic_sections Logical or NULL.
#' @keywords internal
build_initialize_request <- function(request_id, hooks_config = NULL,
                                      agents = NULL,
                                      exclude_dynamic_sections = NULL) {
  req <- list(subtype = "initialize", hooks = hooks_config)
  if (!is.null(agents)) req[["agents"]] <- agents
  if (!is.null(exclude_dynamic_sections)) {
    req[["excludeDynamicSections"]] <- exclude_dynamic_sections
  }
  jsonlite::toJSON(
    list(type = "control_request", request_id = request_id, request = req),
    auto_unbox = TRUE,
    null       = "null"
  )
}

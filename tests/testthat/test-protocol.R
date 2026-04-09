test_that("parse_message: user message with text content", {
  json <- '{"type":"user","message":{"role":"user","content":"hello"},"uuid":"u1","parent_tool_use_id":null,"tool_use_result":null}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "UserMessage")
  expect_equal(msg$content, "hello")
  expect_equal(msg$uuid, "u1")
})

test_that("parse_message: user message with content blocks", {
  json <- '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"hi"}]},"uuid":"u2"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "UserMessage")
  expect_s3_class(msg$content[[1]], "TextBlock")
  expect_equal(msg$content[[1]]$text, "hi")
})

test_that("parse_message: assistant message", {
  json <- '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"hello"}],"model":"claude-opus-4-6","usage":{"input_tokens":10,"output_tokens":5}},"session_id":"s1","uuid":"a1"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "AssistantMessage")
  expect_equal(msg$model, "claude-opus-4-6")
  expect_length(msg$content, 1L)
  expect_s3_class(msg$content[[1]], "TextBlock")
  expect_equal(msg$session_id, "s1")
})

test_that("parse_message: assistant with tool_use block", {
  json <- '{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"tu1","name":"Bash","input":{"command":"ls"}}],"model":"claude-x"}}'
  msg  <- parse_message(json)
  blk  <- msg$content[[1]]
  expect_s3_class(blk, "ToolUseBlock")
  expect_equal(blk$id, "tu1")
  expect_equal(blk$name, "Bash")
})

test_that("parse_message: result message", {
  json <- '{"type":"result","subtype":"success","duration_ms":1234,"duration_api_ms":800,"is_error":false,"num_turns":2,"session_id":"s1","total_cost_usd":0.001}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "ResultMessage")
  expect_false(msg$is_error)
  expect_equal(msg$num_turns, 2L)
  expect_equal(msg$total_cost_usd, 0.001)
})

test_that("parse_message: system message generic", {
  json <- '{"type":"system","subtype":"init"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "SystemMessage")
  expect_equal(msg$subtype, "init")
})

test_that("parse_message: task_started system message", {
  json <- '{"type":"system","subtype":"task_started","task_id":"t1","description":"do it","uuid":"u1","session_id":"s1"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "TaskStartedMessage")
  expect_s3_class(msg, "SystemMessage")
  expect_equal(msg$task_id, "t1")
})

test_that("parse_message: stream_event", {
  json <- '{"type":"stream_event","uuid":"u1","session_id":"s1","event":{"type":"content_block_delta"}}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "StreamEvent")
  expect_equal(msg$uuid, "u1")
})

test_that("parse_message: rate_limit_event", {
  json <- '{"type":"rate_limit_event","uuid":"u1","session_id":"s1","rate_limit_info":{"status":"allowed","rateLimitType":"five_hour","utilization":0.5}}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "RateLimitEvent")
  expect_s3_class(msg$rate_limit_info, "RateLimitInfo")
  expect_equal(msg$rate_limit_info$status, "allowed")
  expect_equal(msg$rate_limit_info$utilization, 0.5)
})

test_that("parse_message: control_request passes through", {
  json <- '{"type":"control_request","request_id":"req_1","request":{"subtype":"initialize"}}'
  msg  <- parse_message(json)
  expect_true(is.list(msg))
  expect_equal(msg$type, "control_request")
})

test_that("parse_message: unknown type returns NULL", {
  json <- '{"type":"future_unknown_type","data":"x"}'
  msg  <- parse_message(json)
  expect_null(msg)
})

test_that("parse_message: invalid JSON raises error", {
  expect_error(parse_message("{not-json}"), class = "claude_error_json_decode")
})

test_that("build_control_response produces valid JSON", {
  json <- build_control_response("req_1", list(decision = "allow"))
  obj  <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_equal(obj$type, "control_response")
  expect_equal(obj$response$subtype, "success")
  expect_equal(obj$response$request_id, "req_1")
  expect_equal(obj$response$response$decision, "allow")
})

test_that("build_user_message_json produces valid JSON", {
  json <- build_user_message_json("hello", session_id = "sess-1")
  obj  <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_equal(obj$type, "user")
  expect_equal(obj$session_id, "sess-1")
  expect_equal(obj$message$content, "hello")
})

test_that("split_lines_with_buffer handles no newline", {
  res <- split_lines_with_buffer("", "hello world")
  expect_equal(res$complete_lines, character(0))
  expect_equal(res$remaining, "hello world")
})

test_that("split_lines_with_buffer splits complete lines", {
  res <- split_lines_with_buffer("", "line1\nline2\n")
  expect_equal(res$complete_lines, c("line1", "line2"))
  expect_equal(res$remaining, "")
})

test_that("split_lines_with_buffer accumulates buffer", {
  res1 <- split_lines_with_buffer("", "partial")
  res2 <- split_lines_with_buffer(res1$remaining, " line\nnext")
  expect_equal(res2$complete_lines, "partial line")
  expect_equal(res2$remaining, "next")
})

# --------------------------------------------------------------------------
# Hook output conversion (mirrors Python _convert_hook_output_for_cli)
# --------------------------------------------------------------------------

test_that("transport converts continue_ to continue in hook output", {
  t <- SubprocessCLITransport$new(ClaudeAgentOptions())
  env <- t$.__enclos_env__$private
  result <- env$convert_hook_output_for_cli(list(continue_ = FALSE, reason = "blocked"))
  expect_null(result[["continue_"]])
  expect_equal(result[["continue"]], FALSE)
  expect_equal(result[["reason"]], "blocked")
})

test_that("transport converts async_ to async in hook output", {
  t <- SubprocessCLITransport$new(ClaudeAgentOptions())
  env <- t$.__enclos_env__$private
  result <- env$convert_hook_output_for_cli(list(async_ = TRUE))
  expect_null(result[["async_"]])
  expect_equal(result[["async"]], TRUE)
})

test_that("transport leaves continue unchanged (no underscore needed in R)", {
  t <- SubprocessCLITransport$new(ClaudeAgentOptions())
  env <- t$.__enclos_env__$private
  result <- env$convert_hook_output_for_cli(list(continue = TRUE, foo = "bar"))
  expect_equal(result[["continue"]], TRUE)
  expect_equal(result[["foo"]], "bar")
})

test_that("build_agents_config strips NULL fields and class attribute", {
  t <- SubprocessCLITransport$new(ClaudeAgentOptions())
  env <- t$.__enclos_env__$private
  agents <- list(
    reviewer = AgentDefinition(
      description = "reviews code",
      model       = "claude-sonnet-4-6"
    )
  )
  cfg <- env$build_agents_config(agents)
  expect_null(cfg[["reviewer"]][["prompt"]])
  expect_null(cfg[["reviewer"]][["tools"]])
  expect_null(cfg[["reviewer"]][["class"]])
  expect_equal(cfg[["reviewer"]][["description"]], "reviews code")
  expect_equal(cfg[["reviewer"]][["model"]], "claude-sonnet-4-6")
})

test_that("build_agents_config produces named dict with camelCase", {
  t <- SubprocessCLITransport$new(ClaudeAgentOptions())
  env <- t$.__enclos_env__$private
  agents <- list(
    myagent = AgentDefinition(
      description      = "test",
      prompt           = "hi",
      disallowed_tools = c("Bash"),
      mcp_servers      = list("server1"),
      initial_prompt   = "start here",
      max_turns        = 5L,
      permission_mode  = "bypassPermissions"
    )
  )
  cfg <- env$build_agents_config(agents)
  # Named dict keyed by agent name
  expect_true("myagent" %in% names(cfg))
  ag <- cfg[["myagent"]]
  # camelCase field names
  expect_equal(ag[["disallowedTools"]], c("Bash"))
  expect_equal(ag[["mcpServers"]], list("server1"))
  expect_equal(ag[["initialPrompt"]], "start here")
  expect_equal(ag[["maxTurns"]], 5L)
  expect_equal(ag[["permissionMode"]], "bypassPermissions")
  # snake_case originals should NOT be present
  expect_null(ag[["disallowed_tools"]])
  expect_null(ag[["mcp_servers"]])
  expect_null(ag[["initial_prompt"]])
  expect_null(ag[["max_turns"]])
  expect_null(ag[["permission_mode"]])
})

# ---------------------------------------------------------------------------
# Additional parse_message coverage
# ---------------------------------------------------------------------------

test_that("parse_message: user message with tool_use_result", {
  json <- '{"type":"user","message":{"role":"user","content":"result"},"uuid":"u1","tool_use_result":{"tool_use_id":"tu1","content":"ok","is_error":false}}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "UserMessage")
  expect_equal(msg$tool_use_result$tool_use_id, "tu1")
})

test_that("parse_message: assistant with thinking block", {
  json <- '{"type":"assistant","message":{"role":"assistant","content":[{"type":"thinking","thinking":"deep thought","signature":"sig1"},{"type":"text","text":"answer"}],"model":"m"}}'
  msg  <- parse_message(json)
  expect_length(msg$content, 2L)
  expect_s3_class(msg$content[[1]], "ThinkingBlock")
  expect_equal(msg$content[[1]]$thinking, "deep thought")
  expect_s3_class(msg$content[[2]], "TextBlock")
})

test_that("parse_message: assistant with usage", {
  json <- '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"hi"}],"model":"m","usage":{"input_tokens":100,"output_tokens":50}}}'
  msg  <- parse_message(json)
  expect_equal(msg$usage$input_tokens, 100L)
  expect_equal(msg$usage$output_tokens, 50L)
})

test_that("parse_message: result with stop_reason and model_usage", {
  json <- '{"type":"result","subtype":"success","is_error":false,"num_turns":1,"session_id":"s1","stop_reason":"end_turn","modelUsage":{"input":500,"output":200}}'
  msg  <- parse_message(json)
  expect_equal(msg$stop_reason, "end_turn")
  expect_equal(msg$model_usage$input, 500L)
})

test_that("parse_message: result with errors list", {
  json <- '{"type":"result","subtype":"error","is_error":true,"num_turns":0,"session_id":"s1","errors":["timeout","quota"]}'
  msg  <- parse_message(json)
  expect_true(msg$is_error)
  expect_equal(msg$errors, list("timeout", "quota"))
})

test_that("parse_message: task_progress system message", {
  json <- '{"type":"system","subtype":"task_progress","task_id":"t1","description":"running","uuid":"u1","session_id":"s1","last_tool_name":"Bash"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "TaskProgressMessage")
  expect_s3_class(msg, "SystemMessage")
  expect_equal(msg$last_tool_name, "Bash")
})

test_that("parse_message: task_notification system message", {
  json <- '{"type":"system","subtype":"task_notification","task_id":"t1","status":"completed","output_file":"/tmp/out","summary":"done","uuid":"u1","session_id":"s1"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "TaskNotificationMessage")
  expect_equal(msg$status, "completed")
  expect_equal(msg$output_file, "/tmp/out")
})

test_that("parse_message: control_cancel_request passes through", {
  json <- '{"type":"control_cancel_request","request_id":"req_1"}'
  msg  <- parse_message(json)
  expect_true(is.list(msg))
  expect_equal(msg$type, "control_cancel_request")
})

test_that("parse_message: control_response passes through", {
  json <- '{"type":"control_response","response":{"subtype":"success","request_id":"req_1","response":{}}}'
  msg  <- parse_message(json)
  expect_true(is.list(msg))
  expect_equal(msg$type, "control_response")
})

test_that("parse_message: missing type field raises error", {
  json <- '{"data":"no type field"}'
  expect_error(parse_message(json), class = "claude_error_message_parse")
})

test_that("parse_message: non-object raises error", {
  json <- '"just a string"'
  expect_error(parse_message(json), class = "claude_error_message_parse")
})

test_that("build_initialize_request includes agents and exclude_dynamic_sections", {
  json <- build_initialize_request("req_1",
    hooks_config = list(PreToolUse = list()),
    agents = list(a1 = list(description = "test")),
    exclude_dynamic_sections = TRUE
  )
  obj <- jsonlite::fromJSON(json, simplifyVector = FALSE)
  expect_equal(obj$request$subtype, "initialize")
  expect_true("a1" %in% names(obj$request$agents))
  expect_true(obj$request$excludeDynamicSections)
})

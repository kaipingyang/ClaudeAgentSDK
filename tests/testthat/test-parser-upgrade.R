# Tests for v0.2.110 parity upgrade (server-tool blocks, task_updated,
# deferred_tool_use / api_error_status, hook events, new option flags,
# sandbox network fields, permission-context fields, rate-limit enums).

# Local helper (mirrors test-transport-build-command.R): build CLI args from opts
build_args <- function(opts) {
  t <- ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
  t$.__enclos_env__$private$build_command()
}

# ---------------------------------------------------------------------------
# M1: server-tool content blocks
# ---------------------------------------------------------------------------

test_that("parse_message: assistant with server_tool_use block", {
  json <- '{"type":"assistant","message":{"role":"assistant","content":[{"type":"server_tool_use","id":"srv1","name":"web_search","input":{"query":"R"}}],"model":"claude-x"}}'
  msg  <- parse_message(json)
  blk  <- msg$content[[1]]
  expect_s3_class(blk, "ServerToolUseBlock")
  expect_equal(blk$id, "srv1")
  expect_equal(blk$name, "web_search")
  expect_equal(blk$input$query, "R")
})

test_that("parse_message: assistant with advisor_tool_result block", {
  json <- '{"type":"assistant","message":{"role":"assistant","content":[{"type":"advisor_tool_result","tool_use_id":"srv1","content":{"type":"web_search_result"}}],"model":"claude-x"}}'
  msg  <- parse_message(json)
  blk  <- msg$content[[1]]
  expect_s3_class(blk, "ServerToolResultBlock")
  expect_equal(blk$tool_use_id, "srv1")
  expect_equal(blk$content$type, "web_search_result")
  expect_null(blk$is_error)  # ServerToolResultBlock has no is_error field
})

test_that("SERVER_TOOL_NAMES exported and contains web_search", {
  expect_true("web_search" %in% SERVER_TOOL_NAMES)
  expect_true("advisor" %in% SERVER_TOOL_NAMES)
})

# ---------------------------------------------------------------------------
# M2: task_updated
# ---------------------------------------------------------------------------

test_that("parse_message: task_updated -> TaskUpdatedMessage with patch.status", {
  json <- '{"type":"system","subtype":"task_updated","task_id":"t1","patch":{"status":"completed","end_time":123},"session_id":"s1","uuid":"u1"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "TaskUpdatedMessage")
  expect_s3_class(msg, "SystemMessage")
  expect_equal(msg$task_id, "t1")
  expect_equal(msg$status, "completed")
  expect_equal(msg$patch$end_time, 123L)
})

test_that("parse_message: task_updated defensive (missing patch/task_id)", {
  json <- '{"type":"system","subtype":"task_updated"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "TaskUpdatedMessage")
  expect_equal(msg$task_id, "")
  expect_null(msg$status)
  expect_equal(msg$patch, list())
})

test_that("TERMINAL_TASK_STATUSES and TASK_UPDATED_STATUSES exported", {
  expect_true(all(c("completed", "failed", "killed") %in% TERMINAL_TASK_STATUSES))
  expect_true("running" %in% TASK_UPDATED_STATUSES)
})

# ---------------------------------------------------------------------------
# M3: deferred_tool_use + api_error_status
# ---------------------------------------------------------------------------

test_that("parse_message: result with deferred_tool_use + api_error_status", {
  json <- paste0(
    '{"type":"result","subtype":"success","duration_ms":1,"duration_api_ms":1,',
    '"is_error":true,"num_turns":1,"session_id":"s1",',
    '"deferred_tool_use":{"id":"d1","name":"Bash","input":{"command":"ls"}},',
    '"api_error_status":429}'
  )
  msg <- parse_message(json)
  expect_s3_class(msg, "ResultMessage")
  expect_s3_class(msg$deferred_tool_use, "DeferredToolUse")
  expect_equal(msg$deferred_tool_use$id, "d1")
  expect_equal(msg$deferred_tool_use$name, "Bash")
  expect_equal(msg$api_error_status, 429L)
})

test_that("parse_message: result without deferred is NULL", {
  json <- '{"type":"result","subtype":"success","duration_ms":1,"duration_api_ms":1,"is_error":false,"num_turns":1,"session_id":"s1"}'
  msg  <- parse_message(json)
  expect_null(msg$deferred_tool_use)
  expect_null(msg$api_error_status)
})

# ---------------------------------------------------------------------------
# M3b: hook events
# ---------------------------------------------------------------------------

test_that("parse_message: hook_started -> HookEventMessage", {
  json <- '{"type":"system","subtype":"hook_started","hook_event":"PreToolUse","session_id":"s1","uuid":"u1"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "HookEventMessage")
  expect_s3_class(msg, "SystemMessage")
  expect_equal(msg$subtype, "hook_started")
  expect_equal(msg$hook_event_name, "PreToolUse")
})

test_that("parse_message: hook_response falls back to hook_event_name key", {
  json <- '{"type":"system","subtype":"hook_response","hook_event_name":"Stop"}'
  msg  <- parse_message(json)
  expect_s3_class(msg, "HookEventMessage")
  expect_equal(msg$hook_event_name, "Stop")
})

# ---------------------------------------------------------------------------
# Options + build_command flags
# ---------------------------------------------------------------------------

test_that("strict_mcp_config / include_hook_events produce flags", {
  args <- build_args(ClaudeAgentOptions(strict_mcp_config = TRUE,
                                        include_hook_events = TRUE))
  expect_true("--strict-mcp-config" %in% args)
  expect_true("--include-hook-events" %in% args)
})

test_that("skills='all' injects Skill tool + defaults setting-sources", {
  args <- build_args(ClaudeAgentOptions(skills = "all"))
  i <- which(args == "--allowedTools")
  expect_true(length(i) == 1L && grepl("Skill", args[i + 1L], fixed = TRUE))
  j <- which(args == "--setting-sources")
  expect_true(length(j) == 1L && args[j + 1L] == "user,project")
})

test_that("skills=list injects Skill(name) patterns", {
  args <- build_args(ClaudeAgentOptions(skills = c("pdf", "excel")))
  i <- which(args == "--allowedTools")
  expect_true(grepl("Skill(pdf)", args[i + 1L], fixed = TRUE))
  expect_true(grepl("Skill(excel)", args[i + 1L], fixed = TRUE))
})

test_that("thinking display emits --thinking-display", {
  args <- build_args(ClaudeAgentOptions(
    thinking = ThinkingConfigEnabled(budget_tokens = 5000L, display = "summarized")
  ))
  k <- which(args == "--thinking-display")
  expect_true(length(k) == 1L && args[k + 1L] == "summarized")
})

test_that("thinking disabled never emits --thinking-display", {
  args <- build_args(ClaudeAgentOptions(thinking = ThinkingConfigDisabled()))
  expect_false("--thinking-display" %in% args)
})

# ---------------------------------------------------------------------------
# Config types
# ---------------------------------------------------------------------------

test_that("SandboxNetworkConfig carries domain + mach fields (camelCase)", {
  nc <- SandboxNetworkConfig(
    allowed_domains            = c("example.com"),
    denied_domains             = c("evil.com"),
    allow_managed_domains_only = TRUE,
    allow_mach_lookup          = c("com.apple.x")
  )
  expect_equal(nc$allowedDomains, "example.com")
  expect_equal(nc$deniedDomains, "evil.com")
  expect_true(nc$allowManagedDomainsOnly)
  expect_equal(nc$allowMachLookup, "com.apple.x")
})

test_that("ThinkingConfig display stored, absent when NULL", {
  expect_equal(ThinkingConfigAdaptive(display = "omitted")$display, "omitted")
  expect_null(ThinkingConfigAdaptive()$display)
  expect_false("display" %in% names(ThinkingConfigAdaptive()))
})

# ---------------------------------------------------------------------------
# Callback context / permission fields
# ---------------------------------------------------------------------------

test_that("ToolPermissionContext carries UI fields", {
  ctx <- ToolPermissionContext(
    blocked_path = "/tmp/x", decision_reason = "hook asked",
    title = "Claude wants to read x", display_name = "Read file",
    description = "subtitle"
  )
  expect_equal(ctx$blocked_path, "/tmp/x")
  expect_equal(ctx$decision_reason, "hook asked")
  expect_equal(ctx$title, "Claude wants to read x")
  expect_equal(ctx$display_name, "Read file")
  expect_equal(ctx$description, "subtitle")
})

test_that("PermissionRequestMessage carries UI fields", {
  msg <- PermissionRequestMessage(
    request_id = "r1", tool_name = "Read", tool_input = list(),
    title = "T", display_name = "D", description = "S",
    blocked_path = "/p", decision_reason = "R"
  )
  expect_equal(msg$title, "T")
  expect_equal(msg$display_name, "D")
  expect_equal(msg$description, "S")
  expect_equal(msg$blocked_path, "/p")
  expect_equal(msg$decision_reason, "R")
})

test_that("PostToolUseHookSpecificOutput has updatedToolOutput", {
  out <- PostToolUseHookSpecificOutput(updated_tool_output = "rewritten")
  expect_equal(out$updatedToolOutput, "rewritten")
  expect_equal(out$hookEventName, "PostToolUse")
})

# ---------------------------------------------------------------------------
# RateLimit enums
# ---------------------------------------------------------------------------

test_that("RATE_LIMIT_STATUSES / RATE_LIMIT_TYPES exported with expected values", {
  expect_setequal(RATE_LIMIT_STATUSES, c("allowed", "allowed_warning", "rejected"))
  expect_true(all(c("five_hour", "seven_day", "overage") %in% RATE_LIMIT_TYPES))
})

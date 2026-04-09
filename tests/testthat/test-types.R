test_that("text_block has correct class and fields", {
  b <- TextBlock("hello")
  expect_s3_class(b, "TextBlock")
  expect_equal(b$text, "hello")
})

test_that("thinking_block has correct fields", {
  b <- ThinkingBlock("thoughts", "sig123")
  expect_s3_class(b, "ThinkingBlock")
  expect_equal(b$thinking, "thoughts")
  expect_equal(b$signature, "sig123")
})

test_that("tool_use_block stores all fields", {
  b <- ToolUseBlock("id1", "Bash", list(command = "ls"))
  expect_s3_class(b, "ToolUseBlock")
  expect_equal(b$id, "id1")
  expect_equal(b$name, "Bash")
  expect_equal(b$input$command, "ls")
})

test_that("tool_result_block stores all fields", {
  b <- ToolResultBlock("id1", "output text", FALSE)
  expect_s3_class(b, "ToolResultBlock")
  expect_equal(b$tool_use_id, "id1")
  expect_equal(b$content, "output text")
  expect_false(b$is_error)
})

test_that("user_message has correct class and defaults", {
  m <- UserMessage("hi")
  expect_s3_class(m, "UserMessage")
  expect_equal(m$content, "hi")
  expect_null(m$uuid)
  expect_null(m$parent_tool_use_id)
})

test_that("assistant_message has correct class", {
  m <- AssistantMessage(
    content = list(TextBlock("hello")),
    model   = "claude-opus-4-6"
  )
  expect_s3_class(m, "AssistantMessage")
  expect_equal(m$model, "claude-opus-4-6")
  expect_length(m$content, 1L)
})

test_that("result_message has correct class", {
  m <- ResultMessage(
    subtype         = "success",
    duration_ms     = 1000L,
    duration_api_ms = 500L,
    is_error        = FALSE,
    num_turns       = 1L,
    session_id      = "sess-1"
  )
  expect_s3_class(m, "ResultMessage")
  expect_false(m$is_error)
  expect_equal(m$num_turns, 1L)
})

test_that("system_message has correct class", {
  m <- SystemMessage("init", list(foo = "bar"))
  expect_s3_class(m, "SystemMessage")
  expect_equal(m$subtype, "init")
})

test_that("TaskStartedMessage inherits SystemMessage", {
  m <- TaskStartedMessage("task_started", list(), "t1", "do stuff", "u1", "s1")
  expect_s3_class(m, "TaskStartedMessage")
  expect_s3_class(m, "SystemMessage")
})

test_that("permission_result_allow default behavior", {
  r <- PermissionResultAllow()
  expect_s3_class(r, "PermissionResultAllow")
  expect_equal(r$behavior, "allow")
  expect_null(r$updated_input)
})

test_that("permission_result_deny stores message and interrupt", {
  r <- PermissionResultDeny("nope", interrupt = TRUE)
  expect_s3_class(r, "PermissionResultDeny")
  expect_equal(r$behavior, "deny")
  expect_equal(r$message, "nope")
  expect_true(r$interrupt)
})

test_that("rate_limit_info defaults", {
  r <- RateLimitInfo("allowed")
  expect_s3_class(r, "RateLimitInfo")
  expect_equal(r$status, "allowed")
  expect_null(r$resets_at)
})

test_that("AgentDefinition stores all fields", {
  a <- AgentDefinition(
    description = "test agent",
    prompt      = "You are a test",
    tools       = c("Read", "Grep"),
    model       = "claude-sonnet-4-6"
  )
  expect_s3_class(a, "AgentDefinition")
  expect_equal(a$description, "test agent")
  expect_equal(a$prompt, "You are a test")
  expect_equal(a$tools, c("Read", "Grep"))
  expect_equal(a$model, "claude-sonnet-4-6")
})

test_that("AgentDefinition allows NULL optional fields", {
  a <- AgentDefinition("minimal agent")
  expect_s3_class(a, "AgentDefinition")
  expect_null(a$prompt)
  expect_null(a$tools)
  expect_null(a$model)
  expect_null(a$disallowed_tools)
  expect_null(a$skills)
  expect_null(a$memory)
  expect_null(a$mcp_servers)
  expect_null(a$initial_prompt)
  expect_null(a$max_turns)
  expect_null(a$background)
  expect_null(a$effort)
  expect_null(a$permission_mode)
})

test_that("AgentDefinition stores new fields (parity with Python)", {
  a <- AgentDefinition(
    description      = "full agent",
    prompt           = "sys prompt",
    tools            = c("Read"),
    disallowed_tools = c("Bash", "Write"),
    model            = "claude-sonnet-4-6",
    skills           = c("commit", "review"),
    memory           = "project",
    mcp_servers      = list("server1"),
    initial_prompt   = "start here",
    max_turns        = 10L,
    background       = TRUE,
    effort           = "high",
    permission_mode  = "bypassPermissions"
  )
  expect_equal(a$disallowed_tools, c("Bash", "Write"))
  expect_equal(a$skills, c("commit", "review"))
  expect_equal(a$memory, "project")
  expect_equal(a$mcp_servers, list("server1"))
  expect_equal(a$initial_prompt, "start here")
  expect_equal(a$max_turns, 10L)
  expect_true(a$background)
  expect_equal(a$effort, "high")
  expect_equal(a$permission_mode, "bypassPermissions")
})

test_that("AgentDefinition effort accepts integer", {
  a <- AgentDefinition("agent", effort = 42L)
  expect_equal(a$effort, 42L)
})

test_that("ClaudeAgentOptions system_prompt preset with exclude_dynamic_sections", {
  opts <- ClaudeAgentOptions(
    system_prompt = list(type = "preset", exclude_dynamic_sections = TRUE)
  )
  expect_equal(opts$system_prompt$type, "preset")
  expect_true(opts$system_prompt$exclude_dynamic_sections)
})

test_that("ClaudeAgentOptions system_prompt file", {
  opts <- ClaudeAgentOptions(
    system_prompt = list(type = "file", path = "/tmp/prompt.txt")
  )
  expect_equal(opts$system_prompt$type, "file")
  expect_equal(opts$system_prompt$path, "/tmp/prompt.txt")
})

test_that("ClaudeAgentOptions system_prompt preset with append", {
  opts <- ClaudeAgentOptions(
    system_prompt = list(type = "preset", append = "extra instructions")
  )
  expect_equal(opts$system_prompt$append, "extra instructions")
})

# ---------------------------------------------------------------------------
# Hook input types
# ---------------------------------------------------------------------------

test_that("PreToolUseHookInput has correct class and fields", {
  h <- PreToolUseHookInput("s1", "/tmp/t", "/home", "Bash", list(command = "ls"), "tu1")
  expect_s3_class(h, "PreToolUseHookInput")
  expect_equal(h$hook_event_name, "PreToolUse")
  expect_equal(h$tool_name, "Bash")
  expect_equal(h$tool_use_id, "tu1")
  expect_null(h$agent_id)
})

test_that("PostToolUseHookInput has correct class and fields", {
  h <- PostToolUseHookInput("s1", "/tmp/t", "/home", "Bash",
                            list(command = "ls"), "output", "tu1")
  expect_s3_class(h, "PostToolUseHookInput")
  expect_equal(h$hook_event_name, "PostToolUse")
  expect_equal(h$tool_response, "output")
})

test_that("PostToolUseFailureHookInput has correct class and fields", {
  h <- PostToolUseFailureHookInput("s1", "/tmp/t", "/home", "Bash",
                                    list(command = "ls"), "tu1", "timeout")
  expect_s3_class(h, "PostToolUseFailureHookInput")
  expect_equal(h$hook_event_name, "PostToolUseFailure")
  expect_equal(h$error, "timeout")
  expect_null(h$is_interrupt)
})

test_that("UserPromptSubmitHookInput has correct class", {
  h <- UserPromptSubmitHookInput("s1", "/tmp/t", "/home", "hello")
  expect_s3_class(h, "UserPromptSubmitHookInput")
  expect_equal(h$prompt, "hello")
})

test_that("StopHookInput has correct class", {
  h <- StopHookInput("s1", "/tmp/t", "/home", TRUE)
  expect_s3_class(h, "StopHookInput")
  expect_true(h$stop_hook_active)
})

test_that("SubagentStopHookInput has correct class and fields", {
  h <- SubagentStopHookInput("s1", "/tmp/t", "/home", TRUE, "a1", "/tmp/a", "code")
  expect_s3_class(h, "SubagentStopHookInput")
  expect_equal(h$agent_id, "a1")
  expect_equal(h$agent_transcript_path, "/tmp/a")
})

test_that("PreCompactHookInput has correct class", {
  h <- PreCompactHookInput("s1", "/tmp/t", "/home", "auto", "keep this")
  expect_s3_class(h, "PreCompactHookInput")
  expect_equal(h$trigger, "auto")
  expect_equal(h$custom_instructions, "keep this")
})

test_that("NotificationHookInput has correct class", {
  h <- NotificationHookInput("s1", "/tmp/t", "/home", "hello", "info", title = "Test")
  expect_s3_class(h, "NotificationHookInput")
  expect_equal(h$notification_type, "info")
  expect_equal(h$title, "Test")
})

test_that("SubagentStartHookInput has correct class", {
  h <- SubagentStartHookInput("s1", "/tmp/t", "/home", "a1", "code")
  expect_s3_class(h, "SubagentStartHookInput")
  expect_equal(h$agent_id, "a1")
})

test_that("PermissionRequestHookInput has correct class", {
  h <- PermissionRequestHookInput("s1", "/tmp/t", "/home", "Bash", list(command = "rm"))
  expect_s3_class(h, "PermissionRequestHookInput")
  expect_equal(h$tool_name, "Bash")
  expect_null(h$permission_suggestions)
})

# ---------------------------------------------------------------------------
# Hook output types
# ---------------------------------------------------------------------------

test_that("SyncHookOutput has correct class and camelCase fields", {
  o <- SyncHookOutput(continue_ = TRUE, suppress_output = TRUE, reason = "ok")
  expect_s3_class(o, "SyncHookOutput")
  expect_true(o$continue_)
  expect_true(o$suppressOutput)
  expect_equal(o$reason, "ok")
})

test_that("AsyncHookOutput has correct class", {
  o <- AsyncHookOutput(async_timeout = 5000L)
  expect_s3_class(o, "AsyncHookOutput")
  expect_true(o$async_)
  expect_equal(o$asyncTimeout, 5000L)
})

# ---------------------------------------------------------------------------
# Permission update types
# ---------------------------------------------------------------------------

test_that("PermissionRuleValue has correct class", {
  r <- PermissionRuleValue("Bash", "allow all")
  expect_s3_class(r, "PermissionRuleValue")
  expect_equal(r$tool_name, "Bash")
  expect_equal(r$rule_content, "allow all")
})

test_that("PermissionUpdate has correct class and fields", {
  u <- PermissionUpdate("addRules",
    rules = list(PermissionRuleValue("Bash")),
    behavior = "allow",
    destination = "session"
  )
  expect_s3_class(u, "PermissionUpdate")
  expect_equal(u$type, "addRules")
  expect_equal(u$behavior, "allow")
  expect_s3_class(u$rules[[1]], "PermissionRuleValue")
})

# ---------------------------------------------------------------------------
# System prompt types
# ---------------------------------------------------------------------------

test_that("SystemPromptPreset has correct class", {
  p <- SystemPromptPreset(exclude_dynamic_sections = TRUE, append = "extra")
  expect_s3_class(p, "SystemPromptPreset")
  expect_equal(p$type, "preset")
  expect_true(p$exclude_dynamic_sections)
  expect_equal(p$append, "extra")
})

test_that("SystemPromptFile has correct class", {
  f <- SystemPromptFile("/tmp/prompt.txt")
  expect_s3_class(f, "SystemPromptFile")
  expect_equal(f$type, "file")
  expect_equal(f$path, "/tmp/prompt.txt")
})

# ---------------------------------------------------------------------------
# Sandbox types
# ---------------------------------------------------------------------------

test_that("SandboxNetworkConfig has correct class and camelCase fields", {
  n <- SandboxNetworkConfig(
    allow_unix_sockets     = c("/tmp/socket"),
    allow_all_unix_sockets = TRUE,
    http_proxy_port        = 8080L
  )
  expect_s3_class(n, "SandboxNetworkConfig")
  expect_equal(n$allowUnixSockets, c("/tmp/socket"))
  expect_true(n$allowAllUnixSockets)
  expect_equal(n$httpProxyPort, 8080L)
})

test_that("SandboxIgnoreViolations has correct class", {
  v <- SandboxIgnoreViolations(file = c("/tmp/ok"), network = c("localhost"))
  expect_s3_class(v, "SandboxIgnoreViolations")
  expect_equal(v$file, c("/tmp/ok"))
})

test_that("SandboxSettings has correct class and camelCase fields", {
  s <- SandboxSettings(enabled = TRUE, excluded_commands = c("rm"))
  expect_s3_class(s, "SandboxSettings")
  expect_true(s$enabled)
  expect_equal(s$excludedCommands, c("rm"))
})

# ---------------------------------------------------------------------------
# Thinking configuration types
# ---------------------------------------------------------------------------

test_that("ThinkingConfigAdaptive has correct class and type", {
  t <- ThinkingConfigAdaptive()
  expect_s3_class(t, "ThinkingConfigAdaptive")
  expect_equal(t$type, "adaptive")
})

test_that("ThinkingConfigEnabled has correct class and budget", {
  t <- ThinkingConfigEnabled(budget_tokens = 10000L)
  expect_s3_class(t, "ThinkingConfigEnabled")
  expect_equal(t$type, "enabled")
  expect_equal(t$budget_tokens, 10000L)
})

test_that("ThinkingConfigDisabled has correct class", {
  t <- ThinkingConfigDisabled()
  expect_s3_class(t, "ThinkingConfigDisabled")
  expect_equal(t$type, "disabled")
})

# ---------------------------------------------------------------------------
# Task budget / usage types
# ---------------------------------------------------------------------------

test_that("TaskBudget has correct class", {
  b <- TaskBudget(max_tokens = 50000L)
  expect_s3_class(b, "TaskBudget")
  expect_equal(b$max_tokens, 50000L)
})

test_that("TaskUsage has correct class", {
  u <- TaskUsage(total_tokens = 1000L, tool_uses = 5L)
  expect_s3_class(u, "TaskUsage")
  expect_equal(u$total_tokens, 1000L)
  expect_equal(u$tool_uses, 5L)
})

# ---------------------------------------------------------------------------
# Context usage types
# ---------------------------------------------------------------------------

test_that("ContextUsageCategory has correct class and camelCase field", {
  c <- ContextUsageCategory("system", 500L, "#ff0000", is_deferred = TRUE)
  expect_s3_class(c, "ContextUsageCategory")
  expect_equal(c$name, "system")
  expect_true(c$isDeferred)
})

test_that("ContextUsageResponse has correct class", {
  cat1 <- ContextUsageCategory("system", 500L, "#ff0000")
  r <- ContextUsageResponse(categories = list(cat1), total_tokens = 500L)
  expect_s3_class(r, "ContextUsageResponse")
  expect_equal(r$totalTokens, 500L)
  expect_length(r$categories, 1L)
})

# ---------------------------------------------------------------------------
# MCP status types
# ---------------------------------------------------------------------------

test_that("McpToolInfo has correct class", {
  t <- McpToolInfo("Read", description = "Read files")
  expect_s3_class(t, "McpToolInfo")
  expect_equal(t$name, "Read")
})

test_that("McpServerInfo has correct class", {
  i <- McpServerInfo("my-server", "1.0.0")
  expect_s3_class(i, "McpServerInfo")
  expect_equal(i$version, "1.0.0")
})

test_that("McpServerStatus has correct class and camelCase fields", {
  s <- McpServerStatus("srv", "connected",
    server_info = McpServerInfo("srv", "1.0"),
    tools = list(McpToolInfo("tool1")))
  expect_s3_class(s, "McpServerStatus")
  expect_equal(s$status, "connected")
  expect_s3_class(s$serverInfo, "McpServerInfo")
  expect_length(s$tools, 1L)
})

test_that("McpStatusResponse has correct class", {
  r <- McpStatusResponse(list(McpServerStatus("srv", "connected")))
  expect_s3_class(r, "McpStatusResponse")
  expect_length(r$mcpServers, 1L)
})

test_that("HookMatcher stores matcher, hooks, and timeout", {
  fn <- function(input, id, ctx) list()
  m  <- HookMatcher(matcher = "Bash", hooks = list(fn), timeout = 5000L)
  expect_s3_class(m, "HookMatcher")
  expect_equal(m$matcher, "Bash")
  expect_length(m$hooks, 1L)
  expect_equal(m$timeout, 5000L)
})

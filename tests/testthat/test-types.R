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

test_that("HookMatcher stores matcher, hooks, and timeout", {
  fn <- function(input, id, ctx) list()
  m  <- HookMatcher(matcher = "Bash", hooks = list(fn), timeout = 5000L)
  expect_s3_class(m, "HookMatcher")
  expect_equal(m$matcher, "Bash")
  expect_length(m$hooks, 1L)
  expect_equal(m$timeout, 5000L)
})

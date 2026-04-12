# Integration tests — require a real Claude Code CLI.
# All tests call skip_if_no_claude() to be skipped in environments without CLI.

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

skip_if_no_claude <- function() {
  tryCatch(find_claude(), error = function(e) skip("Claude Code CLI not found"))
}

skip_if_no_sessions <- function() {
  sessions <- tryCatch(list_sessions(), error = function(e) list())
  if (length(sessions) == 0L) skip("No Claude sessions found in ~/.claude/projects/")
  sessions
}

make_client <- function(...) {
  ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns       = 1L,
    permission_mode = "bypassPermissions",
    ...
  ))
}

# ---------------------------------------------------------------------------
# get_server_info — verifies init_result is captured during handshake
# ---------------------------------------------------------------------------

test_that("get_server_info returns non-NULL list after connect", {
  skip_if_no_claude()
  client <- make_client()
  client$connect()
  on.exit(client$disconnect())

  info <- client$get_server_info()
  expect_false(is.null(info))
  expect_true(is.list(info))
})

# ---------------------------------------------------------------------------
# set_permission_mode / interrupt — fire-and-forget control messages
# ---------------------------------------------------------------------------

test_that("set_permission_mode does not error", {
  skip_if_no_claude()
  client <- make_client()
  client$connect()
  on.exit(client$disconnect())
  expect_no_error(client$set_permission_mode("acceptEdits"))
})

test_that("interrupt does not error", {
  skip_if_no_claude()
  client <- make_client()
  client$connect()
  on.exit(client$disconnect())
  expect_no_error(client$interrupt())
})

# ---------------------------------------------------------------------------
# exclude_dynamic_sections — connect succeeds with preset system prompt
# ---------------------------------------------------------------------------

test_that("exclude_dynamic_sections passes through without error", {
  skip_if_no_claude()
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns       = 1L,
    permission_mode = "bypassPermissions",
    system_prompt   = list(type = "preset", exclude_dynamic_sections = TRUE)
  ))
  expect_no_error(client$connect())
  client$disconnect()
})

# ---------------------------------------------------------------------------
# agents in initialize — connect succeeds when agents are supplied
# ---------------------------------------------------------------------------

test_that("agents config (named list) passes through initialize without error", {
  skip_if_no_claude()
  ag <- AgentDefinition(
    description = "A test sub-agent",
    prompt      = "You are a helper.",
    tools       = character(0)
  )
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns       = 1L,
    permission_mode = "bypassPermissions",
    agents          = list(helper = ag)
  ))
  expect_no_error(client$connect())
  client$disconnect()
})

# ---------------------------------------------------------------------------
# include_partial_messages — AssistantMessage still present in result
# ---------------------------------------------------------------------------

test_that("include_partial_messages=TRUE still yields AssistantMessage", {
  skip_if_no_claude()
  result <- claude_run(
    "Say only: PARTIAL",
    options = ClaudeAgentOptions(
      max_turns               = 1L,
      permission_mode         = "bypassPermissions",
      include_partial_messages = TRUE
    )
  )
  expect_false(result$result$is_error)
  assistant_msgs <- Filter(function(m) inherits(m, "AssistantMessage"), result$messages)
  expect_true(length(assistant_msgs) >= 1L)
})

# ---------------------------------------------------------------------------
# get_context_usage / get_mcp_status — send_and_wait returns real data
# ---------------------------------------------------------------------------

test_that("get_context_usage returns non-NULL list", {
  skip_if_no_claude()
  client <- make_client()
  client$connect()
  on.exit(client$disconnect())

  cu <- client$get_context_usage()
  expect_false(is.null(cu))
  expect_true(is.list(cu))
  expect_true("totalTokens" %in% names(cu) || "categories" %in% names(cu))
})

test_that("get_mcp_status returns non-NULL list", {
  skip_if_no_claude()
  client <- make_client()
  client$connect()
  on.exit(client$disconnect())

  ms <- client$get_mcp_status()
  expect_false(is.null(ms))
  expect_true(is.list(ms))
})

# ---------------------------------------------------------------------------
# list_sessions / get_session_info / get_session_messages
# ---------------------------------------------------------------------------

test_that("list_sessions returns a list", {
  skip_if_no_claude()
  sessions <- list_sessions()
  expect_true(is.list(sessions))
})

test_that("list_sessions entries have expected fields", {
  skip_if_no_claude()
  sessions <- skip_if_no_sessions()
  first <- sessions[[1L]]
  expect_true("session_id" %in% names(first))
  expect_true("last_modified" %in% names(first))
  expect_true("summary" %in% names(first) || "first_prompt" %in% names(first))
  expect_true(nzchar(first$session_id))
})

test_that("list_sessions limit and offset work", {
  skip_if_no_claude()
  all_s <- skip_if_no_sessions()
  if (length(all_s) < 2L) skip("Need at least 2 sessions to test offset")

  one <- list_sessions(limit = 1L)
  expect_equal(length(one), 1L)

  offset1 <- list_sessions(limit = 1L, offset = 1L)
  expect_equal(length(offset1), 1L)
  expect_false(identical(one[[1L]]$session_id, offset1[[1L]]$session_id))
})

test_that("get_session_info returns info for an existing session", {
  skip_if_no_claude()
  sessions <- skip_if_no_sessions()
  sid  <- sessions[[1L]]$session_id
  info <- get_session_info(sid)

  expect_false(is.null(info))
  expect_equal(info$session_id, sid)
  expect_true("cwd" %in% names(info) || "last_modified" %in% names(info))
})

test_that("get_session_info returns NULL for unknown UUID", {
  skip_if_no_claude()
  result <- get_session_info("00000000-0000-4000-8000-000000000000")
  expect_null(result)
})

test_that("get_session_messages returns a list", {
  skip_if_no_claude()
  sessions <- skip_if_no_sessions()
  sid  <- sessions[[1L]]$session_id
  msgs <- get_session_messages(sid)

  expect_true(is.list(msgs))
})

test_that("get_session_messages entries have role field", {
  skip_if_no_claude()
  sessions <- skip_if_no_sessions()
  sid  <- sessions[[1L]]$session_id
  msgs <- get_session_messages(sid)
  if (length(msgs) == 0L) skip("Session has no visible messages")

  first <- msgs[[1L]]
  expect_true("type" %in% names(first))
  expect_true(first$type %in% c("user", "assistant"))
  expect_true("message" %in% names(first))
  expect_true("role" %in% names(first$message))
  expect_true(first$message$role %in% c("user", "assistant"))
})

test_that("get_session_messages limit works", {
  skip_if_no_claude()
  sessions <- skip_if_no_sessions()
  sid  <- sessions[[1L]]$session_id
  all_msgs <- get_session_messages(sid)
  if (length(all_msgs) < 2L) skip("Need at least 2 messages to test limit")

  limited <- get_session_messages(sid, limit = 1L)
  expect_equal(length(limited), 1L)
})

# ---------------------------------------------------------------------------
# set_model — runtime control
# ---------------------------------------------------------------------------

test_that("set_model does not error", {
  skip_if_no_claude()
  client <- make_client()
  client$connect()
  on.exit(client$disconnect())
  expect_no_error(client$set_model("claude-sonnet-4-6"))
})

# ---------------------------------------------------------------------------
# stderr callback — captures CLI debug output
# ---------------------------------------------------------------------------

test_that("stderr callback captures output", {
  skip_if_no_claude()
  captured <- character(0)
  result <- claude_run(
    "Say only: STDERR_TEST",
    options = ClaudeAgentOptions(
      max_turns       = 1L,
      permission_mode = "bypassPermissions",
      stderr          = function(line) { captured <<- c(captured, line) },
      extra_args      = list("debug-to-stderr" = NULL)
    )
  )
  expect_false(result$result$is_error)
  expect_true(length(captured) > 0L)
})

# ---------------------------------------------------------------------------
# Multi-turn ClaudeSDKClient — 2 sequential prompts
# ---------------------------------------------------------------------------

test_that("ClaudeSDKClient handles multi-turn conversation", {
  skip_if_no_claude()
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns       = 1L,
    permission_mode = "bypassPermissions"
  ))
  client$connect()
  on.exit(client$disconnect())

  # Turn 1
  client$send("Say only: TURN1")
  msgs1 <- list()
  coro::loop(for (msg in client$receive_response()) {
    msgs1 <- c(msgs1, list(msg))
  })
  result1 <- Filter(function(m) inherits(m, "ResultMessage"), msgs1)
  expect_true(length(result1) >= 1L)
  expect_false(result1[[1L]]$is_error)

  # Turn 2
  client$send("Say only: TURN2")
  msgs2 <- list()
  coro::loop(for (msg in client$receive_response()) {
    msgs2 <- c(msgs2, list(msg))
  })
  result2 <- Filter(function(m) inherits(m, "ResultMessage"), msgs2)
  expect_true(length(result2) >= 1L)
  expect_false(result2[[1L]]$is_error)
})

# ---------------------------------------------------------------------------
# can_use_tool permission callback
# ---------------------------------------------------------------------------

test_that("can_use_tool callback is invoked and can allow", {
  skip_if_no_claude()
  callback_invoked <- FALSE
  tool_names_seen  <- character(0)
  result <- claude_run(
    "Use the Read tool to read the file /dev/null",
    options = ClaudeAgentOptions(
      max_turns   = 2L,
      can_use_tool = function(tool_name, input, ctx) {
        callback_invoked <<- TRUE
        tool_names_seen  <<- c(tool_names_seen, tool_name)
        PermissionResultAllow()
      }
    )
  )
  # If Claude used any tool, callback should have been invoked
  # Skip if Claude answered without tool use (model may refuse)
  if (!callback_invoked) skip("Claude did not attempt any tool use")
  expect_true(length(tool_names_seen) >= 1L)
})

# ---------------------------------------------------------------------------
# Structured output / json schema
# ---------------------------------------------------------------------------

test_that("structured output with json_schema works", {
  skip_if_no_claude()
  schema <- list(
    type = "object",
    properties = list(
      answer = list(type = "string"),
      confidence = list(type = "number")
    ),
    required = list("answer"),
    additionalProperties = FALSE
  )
  result <- claude_run(
    "What is 1+1? Respond with JSON only.",
    options = ClaudeAgentOptions(
      max_turns       = 1L,
      permission_mode = "bypassPermissions",
      output_format   = list(type = "json_schema", schema = schema)
    )
  )
  # Structured output may fail depending on model support; skip if error
  if (isTRUE(result$result$is_error)) skip("Structured output not supported in this env")
  so <- result$result$structured_output
  if (!is.null(so)) {
    expect_true(is.list(so) || is.character(so))
  }
})

# ---------------------------------------------------------------------------
# include_partial_messages emits StreamEvent
# ---------------------------------------------------------------------------

test_that("include_partial_messages emits StreamEvent", {
  skip_if_no_claude()
  result <- claude_run(
    "Say only: STREAM_CHECK",
    options = ClaudeAgentOptions(
      max_turns               = 1L,
      permission_mode         = "bypassPermissions",
      include_partial_messages = TRUE
    )
  )
  stream_events <- Filter(function(m) inherits(m, "StreamEvent"), result$messages)
  # With include_partial_messages, we should see StreamEvent objects
  expect_true(length(stream_events) >= 1L)
})

# ---------------------------------------------------------------------------
# Agent with new fields in real connection
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# receive_response_async — promise-based async receive
# ---------------------------------------------------------------------------

test_that("receive_response_async resolves with ResultMessage", {
  skip_if_no_claude()
  skip_if(!requireNamespace("promises", quietly = TRUE), "promises package not installed")

  client <- make_client()
  client$connect()
  on.exit(client$disconnect())

  client$send("Say only: ASYNC_TEST")

  collected <- list()
  p <- client$receive_response_async(on_message = function(msg) {
    collected[[length(collected) + 1L]] <<- msg
  })

  result <- NULL
  error  <- NULL
  promises::then(p,
    onFulfilled = function(val) result <<- val,
    onRejected  = function(err) error  <<- err
  )

  # Drive the later event loop until the promise settles
  deadline <- Sys.time() + 120
  while (is.null(result) && is.null(error) && Sys.time() < deadline) {
    later::run_now(timeoutSecs = 0.1)
  }

  expect_null(error)
  expect_true(inherits(result, "ResultMessage"))
  expect_false(result$is_error)
  # on_message should have received at least one message before the result
  expect_true(length(collected) >= 1L)
})

test_that("receive_response_async on_message receives AssistantMessage", {
  skip_if_no_claude()
  skip_if(!requireNamespace("promises", quietly = TRUE), "promises package not installed")

  client <- make_client()
  client$connect()
  on.exit(client$disconnect())

  client$send("Say only: CALLBACK_CHECK")

  assistant_seen <- FALSE
  p <- client$receive_response_async(on_message = function(msg) {
    if (inherits(msg, "AssistantMessage")) assistant_seen <<- TRUE
  })

  result <- NULL
  promises::then(p,
    onFulfilled = function(val) result <<- val,
    onRejected  = function(err) result <<- err
  )

  deadline <- Sys.time() + 120
  while (is.null(result) && Sys.time() < deadline) {
    later::run_now(timeoutSecs = 0.1)
  }

  expect_true(assistant_seen)
})

# ---------------------------------------------------------------------------
# PermissionRequestMessage + approve_tool (message-driven API)
# ---------------------------------------------------------------------------

test_that("PermissionRequestMessage is yielded and approve_tool works", {
  skip_if_no_claude()
  skip_if(!requireNamespace("promises", quietly = TRUE), "promises package not installed")

  # No can_use_tool → message-driven path
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns                   = 2L,
    permission_prompt_tool_name = "stdio"
  ))
  client$connect()
  on.exit(client$disconnect())

  client$send("Use the Read tool to read the file /dev/null")

  perm_seen <- FALSE
  p <- client$receive_response_async(on_message = function(msg) {
    if (inherits(msg, "PermissionRequestMessage")) {
      perm_seen <<- TRUE
      # Approve via the message-driven API
      client$approve_tool(msg$request_id)
    }
  })

  result <- NULL
  error  <- NULL
  promises::then(p,
    onFulfilled = function(val) result <<- val,
    onRejected  = function(err) error  <<- err
  )

  deadline <- Sys.time() + 120
  while (is.null(result) && is.null(error) && Sys.time() < deadline) {
    later::run_now(timeoutSecs = 0.1)
  }

  if (!perm_seen) skip("Claude did not attempt any tool use")
  expect_null(error)
  expect_true(inherits(result, "ResultMessage"))
})

test_that("deny_tool works via message-driven API", {
  skip_if_no_claude()
  skip_if(!requireNamespace("promises", quietly = TRUE), "promises package not installed")

  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns                   = 2L,
    permission_prompt_tool_name = "stdio"
  ))
  client$connect()
  on.exit(client$disconnect())

  client$send("Use the Read tool to read the file /dev/null")

  denied <- FALSE
  p <- client$receive_response_async(on_message = function(msg) {
    if (inherits(msg, "PermissionRequestMessage")) {
      denied <<- TRUE
      client$deny_tool(msg$request_id, "Denied by test")
    }
  })

  result <- NULL
  promises::then(p,
    onFulfilled = function(val) result <<- val,
    onRejected  = function(err) result <<- err
  )

  deadline <- Sys.time() + 120
  while (is.null(result) && Sys.time() < deadline) {
    later::run_now(timeoutSecs = 0.1)
  }

  if (!denied) skip("Claude did not attempt any tool use")
  expect_true(inherits(result, "ResultMessage"))
})

# ---------------------------------------------------------------------------
# Agent with new fields in real connection
# ---------------------------------------------------------------------------

test_that("agent with full fields connects without error", {
  skip_if_no_claude()
  ag <- AgentDefinition(
    description      = "code reviewer",
    prompt           = "Review code carefully.",
    tools            = c("Read", "Grep"),
    disallowed_tools = c("Bash"),
    max_turns        = 3L,
    effort           = "high"
  )
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns       = 1L,
    permission_mode = "bypassPermissions",
    agents          = list(reviewer = ag)
  ))
  expect_no_error(client$connect())
  client$disconnect()
})

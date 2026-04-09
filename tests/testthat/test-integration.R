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

test_that("agents config passes through initialize without error", {
  skip_if_no_claude()
  ag <- AgentDefinition(
    description = "A test sub-agent",
    prompt      = "You are a helper.",
    tools       = character(0)
  )
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns       = 1L,
    permission_mode = "bypassPermissions",
    agents          = list(ag)
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

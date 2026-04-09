skip_if_no_claude <- function() {
  tryCatch(find_claude(), error = function(e) skip("Claude Code CLI not found"))
}

test_that("claude_run returns ClaudeRunResult structure", {
  skip_if_no_claude()
  result <- claude_run(
    "Say only the word: OK",
    options = ClaudeAgentOptions(
      max_turns        = 1L,
      permission_mode  = "bypassPermissions"
    )
  )
  expect_s3_class(result, "ClaudeRunResult")
  expect_true(is.list(result$messages))
  expect_true(length(result$messages) > 0L)
  expect_s3_class(result$result, "ResultMessage")
  expect_false(result$result$is_error)
  expect_true(result$result$num_turns >= 1L)
})

test_that("claude_query yields AssistantMessage and ResultMessage", {
  skip_if_no_claude()
  gen    <- claude_query(
    "Say only the word: PING",
    options = ClaudeAgentOptions(
      max_turns       = 1L,
      permission_mode = "bypassPermissions"
    )
  )
  types  <- character(0)
  coro::loop(for (msg in gen) {
    types <- c(types, class(msg)[[1]])
  })
  expect_true("AssistantMessage" %in% types)
  expect_true("ResultMessage" %in% types)
})

test_that("claude_run extra arg overrides option", {
  skip_if_no_claude()
  result <- claude_run(
    "Say only: YES",
    options   = ClaudeAgentOptions(permission_mode = "bypassPermissions"),
    max_turns = 1L
  )
  expect_s3_class(result$result, "ResultMessage")
  expect_false(result$result$is_error)
})

test_that("AssistantMessage content has TextBlock", {
  skip_if_no_claude()
  result <- claude_run(
    "Say only the word: HELLO",
    options = ClaudeAgentOptions(
      max_turns       = 1L,
      permission_mode = "bypassPermissions"
    )
  )
  assistant_msgs <- Filter(function(m) inherits(m, "AssistantMessage"), result$messages)
  expect_true(length(assistant_msgs) >= 1L)
  first <- assistant_msgs[[1]]
  text_blocks <- Filter(function(b) inherits(b, "TextBlock"), first$content)
  expect_true(length(text_blocks) >= 1L)
  expect_true(nzchar(text_blocks[[1]]$text))
})

test_that("ResultMessage has session_id and cost", {
  skip_if_no_claude()
  result <- claude_run(
    "Say: DONE",
    options = ClaudeAgentOptions(
      max_turns       = 1L,
      permission_mode = "bypassPermissions"
    )
  )
  r <- result$result
  expect_true(nzchar(r$session_id))
  expect_true(is.numeric(r$total_cost_usd) || is.null(r$total_cost_usd))
})

test_that("ClaudeSDKClient connect/send/receive/disconnect", {
  skip_if_no_claude()
  client <- ClaudeSDKClient$new(ClaudeAgentOptions(
    max_turns       = 1L,
    permission_mode = "bypassPermissions"
  ))
  client$connect()
  client$send("Say only: CLIENT_OK")
  messages <- list()
  coro::loop(for (msg in client$receive_response()) {
    messages <- c(messages, list(msg))
  })
  client$disconnect()
  types <- vapply(messages, function(m) class(m)[[1]], character(1))
  expect_true("ResultMessage" %in% types)
  result_msg <- Filter(function(m) inherits(m, "ResultMessage"), messages)[[1]]
  expect_false(result_msg$is_error)
})

test_that("claude_agent_options with system_prompt passes through", {
  skip_if_no_claude()
  result <- claude_run(
    "What are you?",
    options = ClaudeAgentOptions(
      system_prompt   = "You are a test bot. Always reply with: I_AM_BOT",
      max_turns       = 1L,
      permission_mode = "bypassPermissions"
    )
  )
  expect_false(result$result$is_error)
})

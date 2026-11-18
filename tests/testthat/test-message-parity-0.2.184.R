# Parity with Python claude-agent-sdk v0.2.126 / v0.2.137 / v0.2.140:
# ResultMessage$terminal_reason, origin on User/Result messages,
# ConversationResetMessage, and the structured ResultError condition.

parse <- function(x) ClaudeAgentSDK:::parse_message(as.character(jsonlite::toJSON(x, auto_unbox = TRUE)))

test_that("result messages carry terminal_reason and origin", {
  msg <- parse(list(type = "result", subtype = "success", duration_ms = 1, duration_api_ms = 1,
                    is_error = FALSE, num_turns = 1, session_id = "s",
                    terminal_reason = "aborted_tools",
                    origin = list(kind = "task-notification", subkind = "scheduled-trigger")))
  expect_identical(msg$terminal_reason, "aborted_tools")
  expect_identical(msg$origin$kind, "task-notification")
  plain <- parse(list(type = "result", subtype = "success", duration_ms = 1, duration_api_ms = 1,
                      is_error = FALSE, num_turns = 1, session_id = "s"))
  expect_null(plain$terminal_reason)
  expect_null(plain$origin)
})

test_that("user message origin is kept only when well formed", {
  msg <- parse(list(type = "user", message = list(content = "hi"),
                    origin = list(kind = "human")))
  expect_identical(msg$origin$kind, "human")
  bad <- parse(list(type = "user", message = list(content = "hi"), origin = list(kind = 3)))
  expect_null(bad$origin)
  none <- parse(list(type = "user", message = list(content = "hi"), origin = "human"))
  expect_null(none$origin)
})

test_that("conversation_reset frames become ConversationResetMessage", {
  msg <- parse(list(type = "conversation_reset", new_conversation_id = "c2",
                    uuid = "u1", session_id = "s1"))
  expect_s3_class(msg, "ConversationResetMessage")
  expect_identical(msg$new_conversation_id, "c2")
  expect_identical(msg$session_id, "s1")
  expect_error(parse(list(type = "conversation_reset", uuid = "u1", session_id = "s1")),
               "new_conversation_id")
})

test_that("result_error conditions carry the structured payload", {
  result <- ResultMessage(subtype = "error_during_execution", duration_ms = 1, duration_api_ms = 1,
                          is_error = TRUE, num_turns = 1, session_id = "s",
                          errors = list("boom"), api_error_status = 529L, result = "failed",
                          terminal_reason = "aborted_streaming")
  cond <- result_error(result)
  expect_s3_class(cond, "claude_result_error")
  expect_s3_class(cond, "claude_process_error")
  expect_identical(cond$subtype, "error_during_execution")
  expect_identical(cond$api_error_status, 529L)
  expect_identical(cond$terminal_reason, "aborted_streaming")
  expect_match(conditionMessage(cond), "error_during_execution")
  expect_match(conditionMessage(cond), "boom")
})

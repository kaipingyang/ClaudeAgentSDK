test_that("claude_error base class works", {
  err <- tryCatch(claude_error("test msg", class = "my_class"), error = identity)
  expect_true(inherits(err, "my_class"))
  expect_true(inherits(err, "claude_error"))
})

test_that("claude_cli_not_found has correct class hierarchy", {
  err <- tryCatch(claude_cli_not_found(), error = identity)
  expect_true(inherits(err, "claude_error_cli_not_found"))
  expect_true(inherits(err, "claude_error_cli_connection"))
  expect_true(inherits(err, "claude_error"))
})

test_that("claude_cli_not_found appends path to message", {
  err <- tryCatch(claude_cli_not_found("/bad/path"), error = identity)
  expect_match(conditionMessage(err), "/bad/path")
})

test_that("claude_cli_connection_error has correct class", {
  err <- tryCatch(claude_cli_connection_error("conn failed"), error = identity)
  expect_true(inherits(err, "claude_error_cli_connection"))
  expect_true(inherits(err, "claude_error"))
})

test_that("claude_process_error includes exit code in message", {
  err <- tryCatch(claude_process_error("failed", exit_code = 1L), error = identity)
  expect_match(conditionMessage(err), "exit code: 1")
  expect_equal(err$exit_code, 1L)
})

test_that("claude_process_error includes stderr in message", {
  err <- tryCatch(claude_process_error("failed", stderr = "some error"), error = identity)
  expect_match(conditionMessage(err), "some error")
})

test_that("claude_json_decode_error stores the line", {
  err <- tryCatch(claude_json_decode_error("not-json"), error = identity)
  expect_equal(err$line, "not-json")
  expect_match(conditionMessage(err), "Failed to decode JSON")
})

test_that("claude_message_parse_error stores data", {
  err <- tryCatch(claude_message_parse_error("oops", data = list(x = 1)), error = identity)
  expect_equal(err$data, list(x = 1))
})

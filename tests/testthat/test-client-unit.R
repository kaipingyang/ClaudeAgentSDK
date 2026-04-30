# Unit tests for ClaudeSDKClient — no CLI needed

test_that("disconnect without connect does not error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_no_error(client$disconnect())
})

test_that("get_server_info returns NULL before connect", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_null(client$get_server_info())
})

test_that("send before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$send("hello"), "connect")
})

test_that("interrupt before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$interrupt(), "connect")
})

test_that("set_permission_mode before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$set_permission_mode("plan"), "connect")
})

test_that("set_model before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$set_model("claude-haiku-4-5-20251001"), "connect")
})

test_that("options stored on client", {
  opts <- ClaudeAgentOptions(model = "claude-opus-4-6", max_turns = 3L)
  client <- ClaudeSDKClient$new(opts)
  expect_equal(client$options$model, "claude-opus-4-6")
  expect_equal(client$options$max_turns, 3L)
})

test_that("query before connect raises error (alias for send)", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$query("hello"), "connect")
})

test_that("can_use_tool conflicts with permission_prompt_tool_name", {
  opts <- ClaudeAgentOptions(
    can_use_tool = function(tool, input, ctx) PermissionResultAllow(),
    permission_prompt_tool_name = "custom"
  )
  client <- ClaudeSDKClient$new(opts)
  expect_error(client$connect(), "can_use_tool.*permission_prompt_tool_name")
})

test_that("receive_response_async before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$receive_response_async(), "connect")
})

test_that("approve_tool before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$approve_tool("req_1"), "connect")
})

test_that("deny_tool before connect raises error", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$deny_tool("req_1"), "connect")
})

test_that("session_id active binding returns empty string before any run", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_equal(client$session_id, "")
})

test_that("session_id active binding is read-only", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$session_id <- "abc123", "read-only")
})

test_that("resume() errors when no session_id captured yet", {
  client <- ClaudeSDKClient$new(ClaudeAgentOptions())
  expect_error(client$resume(), "No session_id captured yet")
})

test_that("PermissionRequestMessage constructor works", {
  msg <- PermissionRequestMessage(
    request_id = "req_1", tool_name = "Read",
    tool_input = list(path = "/tmp")
  )
  expect_true(inherits(msg, "PermissionRequestMessage"))
  expect_equal(msg$request_id, "req_1")
  expect_equal(msg$tool_name, "Read")
  expect_equal(msg$tool_input, list(path = "/tmp"))
  expect_null(msg$tool_use_id)
})

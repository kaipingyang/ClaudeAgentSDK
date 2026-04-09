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

test_that("can_use_tool conflicts with permission_prompt_tool_name", {
  opts <- ClaudeAgentOptions(
    can_use_tool = function(tool, input, ctx) PermissionResultAllow(),
    permission_prompt_tool_name = "custom"
  )
  client <- ClaudeSDKClient$new(opts)
  expect_error(client$connect(), "can_use_tool.*permission_prompt_tool_name")
})

test_that("claude_agent_options returns ClaudeAgentOptions class", {
  opts <- ClaudeAgentOptions()
  expect_s3_class(opts, "ClaudeAgentOptions")
})

test_that("defaults are correct", {
  opts <- ClaudeAgentOptions()
  expect_equal(opts$allowed_tools,            character())
  expect_equal(opts$disallowed_tools,         character())
  expect_equal(opts$betas,                    character())
  expect_equal(opts$mcp_servers,              list())
  expect_equal(opts$plugins,                  list())
  expect_false(opts$continue_conversation)
  expect_false(opts$include_partial_messages)
  expect_false(opts$fork_session)
  expect_false(opts$enable_file_checkpointing)
  expect_null(opts$model)
  expect_null(opts$max_turns)
  expect_null(opts$permission_mode)
  expect_null(opts$system_prompt)
  expect_null(opts$cwd)
})

test_that("arguments are stored correctly", {
  opts <- ClaudeAgentOptions(
    model         = "claude-opus-4-6",
    max_turns     = 5L,
    permission_mode = "bypassPermissions",
    allowed_tools = c("Bash", "Read"),
    env           = list(FOO = "bar")
  )
  expect_equal(opts$model, "claude-opus-4-6")
  expect_equal(opts$max_turns, 5L)
  expect_equal(opts$permission_mode, "bypassPermissions")
  expect_equal(opts$allowed_tools, c("Bash", "Read"))
  expect_equal(opts$env$FOO, "bar")
})

test_that("print method runs without error", {
  expect_output(print(ClaudeAgentOptions(model = "x")), "ClaudeAgentOptions")
})

test_that("thinking config can be set", {
  opts <- ClaudeAgentOptions(
    thinking = list(type = "enabled", budget_tokens = 1024L)
  )
  expect_equal(opts$thinking$type, "enabled")
  expect_equal(opts$thinking$budget_tokens, 1024L)
})

test_that("task_budget can be set", {
  opts <- ClaudeAgentOptions(task_budget = list(total = 50000L))
  expect_equal(opts$task_budget$total, 50000L)
})

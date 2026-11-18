# Parity with Python claude-agent-sdk v0.2.137 / v0.2.140 / v0.2.153 / v0.2.158 / v0.2.177:
# verbatim_prompts, SystemPromptPreset(snapshot=), forward_subagent_text,
# resume_session_at / resume_drops_turn and HookMatcher(on_failure=).

build_args <- function(opts) {
  t <- ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
  t$.__enclos_env__$private$build_command()
}
init_body <- function(opts) {
  t <- ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
  t$.__enclos_env__$private$build_initialize_body()
}

test_that("verbatim_prompts marks outgoing user messages as client composed", {
  plain <- jsonlite::fromJSON(ClaudeAgentSDK:::build_user_message_json("@file /cmd"))
  expect_null(plain$client_composed)
  verbatim <- jsonlite::fromJSON(ClaudeAgentSDK:::build_user_message_json(
    "@file /cmd", verbatim_prompts = TRUE))
  expect_true(verbatim$client_composed)
  expect_identical(verbatim$message$content, "@file /cmd")
  expect_false(ClaudeAgentOptions()$verbatim_prompts)
  expect_true(ClaudeAgentOptions(verbatim_prompts = TRUE)$verbatim_prompts)
})

test_that("snapshot and forward_subagent_text reach the initialize request", {
  body <- init_body(ClaudeAgentOptions(
    system_prompt = SystemPromptPreset(append = "x", snapshot = TRUE),
    forward_subagent_text = TRUE))
  expect_true(body$systemPromptSnapshot)
  expect_true(body$forwardSubagentText)
  default <- init_body(ClaudeAgentOptions())
  expect_null(default$systemPromptSnapshot)
  expect_null(default$forwardSubagentText)
  expect_null(SystemPromptPreset(append = "x")$snapshot)
})

test_that("resume_session_at and resume_drops_turn are single argv tokens", {
  args <- build_args(ClaudeAgentOptions(resume = "s1", resume_session_at = "uuid-7",
                                        resume_drops_turn = "turn-3"))
  expect_true("--resume-session-at=uuid-7" %in% args)
  expect_true("--resume-drops-turn=turn-3" %in% args)
  expect_false(any(grepl("^--resume-session-at$|^--resume-drops-turn$", args)))
})

test_that("HookMatcher on_failure is validated and sent as onFailure", {
  cb <- function(input, tool_use_id, context) list()
  expect_error(HookMatcher(hooks = list(cb), on_failure = "explode"), "on_failure")
  body <- init_body(ClaudeAgentOptions(hooks = list(
    PreToolUse = list(HookMatcher(matcher = "Bash", hooks = list(cb), on_failure = "block")))))
  expect_identical(body$hooks$PreToolUse[[1]]$onFailure, "block")
  plain <- init_body(ClaudeAgentOptions(hooks = list(
    PreToolUse = list(HookMatcher(matcher = "Bash", hooks = list(cb))))))
  expect_null(plain$hooks$PreToolUse[[1]]$onFailure)
})

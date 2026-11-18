# Review follow-ups for the v0.2.184 parity port.

new_transport <- function(opts) ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
priv <- function(t) t$.__enclos_env__$private

test_that("an explicitly empty resume_drops_turn is still sent", {
  args <- priv(new_transport(ClaudeAgentOptions(resume = "s", resume_session_at = "u",
                                                resume_drops_turn = "")))$build_command()
  expect_true("--resume-drops-turn=" %in% args)
})

test_that("hook callback failures become control errors (so onFailure can block)", {
  t <- new_transport(ClaudeAgentOptions(hooks = list(PreToolUse = list(
    HookMatcher(matcher = "Bash", on_failure = "block",
                hooks = list(function(input, tool_use_id, context) stop("boom"),
                             function(input, tool_use_id, context) NULL))))))
  body <- priv(t)$build_initialize_body()
  ids <- body$hooks$PreToolUse[[1]]$hookCallbackIds
  expect_error(priv(t)$handle_hook(list(callback_id = ids[[1]])), "boom")
  expect_error(priv(t)$handle_hook(list(callback_id = ids[[2]])), "NULL")
  expect_error(priv(t)$handle_hook(list(callback_id = "hook_missing")), "No hook callback")
  ok <- new_transport(ClaudeAgentOptions(hooks = list(PreToolUse = list(
    HookMatcher(hooks = list(function(input, tool_use_id, context) list(continue_ = TRUE)))))))
  okid <- priv(ok)$build_initialize_body()$hooks$PreToolUse[[1]]$hookCallbackIds[[1]]
  expect_identical(priv(ok)$handle_hook(list(callback_id = okid)), list(`continue` = TRUE))
})

test_that("blocking hooks require a CLI that honours and applied them", {
  blocking <- new_transport(ClaudeAgentOptions(hooks = list(PreToolUse = list(
    HookMatcher(hooks = list(function(...) list()), on_failure = "block")))))
  expect_match(priv(blocking)$blocking_hooks_problem(list()), "does not honor on_failure")
  expect_match(priv(blocking)$blocking_hooks_problem(
    list(hook_on_failure_supported = TRUE, hooks_applied = FALSE)), "already running")
  expect_null(priv(blocking)$blocking_hooks_problem(list(hook_on_failure_supported = TRUE)))
  plain <- new_transport(ClaudeAgentOptions(hooks = list(PreToolUse = list(
    HookMatcher(hooks = list(function(...) list()))))))
  expect_null(priv(plain)$blocking_hooks_problem(list()))
})

test_that("can_use_tool warnings follow Python's whole-tool rules", {
  cb <- function(...) NULL
  build <- function(...) priv(new_transport(ClaudeAgentOptions(can_use_tool = cb, ...)))$build_command()
  expect_no_warning(build(allowed_tools = "Bash(ls:*)"))
  expect_no_warning(build(allowed_tools = c("", "  ")))
  expect_warning(build(allowed_tools = c("Read", "Read(*)", "Write()")), "Read, Write")
  expect_warning(build(skills = "all"), "Skill")
  expect_no_warning(build(skills = "pdf"))
})

test_that("Unicode surrounding whitespace in skill names is rejected", {
  for (name in c("\u00a0pdf", "pdf\u2028", "\u3000pdf")) {
    expect_error(priv(new_transport(ClaudeAgentOptions(skills = name)))$build_command(),
                 "whitespace", info = name)
  }
})

test_that("result_error normalises errors and keeps process fields", {
  result <- ResultMessage(subtype = "error_max_turns", duration_ms = 1, duration_api_ms = 1,
                          is_error = TRUE, num_turns = 1, session_id = "s",
                          errors = list("", 42, " boom "))
  cond <- result_error(result, exit_code = 1L, stderr = "trace")
  expect_identical(cond$errors, list("boom"))
  expect_match(conditionMessage(cond), "error_max_turns): boom", fixed = TRUE)
  expect_identical(cond$exit_code, 1L)
  expect_identical(cond$stderr, "trace")
  single <- result_error(ResultMessage(subtype = "x", duration_ms = 1, duration_api_ms = 1,
                                       is_error = TRUE, num_turns = 1, session_id = "s",
                                       errors = "solo"))
  expect_identical(single$errors, list("solo"))
})

test_that("verbatim_prompts raises the minimum CLI version for the advisory check", {
  expect_identical(priv(new_transport(ClaudeAgentOptions(verbatim_prompts = TRUE)))$minimum_cli_version(),
                   "2.1.248")
  expect_identical(priv(new_transport(ClaudeAgentOptions()))$minimum_cli_version(),
                   ClaudeAgentSDK:::MINIMUM_CLAUDE_CODE_VERSION)
})

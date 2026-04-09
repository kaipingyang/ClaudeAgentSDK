# Tests for SubprocessCLITransport$private$build_command()
#
# These are pure unit tests of the CLI argument builder. They do NOT require the
# claude binary to be installed; we simply instantiate the R6 class and invoke
# the private method via the enclosure environment.

# ---------------------------------------------------------------------------
# Helper: build args from an options object
# ---------------------------------------------------------------------------
build_args <- function(opts) {
  t <- ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
  t$.__enclos_env__$private$build_command()
}

# Helper: get the value that follows a flag in an args vector
flag_value <- function(args, flag) {
  idx <- which(args == flag)
  if (length(idx) == 0L) return(NULL)
  # Return the value immediately after the LAST occurrence of the flag
  args[idx[length(idx)] + 1L]
}

# Helper: collect ALL values that follow repeated flags (e.g., --add-dir)
flag_values <- function(args, flag) {
  idx <- which(args == flag)
  if (length(idx) == 0L) return(character(0))
  args[idx + 1L]
}

# ===========================================================================
# 1. Basic / always-present arguments
# ===========================================================================
test_that("basic args always include output-format, verbose, input-format", {
  args <- build_args(ClaudeAgentOptions())
  expect_true("--output-format"  %in% args)
  expect_true("--verbose"        %in% args)

  expect_equal(flag_value(args, "--output-format"), "stream-json")
  expect_equal(flag_value(args, "--input-format"),  "stream-json")

  # --input-format should be the last pair
  n <- length(args)
  expect_equal(args[n - 1L], "--input-format")
  expect_equal(args[n],      "stream-json")
})

# ===========================================================================
# 2-5. system_prompt variants
# ===========================================================================
test_that("system_prompt string is passed with --system-prompt", {

  args <- build_args(ClaudeAgentOptions(system_prompt = "You are a bot"))
  expect_true("--system-prompt" %in% args)
  expect_equal(flag_value(args, "--system-prompt"), "You are a bot")
})

test_that("system_prompt = NULL passes --system-prompt with empty string", {
  args <- build_args(ClaudeAgentOptions(system_prompt = NULL))
  expect_true("--system-prompt" %in% args)
  expect_equal(flag_value(args, "--system-prompt"), "")
})

test_that("system_prompt file type passes --system-prompt-file", {
  sp <- list(type = "file", path = "/tmp/sp.txt")
  args <- build_args(ClaudeAgentOptions(system_prompt = sp))
  expect_true("--system-prompt-file" %in% args)
  expect_equal(flag_value(args, "--system-prompt-file"), "/tmp/sp.txt")
  # Should NOT have --system-prompt
  expect_false("--system-prompt" %in% args)
})

test_that("system_prompt preset with append passes --append-system-prompt", {
  sp <- list(type = "preset", append = "extra")
  args <- build_args(ClaudeAgentOptions(system_prompt = sp))
  expect_true("--append-system-prompt" %in% args)
  expect_equal(flag_value(args, "--append-system-prompt"), "extra")
  expect_false("--system-prompt" %in% args)
})

# ===========================================================================
# 6-8. tools variants
# ===========================================================================
test_that("tools character vector is comma-joined", {
  args <- build_args(ClaudeAgentOptions(tools = c("Read", "Write")))
  expect_true("--tools" %in% args)
  expect_equal(flag_value(args, "--tools"), "Read,Write")
})

test_that("tools = character(0) passes --tools with empty string", {
  args <- build_args(ClaudeAgentOptions(tools = character(0)))
  expect_true("--tools" %in% args)
  expect_equal(flag_value(args, "--tools"), "")
})

test_that("tools = NULL omits --tools flag entirely", {
  args <- build_args(ClaudeAgentOptions(tools = NULL))
  expect_false("--tools" %in% args)
})

test_that("tools as list passes --tools default", {
  args <- build_args(ClaudeAgentOptions(tools = list(type = "preset")))
  expect_true("--tools" %in% args)
  expect_equal(flag_value(args, "--tools"), "default")
})

# ===========================================================================
# 9-10. allowed_tools / disallowed_tools
# ===========================================================================
test_that("allowed_tools produces --allowedTools", {
  args <- build_args(ClaudeAgentOptions(allowed_tools = c("Read")))
  expect_true("--allowedTools" %in% args)
  expect_equal(flag_value(args, "--allowedTools"), "Read")
})

test_that("allowed_tools with multiple values are comma-joined", {
  args <- build_args(ClaudeAgentOptions(allowed_tools = c("Read", "Write")))
  expect_equal(flag_value(args, "--allowedTools"), "Read,Write")
})

test_that("allowed_tools = character(0) omits --allowedTools", {
  args <- build_args(ClaudeAgentOptions(allowed_tools = character(0)))
  expect_false("--allowedTools" %in% args)
})

test_that("disallowed_tools produces --disallowedTools", {
  args <- build_args(ClaudeAgentOptions(disallowed_tools = c("Bash")))
  expect_true("--disallowedTools" %in% args)
  expect_equal(flag_value(args, "--disallowedTools"), "Bash")
})

# ===========================================================================
# 11-12. max_turns / max_budget_usd
# ===========================================================================
test_that("max_turns produces --max-turns with string value", {
  args <- build_args(ClaudeAgentOptions(max_turns = 5L))
  expect_true("--max-turns" %in% args)
  expect_equal(flag_value(args, "--max-turns"), "5")
})

test_that("max_turns = NULL omits --max-turns", {
  args <- build_args(ClaudeAgentOptions(max_turns = NULL))
  expect_false("--max-turns" %in% args)
})

test_that("max_budget_usd produces --max-budget-usd", {
  args <- build_args(ClaudeAgentOptions(max_budget_usd = 1.5))
  expect_true("--max-budget-usd" %in% args)
  expect_equal(flag_value(args, "--max-budget-usd"), "1.5")
})

# ===========================================================================
# 13-14. model / fallback_model
# ===========================================================================
test_that("model produces --model", {
  args <- build_args(ClaudeAgentOptions(model = "claude-sonnet-4-6"))
  expect_true("--model" %in% args)
  expect_equal(flag_value(args, "--model"), "claude-sonnet-4-6")
})

test_that("fallback_model produces --fallback-model", {
  args <- build_args(ClaudeAgentOptions(fallback_model = "claude-haiku-4-5-20251001"))
  expect_true("--fallback-model" %in% args)
  expect_equal(flag_value(args, "--fallback-model"), "claude-haiku-4-5-20251001")
})

# ===========================================================================
# 15. betas
# ===========================================================================
test_that("betas are comma-joined and passed with --betas", {
  args <- build_args(ClaudeAgentOptions(betas = c("beta1", "beta2")))
  expect_true("--betas" %in% args)
  expect_equal(flag_value(args, "--betas"), "beta1,beta2")
})

test_that("betas = character(0) omits --betas", {
  args <- build_args(ClaudeAgentOptions(betas = character(0)))
  expect_false("--betas" %in% args)
})

# ===========================================================================
# 16. permission_mode
# ===========================================================================
test_that("permission_mode produces --permission-mode", {
  args <- build_args(ClaudeAgentOptions(permission_mode = "bypassPermissions"))
  expect_true("--permission-mode" %in% args)
  expect_equal(flag_value(args, "--permission-mode"), "bypassPermissions")
})

# ===========================================================================
# 17. continue_conversation
# ===========================================================================
test_that("continue_conversation = TRUE produces --continue (no value)", {
  args <- build_args(ClaudeAgentOptions(continue_conversation = TRUE))
  expect_true("--continue" %in% args)
})

test_that("continue_conversation = FALSE omits --continue", {
  args <- build_args(ClaudeAgentOptions(continue_conversation = FALSE))
  expect_false("--continue" %in% args)
})

# ===========================================================================
# 18. resume
# ===========================================================================
test_that("resume produces --resume with session id", {
  args <- build_args(ClaudeAgentOptions(resume = "abc-123"))
  expect_true("--resume" %in% args)
  expect_equal(flag_value(args, "--resume"), "abc-123")
})

# ===========================================================================
# 19. session_id
# ===========================================================================
test_that("session_id produces --session-id", {
  args <- build_args(ClaudeAgentOptions(session_id = "sid-1"))
  expect_true("--session-id" %in% args)
  expect_equal(flag_value(args, "--session-id"), "sid-1")
})

# ===========================================================================
# 20-23. thinking variants and max_thinking_tokens
# ===========================================================================
test_that("thinking adaptive produces --thinking adaptive", {
  args <- build_args(ClaudeAgentOptions(thinking = list(type = "adaptive")))
  expect_true("--thinking" %in% args)
  expect_equal(flag_value(args, "--thinking"), "adaptive")
})

test_that("thinking enabled produces --max-thinking-tokens", {
  args <- build_args(ClaudeAgentOptions(
    thinking = list(type = "enabled", budget_tokens = 10000)
  ))
  expect_true("--max-thinking-tokens" %in% args)
  expect_equal(flag_value(args, "--max-thinking-tokens"), "10000")
  # Should NOT emit --thinking flag
  expect_false("--thinking" %in% args)
})

test_that("thinking disabled produces --thinking disabled", {
  args <- build_args(ClaudeAgentOptions(thinking = list(type = "disabled")))
  expect_true("--thinking" %in% args)
  expect_equal(flag_value(args, "--thinking"), "disabled")
})

test_that("max_thinking_tokens without thinking param produces --max-thinking-tokens", {
  args <- build_args(ClaudeAgentOptions(max_thinking_tokens = 5000))
  expect_true("--max-thinking-tokens" %in% args)
  expect_equal(flag_value(args, "--max-thinking-tokens"), "5000")
})

test_that("thinking param takes precedence over max_thinking_tokens", {
  args <- build_args(ClaudeAgentOptions(
    thinking = list(type = "adaptive"),
    max_thinking_tokens = 5000
  ))
  # thinking wins: --thinking adaptive, NOT --max-thinking-tokens
  expect_true("--thinking" %in% args)
  expect_equal(flag_value(args, "--thinking"), "adaptive")
  expect_false("--max-thinking-tokens" %in% args)
})

# ===========================================================================
# 24. effort
# ===========================================================================
test_that("effort produces --effort", {
  args <- build_args(ClaudeAgentOptions(effort = "high"))
  expect_true("--effort" %in% args)
  expect_equal(flag_value(args, "--effort"), "high")
})

# ===========================================================================
# 25. add_dirs
# ===========================================================================
test_that("add_dirs produces repeated --add-dir flags", {
  args <- build_args(ClaudeAgentOptions(add_dirs = list("/tmp/a", "/tmp/b")))
  dirs <- flag_values(args, "--add-dir")
  expect_equal(dirs, c("/tmp/a", "/tmp/b"))
})

test_that("add_dirs = list() omits --add-dir", {
  args <- build_args(ClaudeAgentOptions(add_dirs = list()))
  expect_false("--add-dir" %in% args)
})

# ===========================================================================
# 26. include_partial_messages
# ===========================================================================
test_that("include_partial_messages = TRUE produces --include-partial-messages", {
  args <- build_args(ClaudeAgentOptions(include_partial_messages = TRUE))
  expect_true("--include-partial-messages" %in% args)
})

test_that("include_partial_messages = FALSE omits the flag", {
  args <- build_args(ClaudeAgentOptions(include_partial_messages = FALSE))
  expect_false("--include-partial-messages" %in% args)
})

# ===========================================================================
# 27. fork_session
# ===========================================================================
test_that("fork_session = TRUE produces --fork-session", {
  args <- build_args(ClaudeAgentOptions(fork_session = TRUE))
  expect_true("--fork-session" %in% args)
})

test_that("fork_session = FALSE omits --fork-session", {
  args <- build_args(ClaudeAgentOptions(fork_session = FALSE))
  expect_false("--fork-session" %in% args)
})

# ===========================================================================
# 28. setting_sources
# ===========================================================================
test_that("setting_sources are comma-joined with --setting-sources", {
  args <- build_args(ClaudeAgentOptions(setting_sources = c("user", "project")))
  expect_true("--setting-sources" %in% args)
  expect_equal(flag_value(args, "--setting-sources"), "user,project")
})

test_that("setting_sources = NULL omits --setting-sources", {
  args <- build_args(ClaudeAgentOptions(setting_sources = NULL))
  expect_false("--setting-sources" %in% args)
})

# ===========================================================================
# 29. output_format / json_schema
# ===========================================================================
test_that("output_format json_schema produces --json-schema with JSON", {
  schema <- list(type = "object", properties = list(name = list(type = "string")))
  args <- build_args(ClaudeAgentOptions(
    output_format = list(type = "json_schema", schema = schema)
  ))
  expect_true("--json-schema" %in% args)
  json_val <- flag_value(args, "--json-schema")
  parsed <- jsonlite::fromJSON(json_val, simplifyVector = FALSE)
  expect_equal(parsed$type, "object")
  expect_equal(parsed$properties$name$type, "string")
})

test_that("output_format = NULL omits --json-schema", {
  args <- build_args(ClaudeAgentOptions(output_format = NULL))
  expect_false("--json-schema" %in% args)
})

# ===========================================================================
# 30. task_budget
# ===========================================================================
test_that("task_budget produces --task-budget with total value", {
  args <- build_args(ClaudeAgentOptions(task_budget = list(total = 10)))
  expect_true("--task-budget" %in% args)
  expect_equal(flag_value(args, "--task-budget"), "10")
})

test_that("task_budget = NULL omits --task-budget", {
  args <- build_args(ClaudeAgentOptions(task_budget = NULL))
  expect_false("--task-budget" %in% args)
})

# ===========================================================================
# 31. agents are NOT in command args
# ===========================================================================
test_that("agents option does not produce any agent-related CLI flag", {
  agent_def <- list(
    helper = list(
      model = "claude-sonnet-4-6",
      system_prompt = "You help."
    )
  )
  args <- build_args(ClaudeAgentOptions(agents = agent_def))
  # No flag should contain "agent"
  agent_flags <- args[grepl("agent", args, ignore.case = TRUE)]
  expect_length(agent_flags, 0L)
})

# ===========================================================================
# 32-33. extra_args
# ===========================================================================
test_that("extra_args boolean flag (NULL value) produces bare flag", {
  args <- build_args(ClaudeAgentOptions(
    extra_args = list("debug-to-stderr" = NULL)
  ))
  expect_true("--debug-to-stderr" %in% args)
  # The flag should NOT be followed by a value that belongs to it.
  idx <- which(args == "--debug-to-stderr")
  # Either it is the last arg before --input-format, or the next arg is another flag
  next_arg <- args[idx + 1L]
  # Next arg should be a flag (starts with --) or be "stream-json" if it
  # happens to come right before --input-format
  expect_true(grepl("^--", next_arg) || next_arg == "stream-json")
})

test_that("extra_args with value produces flag and value pair", {
  args <- build_args(ClaudeAgentOptions(
    extra_args = list("custom-flag" = "val")
  ))
  expect_true("--custom-flag" %in% args)
  expect_equal(flag_value(args, "--custom-flag"), "val")
})

test_that("extra_args with -- prefix are not double-prefixed", {
  args <- build_args(ClaudeAgentOptions(
    extra_args = list("--already-prefixed" = "x")
  ))
  expect_true("--already-prefixed" %in% args)
  expect_false("----already-prefixed" %in% args)
  expect_equal(flag_value(args, "--already-prefixed"), "x")
})

# ===========================================================================
# Combined: multiple options together
# ===========================================================================
test_that("multiple options combine correctly", {
  args <- build_args(ClaudeAgentOptions(
    system_prompt   = "Be helpful",
    model           = "claude-sonnet-4-6",
    max_turns       = 10L,
    permission_mode = "bypassPermissions",
    tools           = c("Read", "Bash"),
    effort          = "high",
    add_dirs        = list("/d1", "/d2"),
    thinking        = list(type = "adaptive")
  ))

  expect_equal(flag_value(args, "--system-prompt"),   "Be helpful")
  expect_equal(flag_value(args, "--model"),            "claude-sonnet-4-6")
  expect_equal(flag_value(args, "--max-turns"),        "10")
  expect_equal(flag_value(args, "--permission-mode"),  "bypassPermissions")
  expect_equal(flag_value(args, "--tools"),            "Read,Bash")
  expect_equal(flag_value(args, "--effort"),           "high")
  expect_equal(flag_values(args, "--add-dir"),         c("/d1", "/d2"))
  expect_equal(flag_value(args, "--thinking"),         "adaptive")

  # input-format is still last
  n <- length(args)
  expect_equal(args[n - 1L], "--input-format")
  expect_equal(args[n],      "stream-json")
})

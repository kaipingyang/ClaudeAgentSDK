# Parity with Python claude-agent-sdk v0.2.121 / v0.2.124 / v0.2.129 / v0.2.111
# (argv injection hardening, skill-name validation, can_use_tool shadow warning).

build_args <- function(opts) {
  t <- ClaudeAgentSDK:::SubprocessCLITransport$new(opts)
  t$.__enclos_env__$private$build_command()
}

test_that("--resume and --session-id are single =-joined argv tokens", {
  args <- build_args(ClaudeAgentOptions(resume = "--dangerously-skip-permissions",
                                        session_id = "-abc"))
  expect_true("--resume=--dangerously-skip-permissions" %in% args)
  expect_true("--session-id=-abc" %in% args)
  expect_false("--resume" %in% args)
  expect_false("--dangerously-skip-permissions" %in% args)
  expect_false("--session-id" %in% args)
})

test_that("dash-leading extra_args values bind with --flag=value", {
  args <- build_args(ClaudeAgentOptions(extra_args = list(
    "debug-to" = "-evil", "model-x" = "plain", flag = NULL)))
  expect_true("--debug-to=-evil" %in% args)
  expect_false("-evil" %in% args)
  i <- which(args == "--model-x")
  expect_identical(args[i + 1L], "plain")
  expect_true("--flag" %in% args)
})

test_that("unsafe skill names are rejected before building --allowedTools", {
  bad <- c("a,b", "x(y)", "*", "foo:*", "foo *", "/cmd", " lead", "trail ", "",
           "a\\\\b", "end\\", "ctl\u0001", "bom\ufeff")
  for (name in bad) {
    expect_error(build_args(ClaudeAgentOptions(skills = name)), "skill", ignore.case = TRUE,
                 info = name)
  }
  args <- build_args(ClaudeAgentOptions(skills = c("pdf", "plugin:review")))
  allowed <- args[which(args == "--allowedTools") + 1L]
  expect_match(allowed, "Skill(pdf)", fixed = TRUE)
  expect_match(allowed, "Skill(plugin:review)", fixed = TRUE)
  expect_silent(build_args(ClaudeAgentOptions(skills = "all")))
})

test_that("can_use_tool shadowed by allowed_tools or bypassPermissions warns", {
  cb <- function(...) NULL
  expect_warning(build_args(ClaudeAgentOptions(can_use_tool = cb, allowed_tools = "Read")),
                 "can_use_tool")
  expect_warning(build_args(ClaudeAgentOptions(can_use_tool = cb,
                                               permission_mode = "bypassPermissions")),
                 "can_use_tool")
  expect_no_warning(build_args(ClaudeAgentOptions(can_use_tool = cb)))
  expect_no_warning(build_args(ClaudeAgentOptions(allowed_tools = "Read")))
})

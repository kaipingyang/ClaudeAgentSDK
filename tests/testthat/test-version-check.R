test_that("version check is cached by normalized CLI identity", {
  cli <- tempfile("claude-version-cli-")
  alias <- tempfile("claude-version-alias-")
  writeBin(charToRaw("fake-cli"), cli)
  expect_true(file.symlink(cli, alias))
  on.exit(unlink(c(alias, cli)), add = TRUE)

  cache <- new.env(parent = emptyenv())
  calls <- character()
  checker <- function(cli_path, min_version) {
    calls <<- c(calls, cli_path)
    "2.3.4"
  }

  expect_identical(
    check_claude_version_once(cli, cache = cache, checker = checker),
    "2.3.4"
  )
  expect_identical(
    check_claude_version_once(alias, cache = cache, checker = checker),
    "2.3.4"
  )
  expect_length(calls, 1L)
})

test_that("version cache invalidates for CLI signature and minimum version changes", {
  cli <- tempfile("claude-version-cli-")
  writeBin(charToRaw("v1"), cli)
  on.exit(unlink(cli), add = TRUE)

  cache <- new.env(parent = emptyenv())
  calls <- 0L
  checker <- function(cli_path, min_version) {
    calls <<- calls + 1L
    paste0("checked-", calls)
  }

  expect_identical(
    check_claude_version_once(
      cli, min_version = "2.0.0", cache = cache, checker = checker
    ),
    "checked-1"
  )
  expect_identical(
    check_claude_version_once(
      cli, min_version = "2.0.0", cache = cache, checker = checker
    ),
    "checked-1"
  )

  writeBin(charToRaw("v2-with-new-size"), cli)
  expect_identical(
    check_claude_version_once(
      cli, min_version = "2.0.0", cache = cache, checker = checker
    ),
    "checked-2"
  )
  expect_identical(
    check_claude_version_once(
      cli, min_version = "2.1.0", cache = cache, checker = checker
    ),
    "checked-3"
  )
  expect_identical(calls, 3L)
})

test_that("failed advisory version checks are cached", {
  cli <- tempfile("claude-version-cli-")
  writeBin(charToRaw("fake-cli"), cli)
  on.exit(unlink(cli), add = TRUE)

  cache <- new.env(parent = emptyenv())
  calls <- 0L
  checker <- function(cli_path, min_version) {
    calls <<- calls + 1L
    NULL
  }

  expect_null(check_claude_version_once(cli, cache = cache, checker = checker))
  expect_null(check_claude_version_once(cli, cache = cache, checker = checker))
  expect_identical(calls, 1L)
})

test_that("skip-version-check bypasses without poisoning the cache", {
  cli <- tempfile("claude-version-cli-")
  writeBin(charToRaw("fake-cli"), cli)
  on.exit(unlink(cli), add = TRUE)

  cache <- new.env(parent = emptyenv())
  calls <- 0L
  checker <- function(cli_path, min_version) {
    calls <<- calls + 1L
    "2.3.4"
  }

  withr::local_envvar(CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK = "1")
  expect_null(check_claude_version_once(cli, cache = cache, checker = checker))
  expect_identical(calls, 0L)

  Sys.unsetenv("CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK")
  expect_identical(
    check_claude_version_once(cli, cache = cache, checker = checker),
    "2.3.4"
  )
  expect_identical(calls, 1L)
})

.new_version_test_scheduler <- function() {
  queue <- list()
  list(
    schedule = function(callback, delay = 0) {
      queue[[length(queue) + 1L]] <<- callback
      invisible(NULL)
    },
    run_all = function(limit = 20L) {
      runs <- 0L
      while (length(queue)) {
        runs <- runs + 1L
        if (runs > limit) stop("test scheduler did not settle")
        callback <- queue[[1L]]
        queue <<- queue[-1L]
        callback()
      }
      invisible(runs)
    },
    pending = function() length(queue)
  )
}

.new_version_test_process <- function(output = "2.3.4 (Claude Code)", alive = FALSE) {
  state <- new.env(parent = emptyenv())
  state$alive <- alive
  state$killed <- FALSE
  process <- new.env(parent = emptyenv())
  process$is_alive <- function() state$alive
  process$read_all_output <- function() output
  process$kill <- function() {
    state$killed <- TRUE
    state$alive <- FALSE
    invisible(NULL)
  }
  list(process = process, state = state)
}

test_that("background version check schedules once and only warns for old CLI", {
  cli <- tempfile("claude-version-cli-")
  writeBin(charToRaw("fake-cli"), cli)
  on.exit(unlink(cli), add = TRUE)

  scheduler <- .new_version_test_scheduler()
  fake <- .new_version_test_process("1.9.9 (Claude Code)")
  cache <- new.env(parent = emptyenv())
  launches <- 0L
  warnings <- character()

  scheduled <- schedule_claude_version_check(
    cli,
    cache = cache,
    launcher = function(path) {
      launches <<- launches + 1L
      fake$process
    },
    schedule = scheduler$schedule,
    now = function() 0,
    warn = function(message, call. = FALSE) warnings <<- c(warnings, message)
  )
  duplicate <- schedule_claude_version_check(
    cli,
    cache = cache,
    launcher = function(path) stop("duplicate launch"),
    schedule = scheduler$schedule,
    now = function() 0,
    warn = function(message, call. = FALSE) warnings <<- c(warnings, message)
  )

  expect_true(scheduled)
  expect_false(duplicate)
  expect_identical(launches, 0L)
  expect_identical(scheduler$pending(), 1L)

  scheduler$run_all()
  expect_identical(launches, 1L)
  expect_length(warnings, 1L)
  expect_match(warnings[[1L]], "below the minimum required version")

  expect_false(schedule_claude_version_check(
    cli, cache = cache, schedule = scheduler$schedule
  ))
})

test_that("supported and failed background checks remain silent", {
  cli <- tempfile("claude-version-cli-")
  writeBin(charToRaw("fake-cli"), cli)
  on.exit(unlink(cli), add = TRUE)

  warnings <- character()
  warn <- function(message, call. = FALSE) warnings <<- c(warnings, message)

  scheduler <- .new_version_test_scheduler()
  supported_cache <- new.env(parent = emptyenv())
  fake <- .new_version_test_process("2.3.4 (Claude Code)")
  expect_true(schedule_claude_version_check(
    cli,
    cache = supported_cache,
    launcher = function(path) fake$process,
    schedule = scheduler$schedule,
    now = function() 0,
    warn = warn
  ))
  scheduler$run_all()
  expect_length(warnings, 0L)

  failed_scheduler <- .new_version_test_scheduler()
  failed_cache <- new.env(parent = emptyenv())
  expect_true(schedule_claude_version_check(
    cli,
    cache = failed_cache,
    launcher = function(path) stop("version process unavailable"),
    schedule = failed_scheduler$schedule,
    now = function() 0,
    warn = warn
  ))
  expect_silent(failed_scheduler$run_all())
  expect_length(warnings, 0L)
  expect_false(schedule_claude_version_check(
    cli, cache = failed_cache, schedule = failed_scheduler$schedule
  ))
})

test_that("background version check honors skip without scheduling", {
  cli <- tempfile("claude-version-cli-")
  writeBin(charToRaw("fake-cli"), cli)
  on.exit(unlink(cli), add = TRUE)
  withr::local_envvar(CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK = "1")

  scheduler <- .new_version_test_scheduler()
  expect_false(schedule_claude_version_check(
    cli,
    cache = new.env(parent = emptyenv()),
    launcher = function(path) stop("must not launch"),
    schedule = scheduler$schedule
  ))
  expect_identical(scheduler$pending(), 0L)
})

test_that("transport schedules advisory check only after initialize", {
  connect_source <- paste(
    deparse(ClaudeAgentSDK:::SubprocessCLITransport$public_methods$connect),
    collapse = "\n"
  )
  expect_false(grepl("check_claude_version_once\\(cli_path\\)", connect_source))
  expect_false(grepl("check_claude_version\\(cli_path\\)", connect_source))
  expect_match(connect_source, "schedule_claude_version_check\\(cli_path\\)")
  initialize_at <- regexpr("private$wait_for_initialize()", connect_source, fixed = TRUE)[[1L]]
  schedule_at <- regexpr("schedule_claude_version_check(cli_path)", connect_source, fixed = TRUE)[[1L]]
  expect_gt(initialize_at, 0L)
  expect_gt(schedule_at, initialize_at)
})

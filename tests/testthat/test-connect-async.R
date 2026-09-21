async_connect_fixture <- function(mode = "ok", delay = 0.2, custom = FALSE,
                                  .env = parent.frame()) {
  root <- tempfile("sdk-async-connect-")
  dir.create(root)
  peer <- file.path(root, "claude")
  stopifnot(file.copy(test_path("fixtures/initialize_async_peer.py"), peer))
  Sys.chmod(peer, "0755")
  withr::defer(unlink(root, recursive = TRUE), envir = .env)
  options <- ClaudeAgentOptions(
    cli_path = peer, cwd = root,
    env = list(
      SDK_INIT_MODE = mode, SDK_INIT_DELAY = as.character(delay),
      CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK = "1"
    )
  )
  transport <- if (custom) SubprocessCLITransport$new(options) else NULL
  client <- ClaudeSDKClient$new(options, transport = transport)
  withr::defer(client$disconnect(), envir = .env)
  client
}

drain_async_connect <- function(predicate, seconds = 2) {
  deadline <- Sys.time() + seconds
  while (!isTRUE(predicate()) && Sys.time() < deadline) {
    later::run_now(0.01)
    Sys.sleep(0.005)
  }
  isTRUE(predicate())
}

test_that("asynchronous initialize yields to other callbacks and preserves surrounding frames", {
  client <- async_connect_fixture()
  expect_true(is.function(client$connect_async))
  if (!is.function(client$connect_async)) return()
  resolved <- error <- NULL
  unrelated_callback <- FALSE
  cancel <- later::later(function() unrelated_callback <<- TRUE, 0.02)
  withr::defer(cancel())
  started <- proc.time()[["elapsed"]]
  abort <- client$connect_async(
    on_fulfilled = function(value) resolved <<- value,
    on_rejected = function(value) error <<- value,
    timeout_ms = 1500L
  )
  expect_lt(proc.time()[["elapsed"]] - started, 0.15)
  expect_true(is.function(abort))
  expect_error(client$send("must-not-send"), "initialize handshake is still pending")
  expect_true(drain_async_connect(function() unrelated_callback, 0.1))
  expect_null(resolved)
  expect_true(drain_async_connect(function() !is.null(resolved) || !is.null(error)))
  expect_null(error)
  expect_equal(client$get_server_info()$commands[[1L]]$name, "fixture")
  messages <- client$poll_messages()
  expect_identical(vapply(messages, function(message) message$data$status, ""),
                   c("before-init", "after-init"))
  expect_false(abort())
})

test_that("cancelled initialize settles once and leaves no subprocess or stale callback", {
  client <- async_connect_fixture(delay = 1)
  expect_true(is.function(client$connect_async))
  if (!is.function(client$connect_async)) return()
  fulfilled <- rejected <- 0L
  reason <- NULL
  abort <- client$connect_async(
    on_fulfilled = function(value) fulfilled <<- fulfilled + 1L,
    on_rejected = function(error) {
      rejected <<- rejected + 1L
      reason <<- error
    }
  )
  expect_true(abort())
  expect_false(abort())
  expect_s3_class(reason, "claude_connection_cancelled")
  expect_identical(rejected, 1L)
  expect_identical(fulfilled, 0L)
  expect_false(client$is_alive())
  drain_async_connect(function() FALSE, 0.3)
  expect_identical(rejected, 1L)
  expect_identical(fulfilled, 0L)
})

test_that("initialization errors and process death reject rather than connecting successfully", {
  for (mode in c("error", "exit")) {
    client <- async_connect_fixture(mode = mode, delay = 0.02)
    expect_true(is.function(client$connect_async))
    if (!is.function(client$connect_async)) return()
    fulfilled <- FALSE
    reason <- NULL
    client$connect_async(
      on_fulfilled = function(value) fulfilled <<- TRUE,
      on_rejected = function(error) reason <<- error,
      timeout_ms = 500L
    )
    expect_true(drain_async_connect(function() !is.null(reason)))
    expect_s3_class(reason, "error")
    expect_false(fulfilled)
    expect_false(client$is_alive())
  }
})

test_that("initialization deadline is bounded and disconnect cancels a pending handshake", {
  client <- async_connect_fixture(delay = 1)
  expect_true(is.function(client$connect_async))
  if (!is.function(client$connect_async)) return()
  reason <- NULL
  client$connect_async(
    on_fulfilled = function(value) stop("Unexpected completion"),
    on_rejected = function(error) reason <<- error,
    timeout_ms = 30L
  )
  expect_true(drain_async_connect(function() !is.null(reason), 0.5))
  expect_match(conditionMessage(reason), "initialize.*timed out|timed out.*initialize")
  expect_false(client$is_alive())
  reason <- NULL
  client$connect_async(
    on_fulfilled = function(value) stop("Unexpected completion"),
    on_rejected = function(error) reason <<- error,
    timeout_ms = 1500L
  )
  client$disconnect()
  expect_s3_class(reason, "claude_connection_cancelled")
  expect_false(client$is_alive())
})

test_that("default asynchronous initialization preserves the environment timeout", {
  withr::local_envvar(CLAUDE_CODE_STREAM_CLOSE_TIMEOUT = "120000")
  client <- async_connect_fixture(delay = 1)
  expect_true(is.function(client$connect_async))
  if (!is.function(client$connect_async)) return()
  reason <- NULL
  abort <- client$connect_async(
    on_fulfilled = function(value) stop("Unexpected completion"),
    on_rejected = function(error) reason <<- error
  )
  transport <- client$.__enclos_env__$private$transport
  deadline <- transport$.__enclos_env__$private$initialize_state$deadline
  expect_gt(deadline - proc.time()[["elapsed"]], 119)
  abort()
  expect_s3_class(reason, "claude_connection_cancelled")
})

test_that("a disconnect rejection callback can reconnect without losing the new transport", {
  verify <- function(custom) {
    client <- async_connect_fixture(delay = 0.15, custom = custom)
    replacement <- NULL
    ready <- FALSE
    retry_error <- NULL
    withr::defer(if (!is.null(replacement)) replacement$disconnect())
    client$connect_async(
      on_fulfilled = function(value) stop("First initialization should be cancelled"),
      on_rejected = function(error) {
        client$connect_async(
          on_fulfilled = function(value) ready <<- TRUE,
          on_rejected = function(error) retry_error <<- error
        )
        replacement <<- client$.__enclos_env__$private$transport
      }
    )
    client$disconnect()
    expect_true(drain_async_connect(function() ready || !is.null(retry_error)))
    expect_null(retry_error)
    expect_true(ready)
    expect_true(client$is_alive())
    expect_identical(client$.__enclos_env__$private$transport, replacement)
    expect_no_error(client$send("local-fixture-only"))
  }
  verify(FALSE)
  verify(TRUE)
})

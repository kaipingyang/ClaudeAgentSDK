test_that("control dispatcher correlates responses without consuming SDK messages", {
  dispatcher <- .new_control_dispatcher()
  resolved <- NULL
  rejected <- NULL

  dispatcher$register(
    request_id = "req_context",
    subtype = "get_context_usage",
    resolve = function(value) resolved <<- value,
    reject = function(error) rejected <<- error
  )

  sdk_message <- list(type = "assistant", message = list(content = list()))
  expect_false(dispatcher$dispatch(sdk_message))
  expect_equal(dispatcher$pending_count(), 1L)

  response <- list(
    type = "control_response",
    response = list(
      subtype = "success",
      request_id = "req_context",
      response = list(totalTokens = 123L)
    )
  )
  expect_true(dispatcher$dispatch(response))
  expect_equal(resolved, list(totalTokens = 123L))
  expect_null(rejected)
  expect_equal(dispatcher$pending_count(), 0L)
})

test_that("control dispatcher resolves out of order without losing message order", {
  dispatcher <- .new_control_dispatcher()
  resolved <- list()
  sdk_messages <- list()

  dispatcher$register(
    "req_a", "first",
    resolve = function(value) resolved[["a"]] <<- value,
    reject = function(error) stop(error)
  )
  dispatcher$register(
    "req_b", "second",
    resolve = function(value) resolved[["b"]] <<- value,
    reject = function(error) stop(error)
  )

  frames <- list(
    list(type = "assistant", sequence = 1L),
    list(
      type = "control_response",
      response = list(
        subtype = "success", request_id = "req_b",
        response = list(order = 2L)
      )
    ),
    list(type = "system", sequence = 2L),
    list(
      type = "control_response",
      response = list(
        subtype = "success", request_id = "req_a",
        response = list(order = 1L)
      )
    ),
    list(type = "result", sequence = 3L)
  )

  for (frame in frames) {
    if (!dispatcher$dispatch(frame)) {
      sdk_messages[[length(sdk_messages) + 1L]] <- frame
    }
  }

  expect_equal(resolved$b, list(order = 2L))
  expect_equal(resolved$a, list(order = 1L))
  expect_equal(
    vapply(sdk_messages, `[[`, integer(1), "sequence"),
    1:3
  )
  expect_equal(dispatcher$pending_count(), 0L)
})

test_that("control dispatcher sends only the matching error to its waiter", {
  dispatcher <- .new_control_dispatcher()
  errors <- list()
  resolved <- NULL

  dispatcher$register(
    "req_ok", "ok",
    resolve = function(value) resolved <<- value,
    reject = function(error) errors[["ok"]] <<- error
  )
  dispatcher$register(
    "req_bad", "bad",
    resolve = function(value) stop("unexpected resolve"),
    reject = function(error) errors[["bad"]] <<- error
  )

  expect_true(dispatcher$dispatch(list(
    type = "control_response",
    response = list(
      subtype = "error", request_id = "req_bad", error = "bad request"
    )
  )))
  expect_s3_class(errors$bad, "simpleError")
  expect_match(conditionMessage(errors$bad), "bad request")
  expect_null(errors$ok)
  expect_equal(dispatcher$pending_count(), 1L)

  expect_true(dispatcher$dispatch(list(
    type = "control_response",
    response = list(
      subtype = "success", request_id = "req_ok", response = list(ok = TRUE)
    )
  )))
  expect_equal(resolved, list(ok = TRUE))
  expect_equal(dispatcher$pending_count(), 0L)
})

test_that("timed out requests are removed and late responses are ignored", {
  dispatcher <- .new_control_dispatcher()
  resolved <- FALSE
  rejected <- NULL

  dispatcher$register(
    "req_timeout", "get_context_usage",
    resolve = function(value) resolved <<- TRUE,
    reject = function(error) rejected <<- error
  )
  expect_true(dispatcher$reject(
    "req_timeout", simpleError("Control request timeout: get_context_usage")
  ))
  expect_s3_class(rejected, "simpleError")
  expect_match(conditionMessage(rejected), "timeout")
  expect_equal(dispatcher$pending_count(), 0L)

  expect_true(dispatcher$dispatch(list(
    type = "control_response",
    response = list(
      subtype = "success", request_id = "req_timeout",
      response = list(totalTokens = 999L)
    )
  )))
  expect_false(resolved)
  expect_equal(dispatcher$pending_count(), 0L)
})

test_that("process exit rejects every pending control request", {
  dispatcher <- .new_control_dispatcher()
  rejected <- list()

  for (request_id in c("req_one", "req_two")) {
    local({
      id <- request_id
      dispatcher$register(
        id, "test",
        resolve = function(value) stop("unexpected resolve"),
        reject = function(error) rejected[[id]] <<- error
      )
    })
  }

  count <- dispatcher$reject_all(simpleError("Claude Code process exited"))
  expect_equal(count, 2L)
  expect_equal(dispatcher$pending_count(), 0L)
  expect_setequal(names(rejected), c("req_one", "req_two"))
  expect_true(all(vapply(
    rejected,
    function(error) grepl("process exited", conditionMessage(error), fixed = TRUE),
    logical(1)
  )))
})

test_that("transport send_async registers before write and never reads stdout", {
  skip_if_not_installed("promises")
  transport <- SubprocessCLITransport$new(ClaudeAgentOptions())
  private <- transport$.__enclos_env__$private
  written <- NULL
  read_calls <- 0L
  pending_at_write <- NULL

  fake_proc <- new.env(parent = emptyenv())
  fake_proc$is_alive <- function() TRUE
  fake_proc$write_input <- function(data) {
    pending_at_write <<- private$control_dispatcher$pending_count()
    written <<- data
    raw(0)
  }
  fake_proc$poll_io <- function(...) {
    read_calls <<- read_calls + 1L
    stop("send_async must not poll stdout")
  }
  fake_proc$read_output <- function(...) {
    read_calls <<- read_calls + 1L
    stop("send_async must not read stdout")
  }
  private$proc <- fake_proc
  private$ready <- TRUE

  resolved <- NULL
  rejected <- NULL
  promise <- transport$send_async(
    list(subtype = "get_context_usage"),
    timeout_ms = 1000L
  )
  promises::then(
    promise,
    onFulfilled = function(value) resolved <<- value,
    onRejected = function(error) rejected <<- error
  )

  request <- jsonlite::fromJSON(trimws(written), simplifyVector = FALSE)
  expect_equal(pending_at_write, 1L)
  expect_equal(request$type, "control_request")
  expect_equal(request$request$subtype, "get_context_usage")
  expect_equal(read_calls, 0L)

  expect_true(private$control_dispatcher$dispatch(list(
    type = "control_response",
    response = list(
      subtype = "success",
      request_id = request$request_id,
      response = list(totalTokens = 456L)
    )
  )))
  later::run_now(0.05)

  expect_equal(resolved, list(totalTokens = 456L))
  expect_null(rejected)
  expect_equal(private$control_dispatcher$pending_count(), 0L)
})

test_that("transport send_async times out without blocking the event loop", {
  skip_if_not_installed("promises")
  transport <- SubprocessCLITransport$new(ClaudeAgentOptions())
  private <- transport$.__enclos_env__$private

  fake_proc <- new.env(parent = emptyenv())
  fake_proc$is_alive <- function() TRUE
  fake_proc$write_input <- function(data) raw(0)
  private$proc <- fake_proc
  private$ready <- TRUE

  rejected <- NULL
  heartbeat <- FALSE
  promise <- transport$send_async(
    list(subtype = "get_context_usage"),
    timeout_ms = 1L
  )
  promises::then(
    promise,
    onFulfilled = function(value) stop("unexpected resolve"),
    onRejected = function(error) rejected <<- error
  )
  later::later(function() heartbeat <<- TRUE, delay = 0)
  later::run_now()
  Sys.sleep(0.01)
  later::run_now()
  later::run_now()

  expect_true(heartbeat)
  expect_s3_class(rejected, "simpleError")
  expect_match(conditionMessage(rejected), "get_context_usage")
  expect_equal(private$control_dispatcher$pending_count(), 0L)
})

test_that("transport process exit rejects an in-flight async control", {
  skip_if_not_installed("promises")
  transport <- SubprocessCLITransport$new(ClaudeAgentOptions())
  private <- transport$.__enclos_env__$private
  alive <- TRUE

  fake_proc <- new.env(parent = emptyenv())
  fake_proc$is_alive <- function() alive
  fake_proc$write_input <- function(data) raw(0)
  private$proc <- fake_proc
  private$ready <- TRUE

  rejected <- NULL
  promise <- transport$send_async(list(subtype = "test"), timeout_ms = 1000L)
  promises::then(
    promise,
    onFulfilled = function(value) stop("unexpected resolve"),
    onRejected = function(error) rejected <<- error
  )
  alive <- FALSE
  expect_equal(transport$read_available_messages(), list())
  later::run_now(0.05)

  expect_s3_class(rejected, "simpleError")
  expect_match(conditionMessage(rejected), "process exited")
  expect_equal(private$control_dispatcher$pending_count(), 0L)
})


test_that("transport send_async_callback settles without a promise or stdout read", {
  transport <- SubprocessCLITransport$new(ClaudeAgentOptions())
  private <- transport$.__enclos_env__$private
  written <- NULL
  fake_proc <- new.env(parent = emptyenv())
  fake_proc$is_alive <- function() TRUE
  fake_proc$write_input <- function(data) { written <<- data; raw(0) }
  private$proc <- fake_proc
  private$ready <- TRUE

  resolved <- NULL
  rejected <- NULL
  request_id <- transport$send_async_callback(
    list(subtype = "get_context_usage"),
    on_fulfilled = function(value) resolved <<- value,
    on_rejected = function(error) rejected <<- error,
    timeout_ms = 1000L
  )
  request <- jsonlite::fromJSON(trimws(written), simplifyVector = FALSE)
  expect_identical(request_id, request$request_id)
  expect_equal(private$control_dispatcher$pending_count(), 1L)
  expect_true(private$control_dispatcher$dispatch(list(
    type = "control_response",
    response = list(
      subtype = "success",
      request_id = request$request_id,
      response = list(totalTokens = 654L)
    )
  )))
  expect_equal(resolved, list(totalTokens = 654L))
  expect_null(rejected)
  expect_equal(private$control_dispatcher$pending_count(), 0L)
})


test_that("transport callback can disable the later timeout", {
  transport <- SubprocessCLITransport$new(ClaudeAgentOptions())
  private <- transport$.__enclos_env__$private
  fake_proc <- new.env(parent = emptyenv())
  fake_proc$is_alive <- function() TRUE
  fake_proc$write_input <- function(data) raw(0)
  private$proc <- fake_proc
  private$ready <- TRUE
  loop <- later::create_loop(parent = NULL)
  on.exit(later::destroy_loop(loop), add = TRUE)

  request_id <- later::with_loop(loop, transport$send_async_callback(
    list(subtype = "get_context_usage"),
    on_fulfilled = function(value) NULL,
    on_rejected = function(error) NULL,
    timeout_ms = Inf
  ))

  expect_true(later::loop_empty(loop))
  expect_equal(private$control_dispatcher$pending_count(), 1L)
  private$control_dispatcher$reject(request_id, simpleError("test cleanup"))
  expect_equal(private$control_dispatcher$pending_count(), 0L)
})


test_that("dispatcher isolates callback errors and still rejects every pending request", {
  dispatcher <- ClaudeAgentSDK:::.new_control_dispatcher()
  rejected <- character()
  dispatcher$register(
    "resolve-throws", "first",
    resolve = function(value) stop("consumer resolve failed"),
    reject = function(error) NULL,
    on_settle = function() stop("consumer settle failed")
  )

  expect_true(dispatcher$dispatch(list(
    type = "control_response",
    response = list(
      subtype = "success", request_id = "resolve-throws", response = list(ok = TRUE)
    )
  )))
  expect_equal(dispatcher$pending_count(), 0L)

  dispatcher$register(
    "a-reject-throws", "second",
    resolve = function(value) NULL,
    reject = function(error) stop("consumer reject failed")
  )
  dispatcher$register(
    "z-reject-records", "third",
    resolve = function(value) NULL,
    reject = function(error) rejected <<- c(rejected, conditionMessage(error))
  )

  expect_equal(dispatcher$reject_all(simpleError("transport closed")), 2L)
  expect_equal(dispatcher$pending_count(), 0L)
  expect_equal(rejected, "transport closed")
})

test_that("client exposes transport liveness without polling or connecting", {
  alive <- FALSE
  reads <- 0L
  transport <- list(
    connect = function() alive <<- TRUE,
    disconnect = function() alive <<- FALSE,
    is_alive = function() alive,
    get_init_result = function() list(),
    read_available_messages = function() {
      reads <<- reads + 1L
      list()
    }
  )
  client <- ClaudeSDKClient$new(transport = transport)
  expect_true(is.function(client$is_alive))
  if (!is.function(client$is_alive)) return()
  expect_false(client$is_alive())
  client$connect()
  expect_true(client$is_alive())
  alive <- FALSE
  expect_false(client$is_alive())
  expect_identical(reads, 0L)
  client$disconnect()
})

test_that("polling a dead transport reports a connection error after available tail messages", {
  queue <- list(ResultMessage(
    subtype = "success", duration_ms = 1, duration_api_ms = 1,
    is_error = FALSE, num_turns = 1, session_id = "tail-session", result = "Complete"
  ))
  transport <- list(
    connect = function() invisible(NULL),
    disconnect = function() invisible(NULL),
    is_alive = function() FALSE,
    get_init_result = function() list(),
    read_available_messages = function() {
      batch <- queue
      queue <<- list()
      batch
    }
  )
  client <- ClaudeSDKClient$new(transport = transport)
  client$connect()
  withr::defer(client$disconnect())
  expect_s3_class(client$poll_messages()[[1L]], "ResultMessage")
  expect_error(client$poll_messages(), class = "claude_error_cli_connection")
})

test_that("nonblocking transport preserves final stdout after the process exits", {
  transport <- SubprocessCLITransport$new(ClaudeAgentOptions())
  private <- transport$.__enclos_env__$private
  raw <- paste0(
    '{"type":"result","subtype":"success","duration_ms":1,',
    '"duration_api_ms":1,"is_error":false,"num_turns":1,',
    '"session_id":"tail-session","result":"Complete"}\n'
  )
  private$proc <- list(
    is_alive = function() FALSE,
    poll_io = function(timeout) c(output = "ready", error = "closed"),
    read_output = function(max) {
      value <- raw
      raw <<- ""
      value
    },
    get_exit_status = function() 0L
  )
  withr::defer(private$proc <- NULL)
  messages <- transport$read_available_messages()
  expect_length(messages, 1L)
  if (length(messages)) expect_s3_class(messages[[1L]], "ResultMessage")
})

test_that("asynchronous task stop uses the shared control dispatcher without reading stdout", {
  requests <- list()
  transport <- list(
    connect = function() invisible(NULL),
    disconnect = function() invisible(NULL),
    is_alive = function() TRUE,
    get_init_result = function() list(),
    send_async_callback = function(request, on_fulfilled, on_rejected, timeout_ms) {
      requests[[length(requests) + 1L]] <<- list(
        request = request, resolve = on_fulfilled, reject = on_rejected,
        timeout_ms = timeout_ms
      )
      "stop-request"
    }
  )
  client <- ClaudeSDKClient$new(transport = transport)
  client$connect()
  withr::defer(client$disconnect())
  expect_true(is.function(client$stop_task_async))
  if (!is.function(client$stop_task_async)) return()
  result <- error <- NULL
  client$stop_task_async(
    "task-1", timeout_ms = 5000L,
    on_fulfilled = function(value) result <<- value,
    on_rejected = function(value) error <<- value
  )
  expect_identical(requests[[1L]]$request, list(subtype = "stop_task", task_id = "task-1"))
  expect_identical(requests[[1L]]$timeout_ms, 5000L)
  requests[[1L]]$resolve(list(accepted = TRUE))
  expect_identical(result, list(accepted = TRUE))
  expect_null(error)
})

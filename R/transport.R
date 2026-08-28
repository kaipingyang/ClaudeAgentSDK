#' @title SubprocessCLITransport
#' @description R6 class that manages the Claude Code CLI subprocess and
#'   implements the full bidirectional control protocol. Mirrors
#'   `_internal/transport/subprocess_cli.py` plus the `Query` class from
#'   `_internal/query.py`.
#' @name transport
#' @keywords internal
#' @importFrom R6 R6Class
#' @importFrom later later
#' @importFrom processx process
NULL

.DEFAULT_MAX_BUFFER_SIZE <- 1024L * 1024L  # 1 MB

# Correlate outgoing control requests with responses consumed by the transport's
# single stdout reader. Returning FALSE from dispatch() means the frame is a
# regular SDK message and must continue through the normal message path.
#' @noRd
.new_control_dispatcher <- function() {
  pending <- new.env(parent = emptyenv())

  settle <- function(request_id, value = NULL, error = NULL) {
    if (!exists(request_id, envir = pending, inherits = FALSE)) return(FALSE)
    record <- get(request_id, envir = pending, inherits = FALSE)
    rm(list = request_id, envir = pending)
    if (is.function(record$on_settle)) {
      try(record$on_settle(), silent = TRUE)
    }
    try(
      if (is.null(error)) {
        record$resolve(value)
      } else {
        record$reject(error)
      },
      silent = TRUE
    )
    TRUE
  }

  list(
    register = function(request_id, subtype, resolve, reject,
                        on_settle = NULL) {
      if (exists(request_id, envir = pending, inherits = FALSE)) {
        stop("Duplicate pending control request: ", request_id, call. = FALSE)
      }
      assign(
        request_id,
        list(
          subtype = subtype,
          resolve = resolve,
          reject = reject,
          on_settle = on_settle
        ),
        envir = pending
      )
      invisible(request_id)
    },
    dispatch = function(message) {
      if (!is.list(message) || !identical(message[["type"]], "control_response")) {
        return(FALSE)
      }
      response <- message[["response"]] %||% list()
      request_id <- response[["request_id"]]
      if (is.null(request_id) ||
          !exists(request_id, envir = pending, inherits = FALSE)) {
        return(TRUE)
      }
      if (identical(response[["subtype"]], "error")) {
        settle(
          request_id,
          error = simpleError(response[["error"]] %||% "Control request error")
        )
      } else {
        settle(request_id, value = response[["response"]] %||% list())
      }
      TRUE
    },
    reject = function(request_id, error) {
      settle(request_id, error = error)
    },
    reject_all = function(error) {
      request_ids <- ls(envir = pending, all.names = TRUE)
      for (request_id in request_ids) settle(request_id, error = error)
      invisible(length(request_ids))
    },
    pending_count = function() {
      length(ls(envir = pending, all.names = TRUE))
    }
  )
}

# Write the full payload to a process's stdin, looping until it is flushed.
#
# processx `write_input()` is NON-BLOCKING: it writes only what currently fits the
# OS pipe buffer and RETURNS the unwritten remainder (a raw vector). A single call
# therefore TRUNCATES any message larger than the pipe buffer (~200 KB on Linux) —
# the CLI then never receives the line's terminating newline and hangs forever
# (e.g. large text messages or image attachments). Loop until the whole payload is
# flushed, re-feeding the returned remainder and briefly yielding so the CLI can
# drain stdin (backpressure). This mirrors the official Python SDK, whose async
# stdin write (`await TextSendStream.send(data)`) always writes the complete payload.
#' @noRd
.write_all_to_process <- function(proc, data, timeout_s = 60) {
  deadline <- Sys.time() + timeout_s
  repeat {
    remaining <- proc$write_input(data)          # raw vector of unwritten bytes
    if (length(remaining) == 0L) break
    if (!proc$is_alive())
      stop("process terminated during stdin write", call. = FALSE)
    if (Sys.time() > deadline)
      stop("timed out flushing message to process stdin", call. = FALSE)
    data <- remaining
    Sys.sleep(0.002)
  }
  invisible(NULL)
}

#' SubprocessCLITransport R6 Class
#'
#' Internal class (not exported). Spawns a `claude` subprocess with
#' `--output-format stream-json --input-format stream-json --verbose`, reads
#' newline-delimited JSON from stdout, and handles the bidirectional control
#' protocol (initialize, permission_request, hook_callback, interrupt).
#'
#' @section Usage:
#' ```r
#' t <- SubprocessCLITransport$new(options)
#' t$connect()
#' t$send(build_user_message_json("Hello"))
#' gen <- t$receive_messages()
#' coro::loop(for (msg in gen) { ... })
#' t$disconnect()
#' ```
#' @keywords internal
SubprocessCLITransport <- R6::R6Class(
  "SubprocessCLITransport",

  public = list(

    #' @description Initialize the transport with a `ClaudeAgentOptions` object.
    #' @param options A [ClaudeAgentOptions()] object.
    initialize = function(options) {
      private$options    <- options
      private$buffer     <- .new_stream_line_decoder()
      private$write_lock <- FALSE
      private$session_id <- ""
      private$req_counter <- 0L
      private$pending_permissions <- new.env(parent = emptyenv())
      private$control_dispatcher <- .new_control_dispatcher()
      invisible(self)
    },

    #' @description Start the subprocess and wait for the `initialize`
    #'   control-request handshake.
    connect = function() {
      if (!is.null(private$proc) && private$proc$is_alive()) return(invisible(self))

      cli_path <- find_claude(private$options$cli_path)

      args <- private$build_command()

      # Build process environment
      inherited_env <- as.list(Sys.getenv())
      inherited_env[["CLAUDECODE"]] <- NULL  # prevent nested detection
      process_env <- c(
        inherited_env,
        list(CLAUDE_CODE_ENTRYPOINT = "sdk-r"),
        private$options$env,
        list(CLAUDE_AGENT_SDK_VERSION = as.character(
          utils::packageVersion("ClaudeAgentSDK")
        ))
      )
      if (isTRUE(private$options$enable_file_checkpointing)) {
        process_env[["CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING"]] <- "true"
      }
      cwd <- private$options$cwd %||% getwd()
      process_env[["PWD"]] <- cwd

      # Determine whether to pipe stderr
      should_pipe_stderr <- !is.null(private$options$stderr) ||
        "debug-to-stderr" %in% names(private$options$extra_args)

      private$proc <- processx::process$new(
        command = cli_path,
        args    = args,
        stdin   = "|",
        stdout  = "|",
        stderr  = if (should_pipe_stderr) "|" else NULL,
        wd      = cwd,
        env     = unlist(process_env, use.names = TRUE),
        cleanup = TRUE
      )

      private$ready <- TRUE

      # Wait for the initialize control-request from the CLI. Version checking is
      # advisory and starts only after the usable connection is established.
      private$wait_for_initialize()
      schedule_claude_version_check(cli_path)

      invisible(self)
    },

    #' @description Gracefully shut down the subprocess.
    disconnect = function() {
      private$ready <- FALSE
      if (!is.null(private$control_dispatcher)) {
        private$control_dispatcher$reject_all(
          simpleError("Claude Code transport disconnected")
        )
      }
      if (is.null(private$proc)) return(invisible(self))
      tryCatch({
        if (private$proc$is_alive()) {
          private$proc$interrupt()
          private$proc$wait(timeout = 3000)
          if (private$proc$is_alive()) {
            private$proc$kill()
            private$proc$wait(timeout = 2000)
          }
        }
      }, error = function(e) NULL)
      private$proc <- NULL
      invisible(self)
    },

    #' @description Write a JSON string to the subprocess stdin.
    #' @param message_json Character(1). Must NOT include a trailing newline;
    #'   one is appended automatically.
    send = function(message_json) {
      if (!isTRUE(private$ready) || is.null(private$proc)) {
        claude_cli_connection_error("Transport is not connected. Call connect() first.")
      }
      if (!private$proc$is_alive()) {
        claude_cli_connection_error(paste0(
          "Cannot write to terminated process (exit code: ",
          private$proc$get_exit_status(), ")"
        ))
      }
      tryCatch(
        .write_all_to_process(private$proc, paste0(message_json, "\n")),
        error = function(e) {
          private$ready <- FALSE
          claude_cli_connection_error(
            paste0("Failed to write to process stdin: ", conditionMessage(e))
          )
        }
      )
      invisible(self)
    },

    #' @description Return TRUE if the subprocess is running.
    is_alive = function() {
      !is.null(private$proc) && private$proc$is_alive()
    },

    #' @description Return the server initialization info captured during
    #'   the initialize handshake, or NULL if not yet connected.
    get_init_result = function() {
      private$init_result
    },

    #' @description Send a control request and settle callbacks from the
    #'   transport's normal stdout reader. This method creates no promise and
    #'   never reads stdout.
    #' @param request List. Control request body (must have `subtype`).
    #' @param on_fulfilled Function called with the response payload.
    #' @param on_rejected Function called with an error condition.
    #' @param timeout_ms Numeric. Milliseconds before asynchronous rejection;
    #'   use `Inf` to disable the callback timer.
    #' @return The request id invisibly.
    send_async_callback = function(request, on_fulfilled, on_rejected,
                                   timeout_ms = 5000L) {
      if (!is.function(on_fulfilled) || !is.function(on_rejected)) {
        stop("on_fulfilled and on_rejected must be functions", call. = FALSE)
      }
      timeout_ms <- as.numeric(timeout_ms)
      if (length(timeout_ms) != 1L || is.na(timeout_ms) || timeout_ms < 0) {
        stop("timeout_ms must be one non-negative number", call. = FALSE)
      }

      private$req_counter <- private$req_counter + 1L
      request_id <- paste0(
        "req_", private$req_counter, "_",
        paste0(as.hexmode(sample.int(256, 4) - 1), collapse = "")
      )
      json <- jsonlite::toJSON(
        list(type = "control_request", request_id = request_id, request = request),
        auto_unbox = TRUE,
        null = "null"
      )
      subtype <- request[["subtype"]] %||% "unknown"
      timer_handle <- NULL
      cancel_timer <- function() {
        if (!is.null(timer_handle)) {
          try(later::cancel(timer_handle), silent = TRUE)
          timer_handle <<- NULL
        }
        invisible(NULL)
      }
      private$control_dispatcher$register(
        request_id = request_id,
        subtype = subtype,
        resolve = on_fulfilled,
        reject = on_rejected,
        on_settle = cancel_timer
      )
      if (is.finite(timeout_ms)) {
        timer_handle <- later::later(function() {
          private$control_dispatcher$reject(
            request_id,
            simpleError(paste0("Control request timeout: ", subtype))
          )
        }, delay = timeout_ms / 1000)
      }
      tryCatch(
        self$send(json),
        error = function(error) {
          private$control_dispatcher$reject(request_id, error)
        }
      )
      invisible(request_id)
    },

    #' @description Send a control request and return a promise settled by the
    #'   transport's normal stdout reader. This method never reads stdout.
    #' @param request List. Control request body (must have `subtype`).
    #' @param timeout_ms Integer. Milliseconds before asynchronous rejection.
    #' @return A `promises::promise` resolving to the response payload.
    send_async = function(request, timeout_ms = 5000L) {
      if (!requireNamespace("promises", quietly = TRUE)) {
        stop(
          "The 'promises' package is required for send_async(). ",
          "Install with: install.packages('promises')",
          call. = FALSE
        )
      }
      timeout_ms <- as.numeric(timeout_ms)
      if (length(timeout_ms) != 1L || is.na(timeout_ms) ||
          !is.finite(timeout_ms) || timeout_ms < 0) {
        stop("timeout_ms must be one non-negative finite number", call. = FALSE)
      }

      private$req_counter <- private$req_counter + 1L
      request_id <- paste0(
        "req_", private$req_counter, "_",
        paste0(as.hexmode(sample.int(256, 4) - 1), collapse = "")
      )
      json <- jsonlite::toJSON(
        list(type = "control_request", request_id = request_id, request = request),
        auto_unbox = TRUE,
        null = "null"
      )
      subtype <- request[["subtype"]] %||% "unknown"

      promises::promise(function(resolve, reject) {
        timer_handle <- NULL
        cancel_timer <- function() {
          if (!is.null(timer_handle)) {
            try(later::cancel(timer_handle), silent = TRUE)
            timer_handle <<- NULL
          }
          invisible(NULL)
        }
        private$control_dispatcher$register(
          request_id = request_id,
          subtype = subtype,
          resolve = resolve,
          reject = reject,
          on_settle = cancel_timer
        )
        timer_handle <- later::later(function() {
          private$control_dispatcher$reject(
            request_id,
            simpleError(paste0("Control request timeout: ", subtype))
          )
        }, delay = timeout_ms / 1000)
        tryCatch(
          self$send(json),
          error = function(error) {
            private$control_dispatcher$reject(request_id, error)
          }
        )
      })
    },

    #' @description Send a control request and synchronously poll for its
    #'   response. Buffers any SDK messages received before the response so
    #'   they are not lost from the main receive loop.
    #'
    #'   Mirrors Python's `Query._send_control_request()` (synchronous
    #'   version). Safe to call between turns (not while `receive_messages()`
    #'   is being iterated).
    #'
    #' @param request List. Control request body (must have `subtype`).
    #' @param timeout_ms Integer. Milliseconds to wait (default 30 000).
    #' @return Named list with the response payload, or `NULL` on timeout.
    send_and_wait = function(request, timeout_ms = 30000L) {
      private$req_counter <- private$req_counter + 1L
      request_id <- paste0("req_", private$req_counter, "_",
                           paste0(as.hexmode(sample.int(256, 4) - 1), collapse = ""))
      json <- jsonlite::toJSON(
        list(type = "control_request", request_id = request_id, request = request),
        auto_unbox = TRUE, null = "null"
      )
      self$send(json)

      deadline <- proc.time()[["elapsed"]] + timeout_ms / 1000
      while (proc.time()[["elapsed"]] < deadline) {
        if (is.null(private$proc) || !private$proc$is_alive()) break
        status <- tryCatch(private$proc$poll_io(100L), error = function(e) NULL)
        if (is.null(status)) next
        stdout_ready <- !is.null(names(status)) &&
          "output" %in% names(status) &&
          identical(status[["output"]], "ready")
        if (!stdout_ready) next
        raw <- tryCatch(private$proc$read_output(65536L), error = function(e) "")
        if (!nzchar(raw)) next
        result <- split_lines_with_buffer(private$buffer, raw)
        private$buffer <- result$remaining
        for (line in result$complete_lines) {
          line <- trimws(line)
          if (!nzchar(line) || !startsWith(line, "{")) next
          obj <- tryCatch(
            jsonlite::fromJSON(line, simplifyVector = FALSE),
            error = function(e) NULL
          )
          if (is.null(obj)) next
          if (identical(obj[["type"]], "control_response") &&
              identical(obj[["response"]][["request_id"]], request_id)) {
            resp <- obj[["response"]]
            if (identical(resp[["subtype"]], "error")) {
              stop(resp[["error"]] %||% "Control request error", call. = FALSE)
            }
            return(resp[["response"]] %||% list())
          }
          # Not our response — buffer it so the main receive loop can pick it up
          private$buffer$defer(line)
        }
      }
      warning(paste0("send_and_wait timed out waiting for: ", request[["subtype"]]),
              call. = FALSE)
      NULL
    },

    #' @description Perform a single non-blocking read cycle.  Polls stdout
    #'   with a 0 ms timeout, reads any available data, parses complete JSON
    #'   lines into typed message objects, handles control requests internally,
    #'   and returns a list of SDK messages (never control messages).
    #'
    #'   Returns an empty list when no data is available — the caller can
    #'   schedule the next call via `later::later()` for event-loop-friendly
    #'   polling.
    #' @return List of typed message objects (may be empty).
    read_available_messages = function() {
      if (is.null(private$proc) || !private$proc$is_alive()) {
        if (!is.null(private$control_dispatcher)) {
          private$control_dispatcher$reject_all(
            simpleError("Claude Code process exited")
          )
        }
        return(list())
      }

      msgs <- list()
      opts <- private$options

      # Non-blocking poll (0 ms timeout)
      status <- tryCatch(private$proc$poll_io(0L), error = function(e) NULL)
      if (is.null(status)) return(msgs)

      # Handle stderr
      stderr_ready <- !is.null(names(status)) &&
        "error" %in% names(status) &&
        identical(status[["error"]], "ready")
      if (stderr_ready && !is.null(opts$stderr)) {
        err_line <- tryCatch(private$proc$read_error(1024L), error = function(e) "")
        if (nzchar(err_line)) {
          for (ln in strsplit(err_line, "\n", fixed = TRUE)[[1]]) {
            if (nzchar(trimws(ln))) opts$stderr(ln)
          }
        }
      }

      # Handle stdout
      stdout_ready <- !is.null(names(status)) &&
        "output" %in% names(status) &&
        identical(status[["output"]], "ready")

      if (stdout_ready) {
        max_buf <- opts$max_buffer_size %||% .DEFAULT_MAX_BUFFER_SIZE
        raw <- tryCatch(private$proc$read_output(max_buf), error = function(e) "")
        if (nzchar(raw)) {
          result <- split_lines_with_buffer(private$buffer, raw)
          private$buffer <- result$remaining
          for (line in result$complete_lines) {
            line <- trimws(line)
            if (!nzchar(line)) next
            if (!startsWith(line, "{")) next

            msg <- tryCatch(
              parse_message(line),
              error = function(e) {
                warning(conditionMessage(e), call. = FALSE)
                NULL
              }
            )
            if (is.null(msg)) next
            if (!is.null(private$control_dispatcher) &&
                private$control_dispatcher$dispatch(msg)) next

            # Route control requests; may return a PermissionRequestMessage
            if (is.list(msg) && identical(msg[["type"]], "control_request")) {
              ctrl_msg <- private$handle_control_request(msg)
              if (!is.null(ctrl_msg)) {
                msgs[[length(msgs) + 1L]] <- ctrl_msg
              }
              next
            }
            if (is.list(msg) && identical(msg[["type"]], "control_cancel_request")) {
              next
            }

            msgs[[length(msgs) + 1L]] <- msg
          }
        }
      }

      msgs
    },

    #' @description Get a pending permission request by ID, or NULL.
    #' @param request_id Character.
    get_pending_permission = function(request_id) {
      if (exists(request_id, envir = private$pending_permissions, inherits = FALSE)) {
        get(request_id, envir = private$pending_permissions)
      } else {
        NULL
      }
    },

    #' @description Resolve a pending permission request by sending the
    #'   control response to the CLI.
    #' @param request_id Character.
    #' @param response List with `behavior`, and optionally `updatedInput`,
    #'   `message`, `interrupt`.
    resolve_pending_permission = function(request_id, response) {
      if (!exists(request_id, envir = private$pending_permissions, inherits = FALSE)) {
        warning("No pending permission request: ", request_id, call. = FALSE)
        return(invisible(NULL))
      }
      rm(list = request_id, envir = private$pending_permissions)
      self$send(build_control_response(request_id, response))
      invisible(NULL)
    },

    #' @description Return a `coro` generator that yields typed message objects
    #'   until a `ResultMessage` is received or the process exits. Control
    #'   requests are handled internally and never yielded.
    receive_messages = function() {
      self_ref <- self
      coro::generator(function() {
        while (TRUE) {
          if (is.null(private$proc) || !private$proc$is_alive()) {
            if (!is.null(private$control_dispatcher)) {
              private$control_dispatcher$reject_all(
                simpleError("Claude Code process exited")
              )
            }
            break
          }

          # Poll stdout with 50 ms timeout
          status <- tryCatch(
            private$proc$poll_io(50L),
            error = function(e) c(output = "timeout", input = "timeout", error = "timeout")
          )

          stderr_ready <- !is.null(names(status)) &&
            "error" %in% names(status) &&
            identical(status[["error"]], "ready")
          if (stderr_ready && !is.null(private$options$stderr)) {
            err_line <- tryCatch(private$proc$read_error(1024L), error = function(e) "")
            if (nzchar(err_line)) {
              for (ln in strsplit(err_line, "\n", fixed = TRUE)[[1]]) {
                if (nzchar(trimws(ln))) private$options$stderr(ln)
              }
            }
          }

          stdout_ready <- !is.null(names(status)) &&
            "output" %in% names(status) &&
            identical(status[["output"]], "ready")

          if (stdout_ready) {
            max_buf <- private$options$max_buffer_size %||% .DEFAULT_MAX_BUFFER_SIZE
            raw <- tryCatch(private$proc$read_output(max_buf), error = function(e) "")
            if (nzchar(raw)) {
              result <- split_lines_with_buffer(private$buffer, raw)
              private$buffer <- result$remaining
              for (line in result$complete_lines) {
                line <- trimws(line)
                if (!nzchar(line)) next
                # Skip non-JSON lines (e.g. [SandboxDebug])
                if (!startsWith(line, "{")) next

                msg <- tryCatch(
                  parse_message(line),
                  error = function(e) {
                    warning(conditionMessage(e), call. = FALSE)
                    NULL
                  }
                )
                if (is.null(msg)) next
                if (!is.null(private$control_dispatcher) &&
                    private$control_dispatcher$dispatch(msg)) next

                # Route control requests; may return a PermissionRequestMessage
                if (is.list(msg) && identical(msg[["type"]], "control_request")) {
                  ctrl_msg <- private$handle_control_request(msg)
                  if (!is.null(ctrl_msg)) coro::yield(ctrl_msg)
                  next
                }

                # Cancel requests: R is synchronous so no in-flight tasks
                # to cancel — acknowledge silently, no response needed.
                if (is.list(msg) && identical(msg[["type"]], "control_cancel_request")) {
                  next
                }

                coro::yield(msg)

                if (inherits(msg, "ResultMessage")) return(invisible(NULL))
              }
            }
          }

          # Process exited
          if (!private$proc$is_alive()) {
            exit_code <- private$proc$get_exit_status()
            if (!is.null(private$control_dispatcher)) {
              private$control_dispatcher$reject_all(
                simpleError("Claude Code process exited")
              )
            }
            if (!is.null(exit_code) && exit_code != 0L) {
              stop(claude_process_error(
                "Claude CLI process exited unexpectedly",
                exit_code = exit_code
              ))
            }
            break
          }
        }
        invisible(NULL)
      })()
    }
  ),

  private = list(
    options         = NULL,
    proc            = NULL,
    buffer          = "",
    ready           = FALSE,
    session_id      = "",
    write_lock      = FALSE,
    req_counter     = 0L,
    hook_callbacks  = NULL,   # named list: callback_id -> function
    next_callback_id = 0L,    # counter for unique IDs
    init_result     = NULL,   # captured from the initialize control_response
    pending_permissions = NULL,    # env: request_id → request list (message-driven approval)
    control_dispatcher = NULL,     # request_id → async control callbacks

    # -----------------------------------------------------------------------
    # CLI command builder — mirrors _build_command() in subprocess_cli.py
    # -----------------------------------------------------------------------
    build_command = function() {
      opts <- private$options
      args <- c("--output-format", "stream-json", "--verbose")

      # Skills defaults (mirrors Python _apply_skills_defaults): compute
      # effective allowed_tools + setting_sources from the `skills` option.
      eff_allowed_tools   <- opts$allowed_tools
      eff_setting_sources <- opts$setting_sources
      if (!is.null(opts$skills)) {
        if (identical(opts$skills, "all")) {
          if (!("Skill" %in% eff_allowed_tools)) {
            eff_allowed_tools <- c(eff_allowed_tools, "Skill")
          }
        } else {
          for (.sk in opts$skills) {
            pat <- paste0("Skill(", .sk, ")")
            if (!(pat %in% eff_allowed_tools)) eff_allowed_tools <- c(eff_allowed_tools, pat)
          }
        }
        if (is.null(eff_setting_sources)) eff_setting_sources <- c("user", "project")
      }

      # system_prompt
      if (is.null(opts$system_prompt)) {
        args <- c(args, "--system-prompt", "")
      } else if (is.character(opts$system_prompt)) {
        args <- c(args, "--system-prompt", opts$system_prompt)
      } else if (is.list(opts$system_prompt)) {
        sp <- opts$system_prompt
        if (identical(sp[["type"]], "file")) {
          args <- c(args, "--system-prompt-file", sp[["path"]])
        } else if (identical(sp[["type"]], "preset") && !is.null(sp[["append"]])) {
          args <- c(args, "--append-system-prompt", sp[["append"]])
        }
      }

      # tools
      if (!is.null(opts$tools)) {
        if (is.character(opts$tools)) {
          if (length(opts$tools) == 0L) {
            args <- c(args, "--tools", "")
          } else {
            args <- c(args, "--tools", paste(opts$tools, collapse = ","))
          }
        } else if (is.list(opts$tools)) {
          args <- c(args, "--tools", "default")
        }
      }

      if (length(eff_allowed_tools))    args <- c(args, "--allowedTools",   paste(eff_allowed_tools,    collapse = ","))
      if (!is.null(opts$max_turns))      args <- c(args, "--max-turns",      as.character(opts$max_turns))
      if (!is.null(opts$max_budget_usd)) args <- c(args, "--max-budget-usd", as.character(opts$max_budget_usd))
      if (length(opts$disallowed_tools)) args <- c(args, "--disallowedTools", paste(opts$disallowed_tools, collapse = ","))
      if (!is.null(opts$task_budget))    args <- c(args, "--task-budget",    as.character(opts$task_budget[["total"]]))
      if (!is.null(opts$model))          args <- c(args, "--model",          opts$model)
      if (!is.null(opts$fallback_model)) args <- c(args, "--fallback-model", opts$fallback_model)
      if (length(opts$betas))            args <- c(args, "--betas",          paste(opts$betas, collapse = ","))
      if (!is.null(opts$permission_prompt_tool_name)) {
        args <- c(args, "--permission-prompt-tool", opts$permission_prompt_tool_name)
      }
      if (!is.null(opts$permission_mode)) args <- c(args, "--permission-mode", opts$permission_mode)
      if (isTRUE(opts$continue_conversation)) args <- c(args, "--continue")
      if (!is.null(opts$resume)     && nzchar(opts$resume))     args <- c(args, "--resume",      opts$resume)
      if (!is.null(opts$session_id) && nzchar(opts$session_id)) args <- c(args, "--session-id",  opts$session_id)

      # settings / sandbox
      settings_val <- private$build_settings_value()
      if (!is.null(settings_val)) args <- c(args, "--settings", settings_val)

      # add_dirs
      for (d in opts$add_dirs) args <- c(args, "--add-dir", as.character(d))

      # mcp_servers
      if (length(opts$mcp_servers) > 0L) {
        if (is.list(opts$mcp_servers)) {
          servers_for_cli <- list()
          for (nm in names(opts$mcp_servers)) {
            cfg <- opts$mcp_servers[[nm]]
            if (is.list(cfg) && identical(cfg[["type"]], "sdk")) {
              servers_for_cli[[nm]] <- cfg[setdiff(names(cfg), "instance")]
            } else {
              servers_for_cli[[nm]] <- cfg
            }
          }
          if (length(servers_for_cli)) {
            args <- c(args, "--mcp-config",
                      jsonlite::toJSON(list(mcpServers = servers_for_cli),
                                       auto_unbox = TRUE))
          }
        } else {
          args <- c(args, "--mcp-config", as.character(opts$mcp_servers))
        }
      }

      if (isTRUE(opts$include_partial_messages)) args <- c(args, "--include-partial-messages")
      if (isTRUE(opts$fork_session))             args <- c(args, "--fork-session")
      if (!is.null(eff_setting_sources))        args <- c(args, "--setting-sources",
                                                            paste(eff_setting_sources, collapse = ","))
      if (isTRUE(opts$strict_mcp_config))       args <- c(args, "--strict-mcp-config")
      if (isTRUE(opts$include_hook_events))     args <- c(args, "--include-hook-events")

      # plugins
      for (plug in opts$plugins) {
        if (identical(plug[["type"]], "local")) {
          args <- c(args, "--plugin-dir", plug[["path"]])
        }
      }

      # extra_args
      for (nm in names(opts$extra_args)) {
        val <- opts$extra_args[[nm]]
        flag <- if (startsWith(nm, "--")) nm else paste0("--", nm)
        if (is.null(val)) {
          args <- c(args, flag)
        } else {
          args <- c(args, flag, as.character(val))
        }
      }

      # thinking
      if (!is.null(opts$thinking)) {
        t <- opts$thinking
        if (identical(t[["type"]], "adaptive")) {
          args <- c(args, "--thinking", "adaptive")
        } else if (identical(t[["type"]], "enabled")) {
          args <- c(args, "--max-thinking-tokens", as.character(t[["budget_tokens"]]))
        } else if (identical(t[["type"]], "disabled")) {
          args <- c(args, "--thinking", "disabled")
        }
        if (!identical(t[["type"]], "disabled") && !is.null(t[["display"]])) {
          args <- c(args, "--thinking-display", t[["display"]])
        }
      } else if (!is.null(opts$max_thinking_tokens)) {
        args <- c(args, "--max-thinking-tokens", as.character(opts$max_thinking_tokens))
      }

      if (!is.null(opts$effort)) args <- c(args, "--effort", opts$effort)

      # output_format / json schema
      if (!is.null(opts$output_format) && is.list(opts$output_format) &&
          identical(opts$output_format[["type"]], "json_schema")) {
        schema <- opts$output_format[["schema"]]
        if (!is.null(schema)) {
          args <- c(args, "--json-schema",
                    jsonlite::toJSON(schema, auto_unbox = TRUE))
        }
      }

      # Always use stream-json input (bidirectional)
      args <- c(args, "--input-format", "stream-json")

      args
    },

    # Merge sandbox into settings (mirrors _build_settings_value)
    build_settings_value = function() {
      opts <- private$options
      has_settings <- !is.null(opts$settings)
      has_sandbox  <- !is.null(opts$sandbox)

      if (!has_settings && !has_sandbox) return(NULL)
      if (has_settings && !has_sandbox)  return(opts$settings)

      settings_obj <- list()
      if (has_settings) {
        s <- trimws(opts$settings)
        if (startsWith(s, "{") && endsWith(s, "}")) {
          settings_obj <- tryCatch(
            jsonlite::fromJSON(s, simplifyVector = FALSE),
            error = function(e) list()
          )
        } else if (file.exists(s)) {
          settings_obj <- tryCatch(
            jsonlite::fromJSON(s, simplifyVector = FALSE),
            error = function(e) list()
          )
        }
      }
      if (has_sandbox) settings_obj[["sandbox"]] <- opts$sandbox
      jsonlite::toJSON(settings_obj, auto_unbox = TRUE)
    },

    # -----------------------------------------------------------------------
    # Send initialize control-request and wait for the CLI's control_response
    # -----------------------------------------------------------------------
    wait_for_initialize = function() {
      req_id <- "req_init_1"

      # Build hooks config and register callbacks with unique IDs (mirrors query.py:initialize())
      hooks_config <- NULL
      private$hook_callbacks  <- list()
      private$next_callback_id <- 0L
      if (!is.null(private$options$hooks)) {
        hooks_config <- list()
        for (event_name in names(private$options$hooks)) {
          matchers <- private$options$hooks[[event_name]]
          if (!is.null(matchers) && length(matchers) > 0L) {
            hooks_config[[event_name]] <- lapply(matchers, function(m) {
              # Assign a unique callback_id to each hook function
              callback_ids <- character(0)
              for (hook_fn in m$hooks) {
                cb_id <- paste0("hook_", private$next_callback_id)
                private$next_callback_id <- private$next_callback_id + 1L
                private$hook_callbacks[[cb_id]] <- hook_fn
                callback_ids <- c(callback_ids, cb_id)
              }
              matcher_cfg <- list(matcher = m$matcher, hookCallbackIds = callback_ids)
              if (!is.null(m$timeout)) matcher_cfg[["timeout"]] <- m$timeout
              matcher_cfg
            })
          }
        }
        if (length(hooks_config) == 0L) hooks_config <- NULL
      }

      # Build agents config (mirrors Python Query.initialize())
      agents_config <- NULL
      if (!is.null(private$options$agents) && length(private$options$agents) > 0L) {
        agents_config <- private$build_agents_config(private$options$agents)
      }

      # exclude_dynamic_sections from SystemPromptPreset (mirrors Python Query.initialize())
      exclude_dyn <- NULL
      if (is.list(private$options$system_prompt) &&
          identical(private$options$system_prompt[["type"]], "preset")) {
        exclude_dyn <- private$options$system_prompt[["exclude_dynamic_sections"]]
      }

      init_req_body <- list(
        subtype = "initialize",
        hooks   = hooks_config
      )
      if (!is.null(agents_config))  init_req_body[["agents"]]                 <- agents_config
      if (!is.null(exclude_dyn))    init_req_body[["excludeDynamicSections"]] <- exclude_dyn

      init_request <- list(
        type       = "control_request",
        request_id = req_id,
        request    = init_req_body
      )
      init_json <- jsonlite::toJSON(init_request, auto_unbox = TRUE, null = "null")
      .write_all_to_process(private$proc, paste0(init_json, "\n"))

      # Poll stdout for the matching control_response
      # Respect CLAUDE_CODE_STREAM_CLOSE_TIMEOUT env var (mirrors Python query.py)
      timeout_ms  <- suppressWarnings(as.numeric(
        Sys.getenv("CLAUDE_CODE_STREAM_CLOSE_TIMEOUT", unset = "60000")
      ))
      if (is.na(timeout_ms) || timeout_ms < 60000) timeout_ms <- 60000
      deadline <- proc.time()[["elapsed"]] + timeout_ms / 1000
      while (proc.time()[["elapsed"]] < deadline) {
        if (is.null(private$proc) || !private$proc$is_alive()) {
          claude_cli_connection_error("Claude Code process exited before initialize handshake")
        }
        status <- tryCatch(private$proc$poll_io(100L), error = function(e) NULL)
        if (is.null(status)) next

        stdout_ready <- !is.null(names(status)) &&
          "output" %in% names(status) &&
          identical(status[["output"]], "ready")
        if (!stdout_ready) next

        raw <- tryCatch(private$proc$read_output(65536L), error = function(e) "")
        if (!nzchar(raw)) next

        result <- split_lines_with_buffer(private$buffer, raw)
        private$buffer <- result$remaining
        for (line in result$complete_lines) {
          line <- trimws(line)
          if (!nzchar(line) || !startsWith(line, "{")) next
          obj <- tryCatch(
            jsonlite::fromJSON(line, simplifyVector = FALSE),
            error = function(e) NULL
          )
          if (is.null(obj)) next
          if (identical(obj[["type"]], "control_response") &&
              identical(obj[["response"]][["request_id"]], req_id)) {
            # Capture server info for get_server_info()
            private$init_result <- obj[["response"]][["response"]] %||% list()
            return(invisible(NULL))
          }
          # Queue any other messages that arrived before the init response (append preserves order)
          private$buffer$defer(line)
        }
      }
      warning("Timed out waiting for initialize handshake from Claude Code", call. = FALSE)
    },

    # -----------------------------------------------------------------------
    # Control-request handlers
    # -----------------------------------------------------------------------
    # Returns NULL when handled internally, or a PermissionRequestMessage
    # when the caller must approve/deny via approve_tool()/deny_tool().
    handle_control_request = function(req) {
      request_id <- req[["request_id"]]
      request    <- req[["request"]]
      subtype    <- request[["subtype"]]

      # Message-driven approval: yield PermissionRequestMessage when no
      # can_use_tool sync handler is configured (user calls approve_tool/deny_tool)
      if (identical(subtype, "can_use_tool") &&
          is.null(private$options$can_use_tool)) {
        assign(request_id, request, envir = private$pending_permissions)
        return(PermissionRequestMessage(
          request_id      = request_id,
          tool_name       = request[["tool_name"]],
          tool_input      = request[["input"]],
          tool_use_id     = request[["tool_use_id"]],
          agent_id        = request[["agent_id"]],
          suggestions     = request[["permission_suggestions"]],
          blocked_path    = request[["blocked_path"]],
          decision_reason = request[["decision_reason"]],
          title           = request[["title"]],
          display_name    = request[["display_name"]],
          description     = request[["description"]]
        ))
      }

      # Priority 3: Sync callback (can_use_tool) or default allow
      response <- tryCatch({
        switch(subtype,
          "initialize"        = private$handle_initialize_request_inline(req),
          "can_use_tool"      = private$handle_permission_request(request),
          "interrupt"         = list(type = "interrupt_response"),
          "hook_callback"     = private$handle_hook(request),
          "mcp_message"       = private$handle_sdk_mcp_request(request),
          NULL  # unknown subtype — no response (forward-compatible)
        )
      }, error = function(e) {
        self$send(build_control_error_response(request_id, conditionMessage(e)))
        return(NULL)
      })

      if (!is.null(response)) {
        self$send(build_control_response(request_id, response))
      }
      NULL
    },

    handle_initialize_request_inline = function(req) {
      list(
        type = "initialize_response",
        sdkVersion = as.character(utils::packageVersion("ClaudeAgentSDK")),
        supportedControlMessages = c(
          "permission_request", "interrupt", "hook_callback", "mcp_message"
        )
      )
    },

    # Route a `mcp_message` control-request to the named in-process SDK MCP
    # server and wrap its JSON-RPC response for the control protocol (mirrors
    # Python query.py `_handle_sdk_mcp_request`).
    handle_sdk_mcp_request = function(request) {
      server_name <- request[["server_name"]]
      message     <- request[["message"]]
      cfg <- private$options$mcp_servers[[server_name]]
      if (is.null(cfg) || !identical(cfg[["type"]], "sdk")) {
        return(list(mcp_response = list(
          jsonrpc = "2.0",
          id      = if (is.list(message)) message[["id"]] else NULL,
          error   = list(
            code    = -32601,
            message = paste0("SDK MCP server '", server_name %||% "", "' not found")
          )
        )))
      }
      list(mcp_response = .sdk_mcp_dispatch(cfg, message))
    },

    handle_permission_request = function(request) {
      if (!is.null(private$options$can_use_tool)) {
        ctx <- ToolPermissionContext(
          suggestions     = request[["permission_suggestions"]] %||% list(),
          tool_use_id     = request[["tool_use_id"]],
          agent_id        = request[["agent_id"]],
          signal          = NULL,
          blocked_path    = request[["blocked_path"]],
          decision_reason = request[["decision_reason"]],
          title           = request[["title"]],
          display_name    = request[["display_name"]],
          description     = request[["description"]]
        )
        result <- private$options$can_use_tool(
          request[["tool_name"]],
          request[["input"]],
          ctx
        )
        if (inherits(result, "PermissionResultAllow")) {
          resp <- list(
            behavior     = "allow",
            updatedInput = result$updated_input %||% request[["input"]]
          )
          if (!is.null(result$updated_permissions)) {
            resp[["updatedPermissions"]] <- lapply(
              result$updated_permissions, .permission_update_to_dict
            )
          }
          return(resp)
        } else {
          resp <- list(behavior = "deny", message = result$message %||% "")
          if (isTRUE(result$interrupt)) resp[["interrupt"]] <- TRUE
          return(resp)
        }
      }
      # Default: allow (behavior field required by CLI protocol)
      list(behavior = "allow")
    },

    handle_hook = function(request) {
      # Dispatch by callback_id (mirrors Python query.py handle_control_request hook_callback branch)
      callback_id <- request[["callback_id"]]
      if (is.null(callback_id) || is.null(private$hook_callbacks)) {
        return(list(continue_ = TRUE))
      }
      hook_fn <- private$hook_callbacks[[callback_id]]
      if (is.null(hook_fn)) {
        warning(paste0("No hook callback found for ID: ", callback_id), call. = FALSE)
        return(list(continue_ = TRUE))
      }
      result <- tryCatch(
        hook_fn(
          request[["input"]],
          request[["tool_use_id"]],
          list(signal = NULL)
        ),
        error = function(e) list(continue_ = TRUE)
      )
      # Convert R-style names to CLI-expected names (mirrors Python _convert_hook_output_for_cli):
      # continue_ -> continue,  async_ -> async
      private$convert_hook_output_for_cli(result %||% list(continue_ = TRUE))
    },

    # Mirrors Python's _convert_hook_output_for_cli().
    # R doesn't have keyword conflicts but we support both continue_ and continue
    # for parity with Python-style hook callbacks.
    convert_hook_output_for_cli = function(hook_output) {
      converted <- list()
      for (nm in names(hook_output)) {
        if (nm == "continue_") {
          converted[["continue"]] <- hook_output[[nm]]
        } else if (nm == "async_") {
          converted[["async"]] <- hook_output[[nm]]
        } else {
          converted[[nm]] <- hook_output[[nm]]
        }
      }
      converted
    },

    # snake_case → camelCase mapping for AgentDefinition fields
    # (Python defines these fields in camelCase directly)
    .agent_field_map = list(
      disallowed_tools = "disallowedTools",
      mcp_servers      = "mcpServers",
      initial_prompt   = "initialPrompt",
      max_turns        = "maxTurns",
      permission_mode  = "permissionMode"
    ),

    build_agents_config = function(agents) {
      # Python sends agents as {name: config} dict; R options uses named list
      result <- list()
      for (nm in names(agents)) {
        ag <- agents[[nm]]
        fields <- as.list(ag)
        fields[["class"]] <- NULL
        fields <- Filter(Negate(is.null), fields)
        # Convert snake_case field names → camelCase for CLI
        converted <- list()
        for (key in names(fields)) {
          cli_key <- private$.agent_field_map[[key]] %||% key
          converted[[cli_key]] <- fields[[key]]
        }
        result[[nm]] <- converted
      }
      result
    }
  )
)

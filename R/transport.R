#' @title SubprocessCLITransport
#' @description R6 class that manages the Claude Code CLI subprocess and
#'   implements the full bidirectional control protocol. Mirrors
#'   `_internal/transport/subprocess_cli.py` plus the `Query` class from
#'   `_internal/query.py`.
#' @name transport
NULL

.DEFAULT_MAX_BUFFER_SIZE <- 1024L * 1024L  # 1 MB

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

    #' @description Initialise the transport with a `ClaudeAgentOptions` object.
    #' @param options A `ClaudeAgentOptions` from [claude_agent_options()].
    initialize = function(options) {
      private$options    <- options
      private$buffer     <- ""
      private$write_lock <- FALSE
      private$session_id <- ""
      private$req_counter <- 0L
      invisible(self)
    },

    #' @description Start the subprocess and wait for the `initialize`
    #'   control-request handshake.
    connect = function() {
      if (!is.null(private$proc) && private$proc$is_alive()) return(invisible(self))

      cli_path <- find_claude(private$options$cli_path)

      skip_version_check <- nzchar(Sys.getenv("CLAUDE_AGENT_SDK_SKIP_VERSION_CHECK"))
      if (!skip_version_check) {
        check_claude_version(cli_path)
      }

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

      # Wait for the initialize control-request from the CLI
      private$wait_for_initialize()

      invisible(self)
    },

    #' @description Gracefully shut down the subprocess.
    disconnect = function() {
      private$ready <- FALSE
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
        private$proc$write_input(paste0(message_json, "\n")),
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

    #' @description Return a `coro` generator that yields typed message objects
    #'   until a `ResultMessage` is received or the process exits. Control
    #'   requests are handled internally and never yielded.
    receive_messages = function() {
      self_ref <- self
      coro::generator(function() {
        while (TRUE) {
          if (is.null(private$proc) || !private$proc$is_alive()) break

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

                # Route control requests internally
                if (is.list(msg) && identical(msg[["type"]], "control_request")) {
                  private$handle_control_request(msg)
                  next
                }

                coro::yield(msg)

                if (inherits(msg, "ResultMessage")) return(invisible(NULL))
              }
            }
          }

          # Process exited
          if (!private$proc$is_alive()) break
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

    # -----------------------------------------------------------------------
    # CLI command builder — mirrors _build_command() in subprocess_cli.py
    # -----------------------------------------------------------------------
    build_command = function() {
      opts <- private$options
      args <- c("--output-format", "stream-json", "--verbose")

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

      if (length(opts$allowed_tools))    args <- c(args, "--allowedTools",   paste(opts$allowed_tools,    collapse = ","))
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
      if (!is.null(opts$resume))          args <- c(args, "--resume",      opts$resume)
      if (!is.null(opts$session_id))      args <- c(args, "--session-id",  opts$session_id)

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
      if (!is.null(opts$setting_sources))        args <- c(args, "--setting-sources",
                                                            paste(opts$setting_sources, collapse = ","))

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

      init_req_body <- list(
        subtype = "initialize",
        hooks   = hooks_config
      )
      if (!is.null(agents_config)) init_req_body[["agents"]] <- agents_config

      init_request <- list(
        type       = "control_request",
        request_id = req_id,
        request    = init_req_body
      )
      init_json <- jsonlite::toJSON(init_request, auto_unbox = TRUE, null = "null")
      private$proc$write_input(paste0(init_json, "\n"))

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
            # Handshake complete — SDK registered with CLI
            return(invisible(NULL))
          }
          # Queue any other messages that arrived before the init response (append preserves order)
          private$buffer <- paste0(private$buffer, line, "\n")
        }
      }
      warning("Timed out waiting for initialize handshake from Claude Code", call. = FALSE)
    },

    # -----------------------------------------------------------------------
    # Control-request handlers
    # -----------------------------------------------------------------------
    handle_control_request = function(req) {
      request_id <- req[["request_id"]]
      request    <- req[["request"]]
      subtype    <- request[["subtype"]]

      response <- tryCatch({
        switch(subtype,
          "initialize"        = private$handle_initialize_request_inline(req),
          "can_use_tool"      = private$handle_permission_request(request),
          "interrupt"         = list(type = "interrupt_response"),
          "hook_callback"     = private$handle_hook(request),
          NULL  # unknown subtype — no response (forward-compatible)
        )
      }, error = function(e) {
        self$send(build_control_error_response(request_id, conditionMessage(e)))
        return(NULL)
      })

      if (!is.null(response)) {
        self$send(build_control_response(request_id, response))
      }
      invisible(NULL)
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

    handle_permission_request = function(request) {
      if (!is.null(private$options$can_use_tool)) {
        ctx <- list(
          suggestions = request[["permission_suggestions"]] %||% list(),
          tool_use_id = request[["tool_use_id"]],
          agent_id    = request[["agent_id"]],
          signal      = NULL
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
            resp[["updatedPermissions"]] <- result$updated_permissions
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

    build_agents_config = function(agents) {
      lapply(agents, function(ag) {
        fields <- as.list(ag)
        # Remove class attribute carried over from S3 object
        fields[["class"]] <- NULL
        Filter(Negate(is.null), fields)
      })
    }
  )
)
